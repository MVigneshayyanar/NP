/// Sensory profile model matching the Django SensoryProfile model.
class SensoryProfile {
  final String id;
  final String userId;
  final int lightSensitivity;
  final int soundSensitivity;
  final int textureSensitivity;
  final int colorSensitivity;
  final List<String> goals;
  final String? dailyRoutineStart;
  final String? dailyRoutineEnd;
  final String? bedtime;
  final double? sleepDurationHours;

  SensoryProfile({
    this.id = '',
    this.userId = '',
    this.lightSensitivity = 50,
    this.soundSensitivity = 50,
    this.textureSensitivity = 50,
    this.colorSensitivity = 50,
    this.goals = const [],
    this.dailyRoutineStart,
    this.dailyRoutineEnd,
    this.bedtime,
    this.sleepDurationHours,
  });

  factory SensoryProfile.fromJson(Map<String, dynamic> json) {
    return SensoryProfile(
      id: json['id'] ?? '',
      userId: json['user'] ?? '',
      lightSensitivity: json['light_sensitivity'] ?? 50,
      soundSensitivity: json['sound_sensitivity'] ?? 50,
      textureSensitivity: json['texture_sensitivity'] ?? 50,
      colorSensitivity: json['color_sensitivity'] ?? 50,
      goals: List<String>.from(json['goals'] ?? []),
      dailyRoutineStart: json['daily_routine_start'],
      dailyRoutineEnd: json['daily_routine_end'],
      bedtime: json['bedtime'],
      sleepDurationHours: (json['sleep_duration_hours'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'light_sensitivity': lightSensitivity,
      'sound_sensitivity': soundSensitivity,
      'texture_sensitivity': textureSensitivity,
      'color_sensitivity': colorSensitivity,
      'goals': goals,
      'daily_routine_start': dailyRoutineStart,
      'daily_routine_end': dailyRoutineEnd,
      'bedtime': bedtime,
      'sleep_duration_hours': sleepDurationHours,
    };
  }

  SensoryProfile copyWith({
    int? lightSensitivity,
    int? soundSensitivity,
    int? textureSensitivity,
    int? colorSensitivity,
    List<String>? goals,
    String? dailyRoutineStart,
    String? dailyRoutineEnd,
    String? bedtime,
    double? sleepDurationHours,
  }) {
    return SensoryProfile(
      id: id,
      userId: userId,
      lightSensitivity: lightSensitivity ?? this.lightSensitivity,
      soundSensitivity: soundSensitivity ?? this.soundSensitivity,
      textureSensitivity: textureSensitivity ?? this.textureSensitivity,
      colorSensitivity: colorSensitivity ?? this.colorSensitivity,
      goals: goals ?? this.goals,
      dailyRoutineStart: dailyRoutineStart ?? this.dailyRoutineStart,
      dailyRoutineEnd: dailyRoutineEnd ?? this.dailyRoutineEnd,
      bedtime: bedtime ?? this.bedtime,
      sleepDurationHours: sleepDurationHours ?? this.sleepDurationHours,
    );
  }
}
