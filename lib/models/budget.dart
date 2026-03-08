class Budget {
  final int? id;
  final String category;
  final double monthlyLimit;

  Budget({this.id, required this.category, required this.monthlyLimit});

  Map<String, dynamic> toMap() {
    return {'id': id, 'category': category, 'monthly_limit': monthlyLimit};
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      category: map['category'],
      monthlyLimit: map['monthly_limit'],
    );
  }
}
