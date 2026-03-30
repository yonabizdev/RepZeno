class UserProfile {
  final int? id;
  final String? name;
  final double? height;
  final String? gender;
  final String? dateOfBirth;

  UserProfile({this.id, this.name, this.height, this.gender, this.dateOfBirth});

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as int?,
      name: map['name'] as String?,
      height: map['height'] as double?,
      gender: map['gender'] as String?,
      dateOfBirth: map['dateOfBirth'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'height': height,
      'gender': gender,
      'dateOfBirth': dateOfBirth,
    };
  }
}
