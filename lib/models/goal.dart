class Goal {
  final int? id;
  final String title;
  final double targetAmount;
  final double savedAmount;

  Goal({
    this.id,
    required this.title,
    required this.targetAmount,
    required this.savedAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'target_amount': targetAmount,
      'saved_amount': savedAmount,
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'],
      title: map['title'],
      targetAmount: (map['target_amount'] as num).toDouble(),
      savedAmount: (map['saved_amount'] as num).toDouble(),
    );
  }
}
