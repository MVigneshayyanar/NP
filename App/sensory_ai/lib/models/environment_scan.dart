/// Environment scan model matching the Django EnvironmentScan model.
class EnvironmentScan {
  final String id;
  final String userId;
  final String imageRef;
  final String audioRef;
  final Map<String, dynamic> llmOutput;
  final int environmentScore;
  final int focusScore;
  final int sleepScore;
  final int moodScore;
  final List<ColorMatch> colorMatches;
  final String roomName;
  final List<Recommendation> recommendations;
  final DateTime createdAt;

  EnvironmentScan({
    required this.id,
    required this.userId,
    this.imageRef = '',
    this.audioRef = '',
    this.llmOutput = const {},
    this.environmentScore = 0,
    this.focusScore = 0,
    this.sleepScore = 0,
    this.moodScore = 0,
    this.colorMatches = const [],
    this.roomName = '',
    this.recommendations = const [],
    required this.createdAt,
  });

  factory EnvironmentScan.fromJson(Map<String, dynamic> json) {
    return EnvironmentScan(
      id: json['id'] ?? json['scan_id'] ?? '',
      userId: json['user'] ?? '',
      imageRef: json['image_ref'] ?? '',
      audioRef: json['audio_ref'] ?? '',
      llmOutput: json['llm_output'] ?? {},
      environmentScore: json['environment_score'] ?? 0,
      focusScore: json['focus_score'] ?? 0,
      sleepScore: json['sleep_score'] ?? 0,
      moodScore: json['mood_score'] ?? 0,
      colorMatches: (json['color_matches'] as List<dynamic>?)
              ?.map((e) => ColorMatch.fromJson(e))
              .toList() ??
          [],
      roomName: json['room_name'] ?? '',
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((e) => Recommendation.fromJson(e))
              .toList() ??
          [],
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Recommendation from an environment scan.
class Recommendation {
  final String id;
  final String scanId;
  final String category;
  final String priority;
  final String title;
  final String actionText;
  final bool isApplied;
  final bool isDismissed;

  Recommendation({
    this.id = '',
    this.scanId = '',
    required this.category,
    required this.priority,
    required this.title,
    required this.actionText,
    this.isApplied = false,
    this.isDismissed = false,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['id'] ?? '',
      scanId: json['scan'] ?? '',
      category: json['category'] ?? '',
      priority: json['priority'] ?? 'medium',
      title: json['title'] ?? '',
      actionText: json['action_text'] ?? json['action'] ?? '',
      isApplied: json['is_applied'] ?? false,
      isDismissed: json['is_dismissed'] ?? false,
    );
  }
}

/// Color match result from the paint database.
class ColorMatch {
  final String aiHex;
  final String paintName;
  final String paintCode;
  final String paintBrand;
  final String paintHex;
  final double lrv;
  final double deltaE;

  ColorMatch({
    required this.aiHex,
    required this.paintName,
    required this.paintCode,
    required this.paintBrand,
    required this.paintHex,
    required this.lrv,
    required this.deltaE,
  });

  factory ColorMatch.fromJson(Map<String, dynamic> json) {
    return ColorMatch(
      aiHex: json['ai_hex'] ?? '',
      paintName: json['paint_name'] ?? '',
      paintCode: json['paint_code'] ?? '',
      paintBrand: json['paint_brand'] ?? '',
      paintHex: json['paint_hex'] ?? '',
      lrv: (json['lrv'] as num?)?.toDouble() ?? 0.0,
      deltaE: (json['delta_e'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Progress data for the progress screen.
class ProgressData {
  final int environmentScore;
  final int focusScore;
  final int sleepScore;
  final int moodScore;
  final double environmentDelta;
  final double focusDelta;
  final double sleepDelta;
  final double moodDelta;
  final List<WeeklyScore> weeklyScores;
  final int totalScans;
  final int currentStreak;
  final int roomsScanned;

  ProgressData({
    this.environmentScore = 0,
    this.focusScore = 0,
    this.sleepScore = 0,
    this.moodScore = 0,
    this.environmentDelta = 0.0,
    this.focusDelta = 0.0,
    this.sleepDelta = 0.0,
    this.moodDelta = 0.0,
    this.weeklyScores = const [],
    this.totalScans = 0,
    this.currentStreak = 0,
    this.roomsScanned = 0,
  });

  factory ProgressData.fromJson(Map<String, dynamic> json) {
    return ProgressData(
      environmentScore: json['environment_score'] ?? 0,
      focusScore: json['focus_score'] ?? 0,
      sleepScore: json['sleep_score'] ?? 0,
      moodScore: json['mood_score'] ?? 0,
      environmentDelta: (json['environment_delta'] as num?)?.toDouble() ?? 0.0,
      focusDelta: (json['focus_delta'] as num?)?.toDouble() ?? 0.0,
      sleepDelta: (json['sleep_delta'] as num?)?.toDouble() ?? 0.0,
      moodDelta: (json['mood_delta'] as num?)?.toDouble() ?? 0.0,
      weeklyScores: (json['weekly_scores'] as List<dynamic>?)
              ?.map((e) => WeeklyScore.fromJson(e))
              .toList() ??
          [],
      totalScans: json['total_scans'] ?? 0,
      currentStreak: json['current_streak'] ?? 0,
      roomsScanned: json['rooms_scanned'] ?? 0,
    );
  }
}

/// Weekly score data point for chart rendering.
class WeeklyScore {
  final String date;
  final int environment;
  final int focus;
  final int sleep;
  final int mood;

  WeeklyScore({
    required this.date,
    this.environment = 0,
    this.focus = 0,
    this.sleep = 0,
    this.mood = 0,
  });

  factory WeeklyScore.fromJson(Map<String, dynamic> json) {
    return WeeklyScore(
      date: json['date'] ?? '',
      environment: json['environment'] ?? 0,
      focus: json['focus'] ?? 0,
      sleep: json['sleep'] ?? 0,
      mood: json['mood'] ?? 0,
    );
  }
}
