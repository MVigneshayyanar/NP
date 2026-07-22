/// User model matching the Django User model.
class User {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final int? age;
  final String country;
  final String occupation;
  final String? profilePicture;
  final String livingSituation;
  final String propertyStatus;
  final String tier;
  final bool onboardingCompleted;
  final bool notificationsEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.fullName = '',
    this.age,
    this.country = '',
    this.occupation = '',
    this.profilePicture,
    this.livingSituation = '',
    this.propertyStatus = '',
    this.tier = 'residential',
    this.onboardingCompleted = false,
    this.notificationsEnabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      age: json['age'],
      country: json['country'] ?? '',
      occupation: json['occupation'] ?? '',
      profilePicture: json['profile_picture'],
      livingSituation: json['living_situation'] ?? '',
      propertyStatus: json['property_status'] ?? '',
      tier: json['tier'] ?? 'residential',
      onboardingCompleted: json['onboarding_completed'] ?? false,
      notificationsEnabled: json['notifications_enabled'] ?? true,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'age': age,
      'country': country,
      'occupation': occupation,
      'profile_picture': profilePicture,
      'living_situation': livingSituation,
      'property_status': propertyStatus,
      'tier': tier,
      'onboarding_completed': onboardingCompleted,
      'notifications_enabled': notificationsEnabled,
    };
  }

  User copyWith({
    String? fullName,
    int? age,
    String? country,
    String? occupation,
    String? profilePicture,
    String? livingSituation,
    String? propertyStatus,
    bool? onboardingCompleted,
    bool? notificationsEnabled,
  }) {
    return User(
      id: id,
      username: username,
      email: email,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      country: country ?? this.country,
      occupation: occupation ?? this.occupation,
      profilePicture: profilePicture ?? this.profilePicture,
      livingSituation: livingSituation ?? this.livingSituation,
      propertyStatus: propertyStatus ?? this.propertyStatus,
      tier: tier,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
