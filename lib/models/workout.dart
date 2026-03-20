class Workout {
  final int? id;
  final String date;

  Workout({this.id, required this.date});

  Map<String, dynamic> toMap() {
    return {if (id != null) 'id': id, 'date': date};
  }

  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(id: map['id'], date: map['date']);
  }
}
