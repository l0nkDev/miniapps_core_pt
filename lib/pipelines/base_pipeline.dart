import '../core/models/app_models.dart';

abstract class BasePipeline {
  Future<void> init(PipelineConfig config);
  
  // Takes the path to an audio file and processes it
  // Returns the generated text and the metrics
  Stream<String> processAudio(String audioPath, List<ChatMessage> history, {required void Function(PipelineMetrics) onMetrics, String? systemContext});
  
  // Takes text input directly (fallback/testing)
  Stream<String> processText(List<ChatMessage> history, {required void Function(PipelineMetrics) onMetrics, String? systemContext});
  
  Future<void> dispose();
}
