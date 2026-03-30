class WeightLog {
  final int? id;
  final String date;
  final double weight;
  final String createdAt;

  WeightLog({
    this.id,
    required this.date,
    required this.weight,
    required this.createdAt,
  });

  factory WeightLog.fromMap(Map<String, dynamic> map) {
    return WeightLog(
      id: map['id'] as int?,
      date: map['date'] as String,
      weight: map['weight'] as double,
      createdAt: map['createdAt'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'weight': weight,
      'createdAt': createdAt,
    };
  }
}
