class ProgressPhoto {
  final int? id;
  final String path;
  final String date;
  final String? note;
  final String category;
  final String createdAt;

  ProgressPhoto({
    this.id,
    required this.path,
    required this.date,
    this.note,
    this.category = 'Full Body',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'date': date,
      'note': note,
      'category': category,
      'createdAt': createdAt,
    };
  }

  factory ProgressPhoto.fromMap(Map<String, dynamic> map) {
    return ProgressPhoto(
      id: map['id'] as int?,
      path: map['path'] as String,
      date: map['date'] as String,
      note: map['note'] as String?,
      category: map['category'] as String,
      createdAt: map['createdAt'] as String,
    );
  }

  ProgressPhoto copyWith({
    int? id,
    String? path,
    String? date,
    String? note,
    String? category,
    String? createdAt,
  }) {
    return ProgressPhoto(
      id: id ?? this.id,
      path: path ?? this.path,
      date: date ?? this.date,
      note: note ?? this.note,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
