class Subscription {
  final int? id;
  final String name;
  final double amount;
  final String category;
  final int billingDate; // 1 to 31
  DateTime? lastProcessedDate;

  Subscription({
    this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.billingDate,
    this.lastProcessedDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'category': category,
      'billing_date': billingDate,
      'last_processed_date': lastProcessedDate?.toIso8601String(),
    };
  }

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'],
      name: map['name'],
      amount: (map['amount'] as num).toDouble(),
      category: map['category'],
      billingDate: map['billing_date'] as int,
      lastProcessedDate: map['last_processed_date'] != null 
          ? DateTime.parse(map['last_processed_date']) 
          : null,
    );
  }
}
