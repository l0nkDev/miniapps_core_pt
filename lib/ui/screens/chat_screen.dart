import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/models/app_models.dart';
import '../widgets/metrics_panel.dart';
import 'transactions_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Uuid _uuid = const Uuid();

  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  Future<void> _showModelSwapPopup() async {
    final state = context.read<AppState>();
    final models = await state.getAvailableModels();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        PipelineType activeTab = state.activePipeline;
        String? currentLlm = state.selectedLlmPath;
        String? currentProjector = state.selectedProjectorPath;
        String? currentStt = state.selectedSttPath;

        return StatefulBuilder(
          builder: (context, setModalState) {
            bool isValid = false;
            if (activeTab == PipelineType.trueMultimodal) {
              isValid = currentLlm != null && currentProjector != null;
            } else {
              isValid = currentLlm != null && currentStt != null;
            }

            return Padding(
              padding: const EdgeInsets.all(
                16.0,
              ).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Quick Model Swapper',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  SegmentedButton<PipelineType>(
                    segments: const [
                      ButtonSegment(
                        value: PipelineType.trueMultimodal,
                        label: Text('Multimodal'),
                      ),
                      ButtonSegment(
                        value: PipelineType.sttPipeline,
                        label: Text('Voice (STT+LLM)'),
                      ),
                    ],
                    selected: {activeTab},
                    onSelectionChanged: (Set<PipelineType> newSelection) {
                      setModalState(() {
                        activeTab = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  if (activeTab == PipelineType.trueMultimodal) ...[
                    const Text(
                      'Multimodal Base LLM (Required)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    DropdownButton<String>(
                      isExpanded: true,
                      value:
                          models['llms']!
                              .where(
                                (p) =>
                                    p.toLowerCase().contains('llava') ||
                                    p.toLowerCase().contains('moondream'),
                              )
                              .contains(currentLlm)
                          ? currentLlm
                          : null,
                      hint: const Text('Select Multimodal Base LLM'),
                      items: models['llms']!
                          .where(
                            (p) =>
                                p.toLowerCase().contains('llava') ||
                                p.toLowerCase().contains('moondream'),
                          )
                          .map(
                            (path) => DropdownMenuItem(
                              value: path,
                              child: Text(
                                path.split('/').last,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setModalState(() => currentLlm = val),
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'Multimodal Projector (Required)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: models['projectors']!.contains(currentProjector)
                          ? currentProjector
                          : null,
                      hint: const Text('Select Projector'),
                      items: models['projectors']!
                          .map(
                            (path) => DropdownMenuItem(
                              value: path,
                              child: Text(
                                path.split('/').last,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setModalState(() => currentProjector = val),
                    ),
                  ] else ...[
                    const Text(
                      'Base Text LLM (Required)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    DropdownButton<String>(
                      isExpanded: true,
                      value:
                          models['llms']!
                              .where(
                                (p) =>
                                    !p.toLowerCase().contains('llava') &&
                                    !p.toLowerCase().contains('moondream'),
                              )
                              .contains(currentLlm)
                          ? currentLlm
                          : null,
                      hint: const Text('Select Text LLM'),
                      items: models['llms']!
                          .where(
                            (p) =>
                                !p.toLowerCase().contains('llava') &&
                                !p.toLowerCase().contains('moondream'),
                          )
                          .map(
                            (path) => DropdownMenuItem(
                              value: path,
                              child: Text(
                                path.split('/').last,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setModalState(() => currentLlm = val),
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'Whisper STT (Required)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: models['stt']!.contains(currentStt)
                          ? currentStt
                          : null,
                      hint: const Text('Select STT Model'),
                      items: models['stt']!
                          .map(
                            (path) => DropdownMenuItem(
                              value: path,
                              child: Text(
                                path.split('/').last,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setModalState(() => currentStt = val),
                    ),
                  ],
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: isValid
                        ? () {
                            Navigator.pop(context);
                            state.quickSwapModel(
                              pipelineType: activeTab,
                              llmPath: currentLlm,
                              projectorPath: currentProjector,
                              sttPath: currentStt,
                            );
                          }
                        : null,
                    child: const Text('Swap Models & Reload'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _sendMessage(String text) {
    if (text.isEmpty) return;

    final state = context.read<AppState>();
    state.addMessage(
      ChatMessage(
        id: _uuid.v4(),
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ),
    );
    _textController.clear();
    _scrollToBottom();

    _processInput(text: text);
  }

  void _processInput({String? text, String? audioPath}) {
    final state = context.read<AppState>();

    if (!state.isPipelineLoaded || state.activePipelineInstance == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Load pipeline first!')));
      return;
    }

    state.setProcessing(true);

    final responseId = _uuid.v4();
    String currentResponse = '';
    PipelineMetrics? currentMetrics;

    void onMetrics(PipelineMetrics m) {
      currentMetrics = m;
    }

    final systemContext = state.getTransactionHistoryContext();
    Stream<String> stream;
    if (audioPath != null) {
      stream = state.activePipelineInstance!.processAudio(
        audioPath,
        [...state.messages],
        systemContext: systemContext,
        onMetrics: onMetrics,
      );
    } else {
      stream = state.activePipelineInstance!.processText(
        [...state.messages],
        systemContext: systemContext,
        onMetrics: onMetrics,
      );
    }

    // Create an initial message bubble right away so the user sees it's working
    state.addMessage(
      ChatMessage(
        id: responseId,
        text: 'Thinking...',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );

    stream.listen(
      (chunk) {
        currentResponse += chunk;
        state.updateMessage(responseId, currentResponse);
        _scrollToBottom();
      },
      onDone: () {
        state.setProcessing(false);
        if (currentResponse.isEmpty) {
          state.updateMessage(responseId, 'Error: Empty response generated.');
        } else {
          state.updateMessageMetrics(responseId, currentMetrics);
          if (currentMetrics != null) {
            state.recordMetrics(currentMetrics!);
          }
          // Parse response for any transaction commands
          state.parseMessageForTransaction(currentResponse);
        }
        _scrollToBottom();
      },
      onError: (e) {
        state.setProcessing(false);
        state.updateMessage(responseId, 'Error processing input: $e');
        _scrollToBottom();
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleRecording() async {
    final state = context.read<AppState>();
    if (state.isProcessing || !state.isPipelineLoaded) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Load pipeline first!')));
      return;
    }

    if (_isRecording) {
      // Stop recording
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      if (path != null) {
        // Pass directly to pipeline (already 16kHz mono WAV)
        _processInput(audioPath: path);
      }
    } else {
      // Start recording
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final inPath =
            '${dir.path}/audio_raw_${DateTime.now().millisecondsSinceEpoch}.wav';
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: inPath,
        );
        setState(() {
          _isRecording = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.activePipeline == PipelineType.trueMultimodal
              ? 'True Multimodal'
              : 'STT + LLM Pipeline',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_calls),
            onPressed: state.isProcessing ? null : _showModelSwapPopup,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              context.read<AppState>().clearMessages();
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TransactionsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          const MetricsPanel(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: state.messages.length,
              itemBuilder: (context, index) {
                final msg = state.messages[index];
                return Align(
                  alignment: msg.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: msg.isUser ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(msg.text),
                        if (msg.metrics != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'TTFT: ${msg.metrics!.timeToFirstTokenMs}ms | Total: ${msg.metrics!.totalProcessingTimeMs}ms',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            'CPU: ${msg.metrics!.peakCpuUsage}% | RAM: ${msg.metrics!.peakRamUsageMb}MB',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (state.isProcessing)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_isRecording ? Icons.stop_circle : Icons.mic),
                  color: _isRecording ? Colors.red : null,
                  onPressed: state.isProcessing ? null : _toggleRecording,
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: state.isPipelineLoaded
                          ? 'Type a message...'
                          : 'Load Pipeline first from settings...',
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (state.isProcessing || !state.isPipelineLoaded)
                        ? null
                        : _sendMessage,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: (state.isProcessing || !state.isPipelineLoaded)
                      ? null
                      : () => _sendMessage(_textController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
