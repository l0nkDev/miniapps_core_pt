import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/models/transaction.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final transactions = state.transactions.reversed.toList(); // Newest first
    
    double totalBalance = transactions.fold(0.0, (sum, t) => sum + t.amount);
    double income = transactions.where((t) => t.isIncome).fold(0.0, (sum, t) => sum + t.amount);
    double expense = transactions.where((t) => t.isExpense).fold(0.0, (sum, t) => sum + t.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryStat('Income', income, Colors.green),
                _SummaryStat('Balance', totalBalance, Colors.blue),
                _SummaryStat('Expense', expense, Colors.red),
              ],
            ),
          ),
          Expanded(
            child: transactions.isEmpty
                ? const Center(child: Text('No transactions yet!\\nAsk the AI to log something for you.'))
                : ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final t = transactions[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: t.isExpense ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                          child: Icon(
                            t.isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                            color: t.isExpense ? Colors.red : Colors.green,
                          ),
                        ),
                        title: Text(t.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(t.date.toString().split('.')[0]), // Basic date/time formatting
                        trailing: Text(
                          '\$${t.amount.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            color: t.isExpense ? Colors.redAccent : Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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

class _SummaryStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _SummaryStat(this.label, this.amount, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          '\$${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
