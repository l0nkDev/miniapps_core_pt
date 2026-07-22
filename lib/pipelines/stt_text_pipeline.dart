import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:lib_llama_cpp_server/lib_llama_cpp_server.dart';
import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';
import '../core/models/app_models.dart';
import 'base_pipeline.dart';

class _ServerArgs {
  final String modelPath;
  final String? libraryPath;
  final SendPort sendPort;
  _ServerArgs(this.modelPath, this.libraryPath, this.sendPort);
}

void _llamaServerIsolate(_ServerArgs args) async {
  try {
    print("ISOLATE: Starting LlamaHttpServer.open with model: ${args.modelPath}");
    final server = LlamaHttpServer.open(
      config: LlamaServerConfig(
        model: 'default',
        modelPath: args.modelPath,
        port: 0,
        ctxSize: 2048,
        gpuLayers: 99, // Offload all layers to GPU if the backend supports it (Vulkan/OpenCL)
      ),
      libraryPath: args.libraryPath,
    );
    
    print("ISOLATE: Starting server...");
    final address = await server.start();
    print("ISOLATE: Server started on port ${address.port}");
    args.sendPort.send({'port': address.port});
  } catch (e) {
    print("ISOLATE: Error: $e");
    args.sendPort.send({'error': e.toString()});
  }
}

class SttTextPipeline extends BasePipeline {
  LlamaServerClient? _client;
  Isolate? _serverIsolate;
  bool _isInitialized = false;
  String _sttModelPath = '';

  @override
  Future<void> init(PipelineConfig config) async {
    if (config.type != PipelineType.sttPipeline) return;
    
    try {
      final receivePort = ReceivePort();
      final errorPort = ReceivePort();
      final exitPort = ReceivePort();
      
      errorPort.listen((message) {
        receivePort.sendPort.send({'error': 'Isolate crashed: $message'});
      });
      exitPort.listen((message) {
        receivePort.sendPort.send({'error': 'Isolate exited unexpectedly'});
      });
      
      _serverIsolate = await Isolate.spawn(
        _llamaServerIsolate,
        _ServerArgs(
          config.llmModelPath,
          Platform.isLinux ? 'liblib_llama_cpp_linux.so' : (Platform.isAndroid ? 'liblib_llama_cpp_android.so' : null),
          receivePort.sendPort,
        ),
        onError: errorPort.sendPort,
        onExit: exitPort.sendPort,
      );
      
      final response = await receivePort.first.timeout(
        const Duration(seconds: 300),
        onTimeout: () {
          _serverIsolate?.kill(priority: Isolate.immediate);
          throw Exception('Timeout: Model took longer than 5 minutes to load. It is either too large for your device RAM or the emulator storage is too slow.');
        },
      ) as Map;
      
      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }
      final port = response['port'] as int;
      _client = LlamaServerClient(baseUri: Uri.parse('http://127.0.0.1:$port/v1'));
      
      _sttModelPath = config.sttModelPath ?? '';
      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize STT pipeline server isolate: $e');
      rethrow;
    }
  }

  @override
  Stream<String> processAudio(String audioPath, List<ChatMessage> history, {required void Function(PipelineMetrics) onMetrics, String? systemContext}) async* {
    if (!_isInitialized) throw Exception('Pipeline not initialized');
    
    final startTime = DateTime.now();
    
    yield "Transcribing audio with Whisper...\n";
    
    final whisper = Whisper(model: WhisperModel.base);
    final transcribeResult = await whisper.transcribe(
      transcribeRequest: TranscribeRequest(
        audio: audioPath,
        language: 'es', // Set language to Spanish explicitly to prevent English auto-translation
      ),
      modelPath: _sttModelPath,
    );
    
    final text = transcribeResult.text;
    yield "Transcribed: '$text'\n";
    
    final newHistory = List<ChatMessage>.from(history)..add(
       ChatMessage(id: 'audio', text: text, isUser: true, timestamp: DateTime.now())
    );
    
    yield* processText(newHistory, systemContext: systemContext, onMetrics: (metrics) {
       final totalTime = DateTime.now().difference(startTime).inMilliseconds;
       onMetrics(PipelineMetrics(
         timeToFirstTokenMs: metrics.timeToFirstTokenMs,
         totalProcessingTimeMs: totalTime,
         peakCpuUsage: metrics.peakCpuUsage,
         peakRamUsageMb: metrics.peakRamUsageMb,
       ));
    });
  }

  @override
  Stream<String> processText(List<ChatMessage> history, {required void Function(PipelineMetrics) onMetrics, String? systemContext}) async* {
    if (!_isInitialized || _client == null) throw Exception('Pipeline not initialized');
    
    final startTime = DateTime.now();
    
    final List<Map<String, String>> messages = [
      {'role': 'system', 'content': systemContext ?? 'You are a helpful assistant.'},
    ];
    
    for (final msg in history) {
      if (msg.text.trim().isEmpty) continue;
      final role = msg.isUser ? 'user' : 'assistant';
      if (messages.last['role'] == role) {
        messages.last['content'] = '${messages.last['content']}\n\n${msg.text}';
      } else {
        messages.add({'role': role, 'content': msg.text});
      }
    }
    
    int timeToFirstTokenMs = 0;
    int? tokensGenerated;
    double? tokensPerSecond;
    double? promptTokensPerSecond;
    
    try {
      final response = await _client!.createChatCompletion(
        model: 'default',
        messages: messages,
      );
      
      timeToFirstTokenMs = DateTime.now().difference(startTime).inMilliseconds;
      
      if (response.containsKey('timings')) {
         final timings = response['timings'] as Map;
         if (timings['predicted_per_second'] != null) {
            tokensPerSecond = (timings['predicted_per_second'] as num).toDouble();
         }
         if (timings['prompt_per_second'] != null) {
            promptTokensPerSecond = (timings['prompt_per_second'] as num).toDouble();
         }
         if (timings['predicted_n'] != null) {
            tokensGenerated = (timings['predicted_n'] as num).toInt();
         }
      }
      
      if (response.containsKey('error')) {
         final errorMsg = response['error'];
         debugPrint('Llama Server Error: $errorMsg');
         yield "Server Error: $errorMsg";
         return;
      }
      
      final choices = response['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
         final choice = choices[0] as Map;
         final messageObj = choice['message'];
         if (messageObj is Map && messageObj['content'] != null) {
            yield messageObj['content'] as String;
         } else if (choice['text'] != null) {
            yield choice['text'] as String;
         } else {
            yield ' [Raw: $response] ';
         }
      } else {
         yield 'Error: Empty response generated.';
      }
    } catch (e) {
      yield "Error during generation: $e";
    }
    
    onMetrics(PipelineMetrics(
      timeToFirstTokenMs: timeToFirstTokenMs,
      totalProcessingTimeMs: DateTime.now().difference(startTime).inMilliseconds,
      peakCpuUsage: 50.0, 
      peakRamUsageMb: 2400.0,
      tokensGenerated: tokensGenerated,
      tokensPerSecond: tokensPerSecond,
      promptTokensPerSecond: promptTokensPerSecond,
    ));
  }

  @override
  Future<void> dispose() async {
    _serverIsolate?.kill(priority: Isolate.immediate);
    _serverIsolate = null;
    _client = null;
    _isInitialized = false;
  }
}
