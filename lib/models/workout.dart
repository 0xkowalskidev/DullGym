class Workout {
  final int? id;
  final DateTime date;
  final String? notes;
  final int durationInSeconds;

  const Workout({
    this.id,
    required this.date,
    this.notes,
    this.durationInSeconds = 0,
  });

  Workout copyWith({
    int? id,
    DateTime? date,
    String? notes,
    int? durationInSeconds,
  }) {
    return Workout(
      id: id ?? this.id,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      durationInSeconds: durationInSeconds ?? this.durationInSeconds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'notes': notes,
      'duration_seconds': durationInSeconds,
    };
  }

  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      notes: map['notes'] as String?,
      durationInSeconds: map['duration_seconds'] as int? ?? 0,
    );
  }

  @override
  String toString() {
    return 'Workout(id: $id, date: $date, durationInSeconds: $durationInSeconds)';
  }
}
