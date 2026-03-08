enum ExerciseType {
  repetitionBased,
  timeBased,
  weightedRepetitions,
  distanceBased,
}

class Exercise {
  final int? id;
  final String name;
  final ExerciseType type;
  final String? muscleGroup;
  final String? notes;

  const Exercise({
    this.id,
    required this.name,
    required this.type,
    this.muscleGroup,
    this.notes,
  });

  Exercise copyWith({
    int? id,
    String? name,
    ExerciseType? type,
    String? muscleGroup,
    String? notes,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'muscle_group': muscleGroup,
      'notes': notes,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: ExerciseType.values.firstWhere(
        (exerciseType) => exerciseType.name == map['type'],
        orElse: () => throw StateError('Unknown exercise type: ${map['type']}'),
      ),
      muscleGroup: map['muscle_group'] as String?,
      notes: map['notes'] as String?,
    );
  }

  @override
  String toString() {
    return 'Exercise(id: $id, name: $name, type: $type, muscleGroup: $muscleGroup)';
  }
}
