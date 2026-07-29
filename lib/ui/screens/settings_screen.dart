import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/models/app_models.dart';
import '../../core/services/download_manager.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Models')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Active Architecture', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          // ignore: deprecated_member_use
          RadioListTile<PipelineType>(
            title: const Text('STT + Text LLM Pipeline'),
            subtitle: const Text('Requires Whisper model + base model'),
            value: PipelineType.sttPipeline,
            groupValue: state.activePipeline,
            onChanged: (v) => state.setActivePipeline(v!),
          ),
          
          const Divider(),
          const Text('Downloads Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('Text SLMs', style: TextStyle(fontWeight: FontWeight.bold)),
          _PresetDownloader(
            name: 'Gemma 4 E4B IT (Text LLM)',
            url: 'https://huggingface.co/bartowski/gemma-4-e4b-it-GGUF/resolve/main/gemma-4-e4b-it-q4_k_m.gguf',
            filename: 'gemma-4-e4b-it-q4_k_m.gguf',
            isSelected: state.selectedLlmPath?.endsWith('gemma-4-e4b-it-q4_k_m.gguf') ?? false,
            onDownloaded: (path) => state.setModelPaths(llmPath: path),
          ),
          _PresetDownloader(
            name: 'Gemma 4 E2B IT (Text LLM)',
            url: 'https://huggingface.co/bartowski/gemma-4-e2b-it-GGUF/resolve/main/gemma-4-e2b-it-q4_k_m.gguf',
            filename: 'gemma-4-e2b-it-q4_k_m.gguf',
            isSelected: state.selectedLlmPath?.endsWith('gemma-4-e2b-it-q4_k_m.gguf') ?? false,
            onDownloaded: (path) => state.setModelPaths(llmPath: path),
          ),
          _PresetDownloader(
            name: 'Qwen 3 4B Instruct (Text LLM)',
            url: 'https://huggingface.co/Qwen/Qwen3-4B-Instruct-GGUF/resolve/main/qwen3-4b-instruct-q4_k_m.gguf',
            filename: 'qwen3-4b-instruct-q4_k_m.gguf',
            isSelected: state.selectedLlmPath?.endsWith('qwen3-4b-instruct-q4_k_m.gguf') ?? false,
            onDownloaded: (path) => state.setModelPaths(llmPath: path),
          ),
          _PresetDownloader(
            name: 'Qwen 3 1.7B Instruct (Text LLM)',
            url: 'https://huggingface.co/Qwen/Qwen3-1.7B-Instruct-GGUF/resolve/main/qwen3-1.7b-instruct-q4_k_m.gguf',
            filename: 'qwen3-1.7b-instruct-q4_k_m.gguf',
            isSelected: state.selectedLlmPath?.endsWith('qwen3-1.7b-instruct-q4_k_m.gguf') ?? false,
            onDownloaded: (path) => state.setModelPaths(llmPath: path),
          ),
          _PresetDownloader(
            name: 'Qwen 2.5 3B Instruct (Text LLM)',
            url: 'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf',
            filename: 'qwen2.5-3b-instruct-q4_k_m.gguf',
            isSelected: state.selectedLlmPath?.endsWith('qwen2.5-3b-instruct-q4_k_m.gguf') ?? false,
            onDownloaded: (path) => state.setModelPaths(llmPath: path),
          ),
          _PresetDownloader(
            name: 'Qwen 2.5 1.5B Instruct (Text LLM)',
            url: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
            filename: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
            isSelected: state.selectedLlmPath?.endsWith('qwen2.5-1.5b-instruct-q4_k_m.gguf') ?? false,
            onDownloaded: (path) => state.setModelPaths(llmPath: path),
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 8),
          const Text('Speech-To-Text Models (Multilingual/Spanish)', style: TextStyle(fontWeight: FontWeight.bold)),
          _PresetDownloader(
            name: 'Whisper Tiny (Multi)',
            url: 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin',
            filename: 'ggml-tiny.bin',
            isSelected: state.selectedSttPath?.endsWith('ggml-tiny.bin') ?? false,
            onDownloaded: (path) => state.setModelPaths(sttPath: path),
          ),
          _PresetDownloader(
            name: 'Whisper Base (Multi)',
            url: 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin',
            filename: 'ggml-base.bin',
            isSelected: state.selectedSttPath?.endsWith('ggml-base.bin') ?? false,
            onDownloaded: (path) => state.setModelPaths(sttPath: path),
          ),
          _PresetDownloader(
            name: 'Whisper Small (Multi)',
            url: 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin',
            filename: 'ggml-small.bin',
            isSelected: state.selectedSttPath?.endsWith('ggml-small.bin') ?? false,
            onDownloaded: (path) => state.setModelPaths(sttPath: path),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              labelText: 'Base LLM Path (.gguf)',
              border: const OutlineInputBorder(),
              hintText: state.selectedLlmPath ?? 'Not set',
            ),
            onChanged: (v) => state.setModelPaths(llmPath: v),
          ),
          const SizedBox(height: 8),
          if (state.activePipeline == PipelineType.trueMultimodal)
            TextField(
              decoration: InputDecoration(
                labelText: 'Projector Path (.mmproj)',
                border: const OutlineInputBorder(),
                hintText: state.selectedProjectorPath ?? 'Not set',
              ),
              onChanged: (v) => state.setModelPaths(projectorPath: v),
            ),
          if (state.activePipeline == PipelineType.sttPipeline)
            TextField(
              decoration: InputDecoration(
                labelText: 'Whisper Model Path (.bin)',
                border: const OutlineInputBorder(),
                hintText: state.selectedSttPath ?? 'Not set',
              ),
              onChanged: (v) => state.setModelPaths(sttPath: v),
            ),
            
          const SizedBox(height: 24),
          const Divider(),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Model Download Manager UI (Custom URLs) To be implemented')));
            },
            child: const Text('Open Custom Downloads'),
          ),
          const Divider(),
          const Text('Performance Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('GPU Layers', style: TextStyle(fontWeight: FontWeight.bold)),
          const Text('Increase to offload to GPU. If the app crashes on large models, lower this value.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          Slider(
            value: state.gpuLayers.toDouble(),
            min: 0,
            max: 99,
            divisions: 99,
            label: state.gpuLayers.toString(),
            onChanged: (value) {
              state.setModelPaths(gpuLayers: value.toInt());
            },
          ),
          const SizedBox(height: 16),
          const Divider(),
          const Text('Native Voice Engine', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text('Use Native Speech-to-Text'),
            subtitle: const Text('Instantly transcribe audio using your device\'s native engine. Bypasses Whisper. Requires offline language pack.'),
            value: state.useNativeSTT,
            onChanged: (val) => state.setNativeToggles(stt: val),
          ),
          SwitchListTile(
            title: const Text('Use Native Text-to-Speech'),
            subtitle: const Text('Read AI responses out loud automatically. Requires offline language pack.'),
            value: state.useNativeTTS,
            onChanged: (val) => state.setNativeToggles(tts: val),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: state.isInitializingPipeline ? null : () async {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loading Pipeline... Please wait.')));
              await state.loadPipeline();
              if (context.mounted) {
                if (state.isPipelineLoaded) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pipeline Loaded Into Memory!')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load pipeline: ${state.pipelineError ?? "Unknown error"}')));
                }
              }
            },
            child: state.isInitializingPipeline 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Load Pipeline into Memory'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetDownloader extends StatefulWidget {
  final String name;
  final String url;
  final String filename;
  final bool isSelected;
  final Function(String) onDownloaded;

  const _PresetDownloader({
    required this.name,
    required this.url,
    required this.filename,
    this.isSelected = false,
    required this.onDownloaded,
  });

  @override
  State<_PresetDownloader> createState() => _PresetDownloaderState();
}

class _PresetDownloaderState extends State<_PresetDownloader> {
  double _progress = 0;
  bool _isDownloading = false;
  bool _isDownloaded = false;
  String? _downloadedPath;
  
  int _receivedBytes = 0;
  int _totalBytes = 0;
  double _speedMBps = 0.0;

  @override
  void initState() {
    super.initState();
    _checkIfDownloaded();
  }

  void _checkIfDownloaded() async {
    final manager = DownloadManager();
    final modelsDirPath = await manager.getModelsDirectory();
    final file = File('$modelsDirPath/${widget.filename}');
    if (await file.exists()) {
      if (mounted) {
        setState(() {
          _isDownloaded = true;
          _progress = 1.0;
          _downloadedPath = file.path;
        });
      }
    }
  }

  void _startDownload() async {
    setState(() {
      _isDownloading = true;
    });
    
    final manager = DownloadManager();
    final path = await manager.downloadModel(
      widget.url,
      widget.filename,
      (progress, received, total, speed) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _receivedBytes = received;
            _totalBytes = total;
            _speedMBps = speed;
          });
        }
      },
    );

    if (path != null) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isDownloaded = true;
          _progress = 1.0;
          _downloadedPath = path;
        });
      }
      widget.onDownloaded(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.name} selected!')));
      }
    } else {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download failed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String formatBytes(int bytes) {
      if (bytes == 0) return '0 B';
      final double mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} MB';
    }

    Widget subtitle;
    if (_isDownloading) {
      subtitle = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 4),
          Text(
            '${(_progress * 100).toStringAsFixed(1)}% - ${formatBytes(_receivedBytes)} / ${formatBytes(_totalBytes)} @ ${_speedMBps.toStringAsFixed(2)} MB/s',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      );
    } else {
      subtitle = Text(_isDownloaded ? 'Downloaded' : 'Not downloaded');
    }

    return Card(
      child: ListTile(
        title: Text(widget.name),
        subtitle: subtitle,
        trailing: _isDownloaded
            ? (widget.isSelected 
                ? const Icon(Icons.radio_button_checked, color: Colors.green)
                : IconButton(
                    icon: const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                    onPressed: () {
                      if (_downloadedPath != null) {
                        widget.onDownloaded(_downloadedPath!);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.name} selected!')));
                      }
                    },
                  ))
            : IconButton(
                icon: const Icon(Icons.download),
                onPressed: _isDownloading ? null : _startDownload,
              ),
      ),
    );
  }
}
