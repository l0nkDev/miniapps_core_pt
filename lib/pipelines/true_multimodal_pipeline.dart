import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:lib_llama_cpp/lib_llama_cpp.dart';
import 'package:lib_llama_cpp_platform_interface/lib_llama_cpp_platform_interface.dart';
import '../core/models/app_models.dart';
import '../core/services/hardware_profiler.dart';
import 'base_pipeline.dart';

class LocalLlamaCppPlatform extends LibLlamaCppPlatform {
  @override
  Future<LlamaCppLibraryDescriptor> resolveLibrary({
    LlamaCppLibraryRequest? request,
  }) async {
    return LlamaCppLibraryDescriptor(
      resolution: LlamaCppLibraryResolution.path,
      path: Platform.isLinux ? 'liblib_llama_cpp_linux.so' : (Platform.isAndroid ? 'liblib_llama_cpp_android.so' : null),
    );
  }
}

class TrueMultimodalPipeline extends BasePipeline {
  LlamaOpenAIClient? _client;
  bool _isInitialized = false;

  @override
  Future<void> init(PipelineConfig config) async {
    if (config.type != PipelineType.trueMultimodal) return;
    
    try {
      LibLlamaCppPlatform.instance = LocalLlamaCppPlatform();
      _client = LlamaOpenAIClient(
        models: {
          'multimodal': LlamaModelConfig(
            modelPath: config.llmModelPath,
            mmprojPath: config.projectorPath,
            contextSize: 2048,
          ),
        },
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize true multimodal: $e');
      rethrow;
    }
  }

  @override
  Stream<String> processAudio(String audioPath, List<ChatMessage> history, {required void Function(PipelineMetrics) onMetrics, String? systemContext, String? dynamicContext, void Function(String)? onTranscribed}) async* {
    if (!_isInitialized || _client == null) throw Exception('Pipeline not initialized');
    
    final startTime = DateTime.now();
    
    final newHistory = List<ChatMessage>.from(history)..add(
       ChatMessage(id: 'audio', text: 'Please process the audio at: $audioPath', isUser: true, timestamp: DateTime.now())
    );
    
    yield* processText(newHistory, systemContext: systemContext, dynamicContext: dynamicContext, onMetrics: (metrics) {
       final totalTime = DateTime.now().difference(startTime).inMilliseconds;
       onMetrics(PipelineMetrics(
         timeToFirstTokenMs: metrics.timeToFirstTokenMs,
         totalProcessingTimeMs: totalTime,
         peakCpuUsage: metrics.peakCpuUsage,
         peakRamUsageMb: metrics.peakRamUsageMb,
         tokensGenerated: metrics.tokensGenerated,
         tokensPerSecond: metrics.tokensPerSecond,
         promptTokensPerSecond: metrics.promptTokensPerSecond,
       ));
    });
  }

  @override
  Stream<String> processText(List<ChatMessage> history, {required void Function(PipelineMetrics) onMetrics, String? systemContext, String? dynamicContext}) async* {
    if (!_isInitialized || _client == null) throw Exception('Pipeline not initialized');
    
    final startTime = DateTime.now();
    
    final List<LlamaChatMessage> messages = [
      LlamaChatMessage(role: 'system', content: systemContext ?? 'You are a helpful assistant.'),
    ];
    
    final recentHistory = history.length > 6 ? history.sublist(history.length - 6) : history;
    for (int i = 0; i < recentHistory.length; i++) {
      final msg = recentHistory[i];
      if (msg.text.trim().isEmpty) continue;
      
      if (i == recentHistory.length - 1 && dynamicContext != null && dynamicContext.isNotEmpty) {
        messages.add(LlamaChatMessage(role: 'system', content: dynamicContext));
      }
      
      final role = msg.isUser ? 'user' : 'assistant';
      if (messages.last.role == role) {
        messages.last = LlamaChatMessage(role: role, content: '${messages.last.content}\n\n${msg.text}');
      } else {
        messages.add(LlamaChatMessage(role: role, content: msg.text));
      }
    }
    
    int timeToFirstTokenMs = 0;
    double? tokensPerSecond;
    
    final profiler = HardwareProfiler();
    profiler.startTracking();

    try {
      final response = await _client!.chat.completions.create(
        model: 'multimodal',
        messages: messages,
      );
      
      final totalTimeMs = DateTime.now().difference(startTime).inMilliseconds;
      timeToFirstTokenMs = totalTimeMs;
      
      final result = response;
      if (result.choices.isNotEmpty) {
         final content = result.choices.first.message.content.toString();
         final approximatedTokens = content.length ~/ 4;
         if (totalTimeMs > 0) {
            tokensPerSecond = approximatedTokens / (totalTimeMs / 1000.0);
         }
         yield content;
      } else {
         yield "Error: No response generated.";
      }
    } catch (e) {
      yield "Error during generation: $e";
    }
    
    final hwMetrics = profiler.stopTracking();

    onMetrics(PipelineMetrics(
      timeToFirstTokenMs: timeToFirstTokenMs,
      totalProcessingTimeMs: DateTime.now().difference(startTime).inMilliseconds,
      peakCpuUsage: hwMetrics['peakCpu'] ?? 0.0,
      peakRamUsageMb: hwMetrics['peakRamMb'] ?? 0.0,
      tokensPerSecond: tokensPerSecond,
    ));
  }

  @override
  Future<void> dispose() async {
    _client = null;
    _isInitialized = false;
  }
}
