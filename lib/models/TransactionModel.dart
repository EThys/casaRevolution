class Transaction {
  final DateTime date;
  final String landlord;
  final double amount;
  final String type;

  Transaction({
    required this.date,
    required this.landlord,
    required this.amount,
    required this.type,
  });
}