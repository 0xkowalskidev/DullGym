class TemplateSet {
  final int? id;
  final int templateId;
  final int exerciseId;
  final int setOrder;
  final int? targetRepetitions;
  final double? targetWeightInKilograms;
  final int? targetDurationInSeconds;
  final double? targetDistanceInMeters;

  const TemplateSet({
    this.id,
    required this.templateId,
    required this.exerciseId,
    required this.setOrder,
    this.targetRepetitions,
    this.targetWeightInKilograms,
    this.targetDurationInSeconds,
    this.targetDistanceInMeters,
  });

  TemplateSet copyWith({
    int? id,
    int? templateId,
    int? exerciseId,
    int? setOrder,
    int? targetRepetitions,
    double? targetWeightInKilograms,
    int? targetDurationInSeconds,
    double? targetDistanceInMeters,
  }) {
    return TemplateSet(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      exerciseId: exerciseId ?? this.exerciseId,
      setOrder: setOrder ?? this.setOrder,
      targetRepetitions: targetRepetitions ?? this.targetRepetitions,
      targetWeightInKilograms: targetWeightInKilograms ?? this.targetWeightInKilograms,
      targetDurationInSeconds: targetDurationInSeconds ?? this.targetDurationInSeconds,
      targetDistanceInMeters: targetDistanceInMeters ?? this.targetDistanceInMeters,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'template_id': templateId,
      'exercise_id': exerciseId,
      'set_order': setOrder,
      'target_repetitions': targetRepetitions,
      'target_weight_kg': targetWeightInKilograms,
      'target_duration_seconds': targetDurationInSeconds,
      'target_distance_meters': targetDistanceInMeters,
    };
  }

  factory TemplateSet.fromMap(Map<String, dynamic> map) {
    return TemplateSet(
      id: map['id'] as int?,
      templateId: map['template_id'] as int,
      exerciseId: map['exercise_id'] as int,
      setOrder: map['set_order'] as int,
      targetRepetitions: map['target_repetitions'] as int?,
      targetWeightInKilograms: map['target_weight_kg'] != null
          ? (map['target_weight_kg'] as num).toDouble()
          : null,
      targetDurationInSeconds: map['target_duration_seconds'] as int?,
      targetDistanceInMeters: map['target_distance_meters'] != null
          ? (map['target_distance_meters'] as num).toDouble()
          : null,
    );
  }

  @override
  String toString() {
    return 'TemplateSet(id: $id, templateId: $templateId, exerciseId: $exerciseId, setOrder: $setOrder)';
  }
}
