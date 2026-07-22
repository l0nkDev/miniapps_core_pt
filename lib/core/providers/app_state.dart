import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_models.dart';
import '../../pipelines/base_pipeline.dart';
import '../../pipelines/true_multimodal_pipeline.dart';
import '../../pipelines/stt_text_pipeline.dart';

class AppState extends ChangeNotifier {
  PipelineType _activePipeline = PipelineType.sttPipeline;
  String? _selectedLlmPath;
  String? _selectedProjectorPath;
  String? _selectedSttPath;
  int _gpuLayers = 99;

  final List<ChatMessage> _messages = [];
  final Map<String, List<PipelineMetrics>> _benchmarkHistory = {};
  final List<Transaction> _transactions = [];
  bool _isProcessing = false;
  bool _isInitializingPipeline = false;
  bool _isPipelineLoaded = false;
  String? _pipelineError;
  
  BasePipeline? _activePipelineInstance;

  Map<String, ModelStats> _modelStats = {};
  Map<String, ModelStats> get modelStats => _modelStats;

  AppState() {
    loadStats();
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
    final regex = RegExp(r'\[SAVE:\s*([-\d\.]+),\s*([^\]]+)\]');
    final match = regex.firstMatch(message);
    if (match != null) {
      final amountStr = match.group(1);
      final desc = match.group(2)?.trim();
      if (amountStr != null && desc != null) {
        final amount = double.tryParse(amountStr);
        if (amount != null) {
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
  }

  String getTransactionHistoryContext() {
    final buffer = StringBuffer();
    buffer.writeln('You are a helpful financial assistant. Your job is to help the user track their expenses and income.');
    buffer.writeln('When the user mentions a new transaction (income or expense), you MUST include the exact syntax `[SAVE: amount, description]` in your response to save it to the database.');
    buffer.writeln('Use positive numbers for income, and negative numbers for expenses. For example, if the user bought a coffee for \$5, you should write: `[SAVE: -5, Coffee]`. If the user sold a bike for \$230, write: `[SAVE: 230, Sold bike]`.');
    buffer.writeln('IMPORTANT: If the user is just chatting, saying hello, or not explicitly describing a purchase, sale, or monetary transfer, DO NOT output any [SAVE: ...] tag. For example, if they say "hello", just say "Hello! How can I help you?". Do not output `[SAVE: 0, greeting]`.');
    buffer.writeln('CRITICAL CONSTRAINT: You are running on a mobile phone with limited resources. You MUST keep your conversational responses extremely brief, short, and to the point. Never generate long paragraphs.');
    buffer.writeln();
    
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
