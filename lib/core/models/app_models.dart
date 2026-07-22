import 'dart:convert';

enum PipelineType { trueMultimodal, sttPipeline }

class PipelineConfig {
  final PipelineType type;
  final String llmModelPath;
  final String? projectorPath; // For true multimodal
  final String? sttModelPath; // For STT pipeline
  final int gpuLayers;

  PipelineConfig({
    required this.type,
    required this.llmModelPath,
    this.projectorPath,
    this.sttModelPath,
    this.gpuLayers = 99,
  });
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final PipelineMetrics? metrics;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.metrics,
  });
}

class PipelineMetrics {
  final String? modelName;
  final int timeToFirstTokenMs;
  final int totalProcessingTimeMs;
  final double peakCpuUsage;
  final double peakRamUsageMb;
  final int? tokensGenerated;
  final double? tokensPerSecond;
  final double? promptTokensPerSecond;

  PipelineMetrics({
    this.modelName,
    required this.timeToFirstTokenMs,
    required this.totalProcessingTimeMs,
    required this.peakCpuUsage,
    required this.peakRamUsageMb,
    this.tokensGenerated,
    this.tokensPerSecond,
    this.promptTokensPerSecond,
  });
}

class ModelStats {
  final String modelName;
  int totalChats;
  int totalTtftMs;
  int totalTokensGenerated;
  int totalGenerationTimeMs;

  ModelStats({
    required this.modelName,
    this.totalChats = 0,
    this.totalTtftMs = 0,
    this.totalTokensGenerated = 0,
    this.totalGenerationTimeMs = 0,
  });

  double get averageTtftMs => totalChats > 0 ? totalTtftMs / totalChats : 0.0;
  double get averageTokensPerSecond =>
      totalGenerationTimeMs > 0 ? (totalTokensGenerated / (totalGenerationTimeMs / 1000.0)) : 0.0;

  Map<String, dynamic> toJson() => {
        'modelName': modelName,
        'totalChats': totalChats,
        'totalTtftMs': totalTtftMs,
        'totalTokensGenerated': totalTokensGenerated,
        'totalGenerationTimeMs': totalGenerationTimeMs,
      };

  factory ModelStats.fromJson(Map<String, dynamic> json) => ModelStats(
        modelName: json['modelName'] as String,
        totalChats: json['totalChats'] as int,
        totalTtftMs: json['totalTtftMs'] as int,
        totalTokensGenerated: json['totalTokensGenerated'] as int,
        totalGenerationTimeMs: json['totalGenerationTimeMs'] as int,
      );
}

class Transaction {
  final String id;
  final double amount;
  final String description;
  final DateTime timestamp;

  Transaction({
    required this.id,
    required this.amount,
    required this.description,
    required this.timestamp,
  });

  bool get isIncome => amount >= 0;
  bool get isExpense => amount < 0;
  DateTime get date => timestamp;

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'],
        amount: json['amount'],
        description: json['description'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}
