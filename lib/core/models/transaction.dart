import 'package:uuid/uuid.dart';

class Transaction {
  final String id;
  final double amount;
  final String description;
  final DateTime date;

  Transaction({
    String? id,
    required this.amount,
    required this.description,
    DateTime? date,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now();

  bool get isExpense => amount < 0;
  bool get isIncome => amount > 0;
}
