class Income {
  final int? id;
  final double amount;
  final String source;
  final DateTime date;

  Income({
    this.id,
    required this.amount,
    required this.source,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'source': source,
      'date': date.toIso8601String(),
    };
  }

  factory Income.fromMap(Map<String, dynamic> map) {
    return Income(
      id: map['id'],
      amount: map['amount'],
      source: map['source'],
      date: DateTime.parse(map['date']),
    );
  }
}
