class WorkoutTemplate {
  final int? id;
  final String name;

  const WorkoutTemplate({
    this.id,
    required this.name,
  });

  WorkoutTemplate copyWith({
    int? id,
    String? name,
  }) {
    return WorkoutTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory WorkoutTemplate.fromMap(Map<String, dynamic> map) {
    return WorkoutTemplate(
      id: map['id'] as int?,
      name: map['name'] as String,
    );
  }

  @override
  String toString() {
    return 'WorkoutTemplate(id: $id, name: $name)';
  }
}
