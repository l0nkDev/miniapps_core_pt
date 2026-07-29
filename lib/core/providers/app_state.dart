import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_models.dart';
import '../services/download_manager.dart';
import '../../pipelines/base_pipeline.dart';
import '../../pipelines/true_multimodal_pipeline.dart';
import '../../pipelines/stt_text_pipeline.dart';
import '../services/hardware_profiler.dart';

class AppState extends ChangeNotifier {
  PipelineType _activePipeline = PipelineType.sttPipeline;
  String? _selectedLlmPath;
  String? _selectedProjectorPath;
  String? _selectedSttPath;
  int _gpuLayers = 99;
  
  bool _useNativeSTT = false;
  bool get useNativeSTT => _useNativeSTT;
  
  bool _useNativeTTS = false;
  bool get useNativeTTS => _useNativeTTS;

  final List<ChatMessage> _messages = [];
  final Map<String, List<PipelineMetrics>> _benchmarkHistory = {};
  final List<Transaction> _transactions = [];
  bool _isProcessing = false;
  bool _isInitializingPipeline = false;
  bool _isPipelineLoaded = false;
  String? _pipelineError;
  
  bool _needsModelDownload = false;
  bool get needsModelDownload => _needsModelDownload;
  
  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;
  
  double _downloadProgress = 0.0;
  double get downloadProgress => _downloadProgress;
  
  String _downloadStatus = '';
  String get downloadStatus => _downloadStatus;
  
  BasePipeline? _activePipelineInstance;

  Map<String, ModelStats> _modelStats = {};
  Map<String, ModelStats> get modelStats => _modelStats;

  AppState() {
    loadStats();
    autoInitialize();
  }

  bool _isPrewarming = false;
  bool get isPrewarming => _isPrewarming;

  Future<void> autoInitialize() async {
    final models = await getAvailableModels();
    final dir = await getApplicationDocumentsDirectory();
    final prefsFile = File('${dir.path}/selected_models.json');
    
    String? llm;
    String? stt;
    String? projector;
    
    // Check if the user previously saved a specific model preference
    if (prefsFile.existsSync()) {
      try {
        final data = jsonDecode(prefsFile.readAsStringSync());
        llm = data['llm'];
        stt = data['stt'];
        projector = data['projector'];
        _useNativeSTT = data['useNativeSTT'] ?? false;
        _useNativeTTS = data['useNativeTTS'] ?? false;
        
        // Verify they still exist on disk
        if (llm != null && !File(llm).existsSync()) llm = null;
        if (stt != null && !File(stt).existsSync()) stt = null;
        if (projector != null && !File(projector).existsSync()) projector = null;
      } catch (_) {}
    }
    
    // If no preference saved, determine the expected default LLM based on hardware
    if (llm == null || llm.isEmpty) {
      final ramMb = HardwareSpecs.getDeviceRamMB();
      final expectedLlmPrefix = (ramMb > 10000) ? 'qwen2.5-3b-instruct' : 'qwen2.5-1.5b-instruct';
      llm = models['llms']?.firstWhere((m) => m.toLowerCase().contains(expectedLlmPrefix), orElse: () => '');
    }
    
    if (stt == null || stt.isEmpty) {
      final ramMb = HardwareSpecs.getDeviceRamMB();
      final expectedSttPrefix = (ramMb > 10000) ? 'ggml-small.bin' : 'ggml-base.bin';
      stt = models['stt']?.firstWhere((m) => m.toLowerCase().contains(expectedSttPrefix), orElse: () => '');
    }
    
    if (llm != null && llm.isNotEmpty && stt != null && stt.isNotEmpty) {
      _needsModelDownload = false;
      _selectedLlmPath = llm;
      _selectedSttPath = stt;
      _activePipeline = PipelineType.sttPipeline;
      
      await loadPipeline();
    } else {
      _needsModelDownload = true;
    }
    notifyListeners();
  }

  final _downloadManager = DownloadManager();

  void cancelDownloads() {
    _isDownloading = false;
    _needsModelDownload = false;
    _downloadManager.cancel();
    notifyListeners();
  }

  Future<void> downloadDefaultModels() async {
    _isDownloading = true;
    _needsModelDownload = false;
    _downloadProgress = 0.0;
    _downloadStatus = 'Initializing download...';
    notifyListeners();

    try {
      final ramMb = HardwareSpecs.getDeviceRamMB();
      String qwenUrl;
      String qwenFilename;
      String qwenName;
      String whisperUrl;
      String whisperFilename;
      String whisperName;

      if (ramMb > 10000) {
        // High-end device (e.g. 12GB RAM)
        qwenUrl = 'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf';
        qwenFilename = 'qwen2.5-3b-instruct-q4_k_m.gguf';
        qwenName = 'Qwen 2.5 3B (~2.1 GB)';
        whisperUrl = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin';
        whisperFilename = 'ggml-small.bin';
        whisperName = 'Whisper Small (~480 MB)';
      } else {
        // Mid-range & Low-end devices
        qwenUrl = 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf';
        qwenFilename = 'qwen2.5-1.5b-instruct-q4_k_m.gguf';
        qwenName = 'Qwen 2.5 1.5B (~1.12 GB)';
        whisperUrl = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin';
        whisperFilename = 'ggml-base.bin';
        whisperName = 'Whisper Base (~142 MB)';
      }
      
      _downloadStatus = 'Downloading $qwenName...';
      notifyListeners();

      final qwenPath = await _downloadManager.downloadModel(
        qwenUrl,
        qwenFilename,
        (progress, received, total, speed) {
          if (_isDownloading) {
            _downloadProgress = progress * 0.85;
            notifyListeners();
          }
        },
      );

      if (qwenPath == null || !_isDownloading) return;
      
      _downloadStatus = 'Downloading $whisperName...';
      notifyListeners();

      final whisperPath = await _downloadManager.downloadModel(
        whisperUrl,
        whisperFilename,
        (progress, received, total, speed) {
          if (_isDownloading) {
            _downloadProgress = 0.85 + (progress * 0.15);
            notifyListeners();
          }
        },
      );

      if (whisperPath == null || !_isDownloading) return;

      _downloadStatus = 'Download complete!';
      _isDownloading = false;
      notifyListeners();
      
      await autoInitialize();
    } catch (e) {
      _downloadStatus = 'Error downloading models: $e';
      _isDownloading = false;
      _needsModelDownload = true;
      notifyListeners();
    }
  }

  Future<void> loadStats() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/model_stats.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> json = jsonDecode(content);
        _modelStats = json.map((k, v) => MapEntry(k, ModelStats.fromJson(v)));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> saveStats() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/model_stats.json');
      final content = jsonEncode(_modelStats.map((k, v) => MapEntry(k, v.toJson())));
      await file.writeAsString(content);
    } catch (e) {
      debugPrint('Error saving stats: $e');
    }
  }

  void recordMetrics(PipelineMetrics metrics) {
    if (_selectedLlmPath == null) return;
    
    final modelName = _selectedLlmPath!.split(Platform.pathSeparator).last;
    
    _benchmarkHistory.putIfAbsent(modelName, () => []).add(metrics);
    
    _modelStats.putIfAbsent(modelName, () => ModelStats(modelName: modelName));
    
    final stats = _modelStats[modelName]!;
    stats.totalChats++;
    stats.totalTtftMs += metrics.timeToFirstTokenMs;
    
    if (metrics.tokensGenerated != null) {
      stats.totalTokensGenerated += metrics.tokensGenerated!;
      stats.totalGenerationTimeMs += (metrics.totalProcessingTimeMs - metrics.timeToFirstTokenMs);
    }
    
    saveStats();
    notifyListeners();
  }

  PipelineType get activePipeline => _activePipeline;
  String? get selectedLlmPath => _selectedLlmPath;
  String? get selectedProjectorPath => _selectedProjectorPath;
  String? get selectedSttPath => _selectedSttPath;
  int get gpuLayers => _gpuLayers;
  List<ChatMessage> get messages => _messages;
  Map<String, List<PipelineMetrics>> get benchmarkHistory => _benchmarkHistory;
  List<Transaction> get transactions => _transactions;
  bool get isProcessing => _isProcessing;
  bool get isInitializingPipeline => _isInitializingPipeline;
  bool get isPipelineLoaded => _isPipelineLoaded;
  String? get pipelineError => _pipelineError;
  BasePipeline? get activePipelineInstance => _activePipelineInstance;

  void setActivePipeline(PipelineType type) {
    _activePipeline = type;
    _isPipelineLoaded = false;
    notifyListeners();
  }

  Future<void> loadPipeline() async {
    _isPipelineLoaded = false;
    _isInitializingPipeline = true;
    notifyListeners();

    if (_activePipelineInstance != null) {
      await _activePipelineInstance!.dispose();
      _activePipelineInstance = null;
    }

    if (_activePipeline == PipelineType.trueMultimodal) {
      _activePipelineInstance = TrueMultimodalPipeline();
    } else {
      _activePipelineInstance = SttTextPipeline();
    }

    try {
      debugPrint('APPSTATE: Starting loadPipeline with LLM: $_selectedLlmPath');
      if (_selectedLlmPath == null || _selectedLlmPath!.isEmpty) {
        throw Exception('No LLM model selected. Please download and select a base LLM first.');
      }
      if (_activePipeline == PipelineType.trueMultimodal && (_selectedProjectorPath == null || _selectedProjectorPath!.isEmpty)) {
        throw Exception('Multimodal pipeline requires a projector model. Please download and select one.');
      }

      debugPrint('APPSTATE: Calling init on active pipeline instance...');
      await _activePipelineInstance!.init(
        PipelineConfig(
          type: _activePipeline,
          llmModelPath: _selectedLlmPath!,
          projectorPath: _selectedProjectorPath,
          sttModelPath: _selectedSttPath,
          gpuLayers: _gpuLayers,
        ),
      );
      debugPrint('APPSTATE: init finished successfully.');
      _isPipelineLoaded = true;
      _pipelineError = null;
      
      // Pre-warm the system prompt
      if (_activePipelineInstance != null) {
        debugPrint('Starting background pre-warm of KV cache...');
        _isPrewarming = true;
        notifyListeners();
        _activePipelineInstance!.processText(
          [ChatMessage(id: 'warmup', text: 'hello', isUser: true, timestamp: DateTime.now())],
          systemContext: getStaticSystemPrompt(),
          dynamicContext: getDynamicContext(),
          onMetrics: (_) {},
        ).listen((_) {}, onError: (e) {
          debugPrint('Pre-warm error (ignoring): $e');
          _isPrewarming = false;
          notifyListeners();
        }).onDone(() {
          debugPrint('Pre-warm complete! KV Cache is ready.');
          _isPrewarming = false;
          notifyListeners();
        });
      }
    } catch (e) {
      debugPrint('APPSTATE: Caught error: $e');
      _isPipelineLoaded = false;
      _pipelineError = e.toString();
      debugPrint('Error loading pipeline: $e');
    } finally {
      _isInitializingPipeline = false;
    }
    notifyListeners();
  }

  void setModelPaths({
    String? llmPath,
    String? projectorPath,
    String? sttPath,
    int? gpuLayers,
  }) {
    if (llmPath != null) _selectedLlmPath = llmPath;
    if (projectorPath != null) _selectedProjectorPath = projectorPath;
    if (sttPath != null) _selectedSttPath = sttPath;
    if (gpuLayers != null) _gpuLayers = gpuLayers;
    notifyListeners();
    _saveModelPreferences();
  }
  
  void setNativeToggles({bool? stt, bool? tts}) {
    if (stt != null) _useNativeSTT = stt;
    if (tts != null) _useNativeTTS = tts;
    notifyListeners();
    _saveModelPreferences();
  }
  
  Future<void> _saveModelPreferences() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/selected_models.json');
      await file.writeAsString(jsonEncode({
        'llm': _selectedLlmPath,
        'stt': _selectedSttPath,
        'projector': _selectedProjectorPath,
        'useNativeSTT': _useNativeSTT,
        'useNativeTTS': _useNativeTTS,
      }));
    } catch (e) {
      debugPrint('Failed to save model preferences: $e');
    }
  }

  Future<Map<String, List<String>>> getAvailableModels() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${dir.path}/models');
    
    final List<String> llms = [];
    final List<String> projectors = [];
    final List<String> stt = [];

    if (await modelsDir.exists()) {
      final entities = modelsDir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final filename = entity.path.split(Platform.pathSeparator).last;
          if (filename.endsWith('.gguf')) {
            if (filename.contains('mmproj')) {
              projectors.add(entity.path);
            } else {
              llms.add(entity.path);
            }
          } else if (filename.endsWith('.bin') && filename.contains('ggml')) {
            stt.add(entity.path);
          }
        }
      }
    }
    
    return {
      'llms': llms,
      'projectors': projectors,
      'stt': stt,
    };
  }

  Future<void> quickSwapModel({
    required PipelineType pipelineType,
    String? llmPath, 
    String? projectorPath, 
    String? sttPath
  }) async {
    _activePipeline = pipelineType;
    setModelPaths(llmPath: llmPath, projectorPath: projectorPath, sttPath: sttPath);
    await loadPipeline();
  }

  void addMessage(ChatMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  void updateMessage(String id, String newText) {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index != -1) {
      final msg = _messages[index];
      _messages[index] = ChatMessage(
        id: msg.id,
        text: newText,
        isUser: msg.isUser,
        timestamp: msg.timestamp,
        metrics: msg.metrics,
      );
      notifyListeners();
    }
  }

  void updateMessageMetrics(String id, PipelineMetrics? metrics) {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index != -1) {
      final msg = _messages[index];
      _messages[index] = ChatMessage(
        id: msg.id,
        text: msg.text,
        isUser: msg.isUser,
        timestamp: msg.timestamp,
        metrics: metrics,
      );
      notifyListeners();
    }
  }

  void setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  void parseMessageForTransaction(String message) {
    final regexIncome = RegExp(r'\[INCOME:\s*([-\d\.,]+),\s*([^\]]+)\]');
    final matchIncome = regexIncome.firstMatch(message);
    if (matchIncome != null) {
      _saveTransaction(matchIncome, isIncome: true);
      return;
    }
    
    final regexExpense = RegExp(r'\[EXPENSE:\s*([-\d\.,]+),\s*([^\]]+)\]');
    final matchExpense = regexExpense.firstMatch(message);
    if (matchExpense != null) {
      _saveTransaction(matchExpense, isIncome: false);
    }
  }

  void _saveTransaction(RegExpMatch match, {required bool isIncome}) {
    final amountStr = match.group(1);
    final desc = match.group(2)?.trim();
    if (amountStr != null && desc != null) {
      final cleanAmountStr = amountStr.replaceAll(',', '');
      double? amount = double.tryParse(cleanAmountStr);
      if (amount != null) {
        amount = amount.abs();
        if (!isIncome) {
          amount = -amount;
        }
        _transactions.add(Transaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          amount: amount,
          description: desc,
          timestamp: DateTime.now(),
        ));
        notifyListeners();
      }
    }
  }

  String getStaticSystemPrompt() {
    final buffer = StringBuffer();
    buffer.writeln('You are a finance assistant that tracks expenses and income. You must follow these strict rules:');
    buffer.writeln('1. If the user describes a transaction with both an amount and an item, you MUST output EXACTLY: `[EXPENSE: amount, item]` or `[INCOME: amount, item]`.');
    buffer.writeln('2. If the user mentions an amount but no item, ask what they spent it on.');
    buffer.writeln('3. If the user mentions an item but no amount, ask how much it was.');
    buffer.writeln('4. If the user says a greeting, chats normally, or says something completely unrelated to finance, DO NOT output a tag. Just reply conversationally in a short sentence.');
    buffer.writeln('');
    buffer.writeln('EXAMPLES:');
    buffer.writeln('User: Gasté 50 en comida');
    buffer.writeln('Assistant: [EXPENSE: 50, Comida]');
    buffer.writeln('User: Vendí mi bici por 200');
    buffer.writeln('Assistant: [INCOME: 200, Bici]');
    buffer.writeln('User: compré tomates');
    buffer.writeln('Assistant: ¿Cuánto te costaron los tomates?');
    buffer.writeln('User: gasté 100');
    buffer.writeln('Assistant: ¿En qué gastaste los 100?');
    buffer.writeln('User: hola');
    buffer.writeln('Assistant: ¡Hola! ¿En qué te puedo ayudar?');
    buffer.writeln('User: nicki nicole');
    buffer.writeln('Assistant: No sé qué tiene que ver eso con tus finanzas. ¿Registramos algún gasto?');
    buffer.writeln('User: lero lero');
    buffer.writeln('Assistant: Por favor dime si quieres registrar algún ingreso o gasto.');
    buffer.writeln('');
    buffer.writeln('CRITICAL: Keep your responses extremely short. You are on a mobile phone.');
    return buffer.toString();
  }

  String getDynamicContext() {
    final buffer = StringBuffer();
    if (_transactions.isEmpty) {
      buffer.writeln('No previous transactions yet.');
    } else {
      buffer.writeln('Here is the history of previous transactions:');
      for (final t in _transactions) {
        buffer.writeln('- ${t.timestamp.toIso8601String().split('T').first}: ${t.description} for \$${t.amount}');
      }
    }
    return buffer.toString();
  }
}
