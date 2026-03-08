class WorkoutSet {
  final int? id;
  final int workoutId;
  final int exerciseId;
  final int setOrder;
  final int? repetitions;
  final double? weightInKilograms;
  final int? durationInSeconds;
  final double? distanceInMeters;
  final String? notes;

  const WorkoutSet({
    this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.setOrder,
    this.repetitions,
    this.weightInKilograms,
    this.durationInSeconds,
    this.distanceInMeters,
    this.notes,
  });

  WorkoutSet copyWith({
    int? id,
    int? workoutId,
    int? exerciseId,
    int? setOrder,
    int? repetitions,
    double? weightInKilograms,
    int? durationInSeconds,
    double? distanceInMeters,
    String? notes,
  }) {
    return WorkoutSet(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      exerciseId: exerciseId ?? this.exerciseId,
      setOrder: setOrder ?? this.setOrder,
      repetitions: repetitions ?? this.repetitions,
      weightInKilograms: weightInKilograms ?? this.weightInKilograms,
      durationInSeconds: durationInSeconds ?? this.durationInSeconds,
      distanceInMeters: distanceInMeters ?? this.distanceInMeters,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workout_id': workoutId,
      'exercise_id': exerciseId,
      'set_order': setOrder,
      'repetitions': repetitions,
      'weight_kg': weightInKilograms,
      'duration_seconds': durationInSeconds,
      'distance_meters': distanceInMeters,
      'notes': notes,
    };
  }

  factory WorkoutSet.fromMap(Map<String, dynamic> map) {
    return WorkoutSet(
      id: map['id'] as int?,
      workoutId: map['workout_id'] as int,
      exerciseId: map['exercise_id'] as int,
      setOrder: map['set_order'] as int,
      repetitions: map['repetitions'] as int?,
      weightInKilograms: map['weight_kg'] != null
          ? (map['weight_kg'] as num).toDouble()
          : null,
      durationInSeconds: map['duration_seconds'] as int?,
      distanceInMeters: map['distance_meters'] != null
          ? (map['distance_meters'] as num).toDouble()
          : null,
      notes: map['notes'] as String?,
    );
  }

  @override
  String toString() {
    return 'WorkoutSet(id: $id, workoutId: $workoutId, exerciseId: $exerciseId, setOrder: $setOrder)';
  }
}
