import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';

class MetricsPanel extends StatelessWidget {
  const MetricsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    
    // Find the latest message with metrics to display globally, or just show active status
    final latestMetrics = state.messages.reversed
        .where((m) => m.metrics != null)
        .firstOrNull?.metrics;

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.black87,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Benchmarking Metrics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: const Icon(Icons.leaderboard, size: 16),
                label: const Text('Leaderboard'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  _showLeaderboard(context, state);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (state.isProcessing)
            const Text('Status: Processing...', style: TextStyle(color: Colors.amber))
          else if (latestMetrics != null)
              Wrap(
                spacing: 12,
                runSpacing: 4,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  if (latestMetrics.sttProcessingTimeMs != null && latestMetrics.sttProcessingTimeMs! > 0)
                     _StatText('STT Time: ${latestMetrics.sttProcessingTimeMs}ms'),
                  _StatText('TTFT: ${latestMetrics.timeToFirstTokenMs}ms'),
                  _StatText('Decoding TPS: ${latestMetrics.tokensPerSecond?.toStringAsFixed(1) ?? "0.0"}'),
                  _StatText('Total: ${latestMetrics.totalProcessingTimeMs}ms'),
                  _StatText('Peak RAM: ${latestMetrics.peakRamUsageMb.toStringAsFixed(1)}MB'),
                ],
              )
            else
            const Text('Status: Idle', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  void _showLeaderboard(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _LeaderboardSheet(),
    );
  }
}

class _LeaderboardSheet extends StatelessWidget {
  const _LeaderboardSheet();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final history = state.benchmarkHistory;

    final List<Map<String, dynamic>> rankings = [];
    
    history.forEach((modelName, metricsList) {
      if (metricsList.isEmpty) return;
      double avgTps = metricsList.map((e) => e.tokensPerSecond ?? 0.0).reduce((a, b) => a + b) / metricsList.length;
      double avgPromptTps = metricsList.map((e) => e.promptTokensPerSecond ?? 0.0).reduce((a, b) => a + b) / metricsList.length;
      double avgTtft = metricsList.map((e) => e.timeToFirstTokenMs).reduce((a, b) => a + b) / metricsList.length;
      
      rankings.add({
        'model': modelName,
        'avgTps': avgTps,
        'avgPromptTps': avgPromptTps,
        'avgTtft': avgTtft,
        'runs': metricsList.length,
      });
    });

    // Sort by highest TPS
    rankings.sort((a, b) => (b['avgTps'] as double).compareTo(a['avgTps'] as double));

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🏆 Model Leaderboard',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          ),
          if (rankings.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No benchmarks recorded yet.\\nRun a prompt to populate the leaderboard!', 
                  textAlign: TextAlign.center, 
                  style: TextStyle(color: Colors.white54)
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: rankings.length,
                itemBuilder: (context, index) {
                  final rank = rankings[index];
                  final isFirst = index == 0;
                  return Card(
                    color: isFirst ? const Color(0xFF2C2C3E) : const Color(0xFF252536),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isFirst ? const BorderSide(color: Colors.amber, width: 1.5) : BorderSide.none,
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '#${index + 1}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isFirst ? Colors.amber : Colors.white54,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  rank['model'] as String,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${(rank['avgTps'] as double).toStringAsFixed(2)} TPS',
                                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                ),
                              )
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Avg TTFT: ${(rank['avgTtft'] as double).toStringAsFixed(0)}ms', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              Text('Prompt Eval: ${(rank['avgPromptTps'] as double).toStringAsFixed(2)} TPS', style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                              Text('Runs: ${rank['runs']}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _StatText extends StatelessWidget {
  final String text;
  const _StatText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: Colors.greenAccent, fontSize: 12));
  }
}
