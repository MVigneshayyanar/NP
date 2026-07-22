import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

/// Provider for user's sensory profile.
final sensoryProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return {};
  try {
    final response = await ApiClient().getSensoryProfile(user.id);
    return response.data as Map<String, dynamic>;
  } catch (e) {
    return {};
  }
});

/// Provider for environment scans list.
final userScansProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return [];
  try {
    final response = await ApiClient().getScans(userId: user.id);
    final data = response.data;
    if (data is List) return data;
    if (data is Map && data.containsKey('results')) return data['results'] as List;
    return [];
  } catch (e) {
    return [];
  }
});

/// Provider for user progress metrics & weekly chart.
/// Django returns flat fields: environment_score, focus_score, sleep_score, mood_score,
/// environment_delta, focus_delta, sleep_delta, mood_delta, weekly_scores.
/// We normalize into {scores: {...}, deltas: {...}, weekly_scores: [...]} for the UI.
final userProgressProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return {};
  try {
    final response = await ApiClient().getProgress(user.id);
    final raw = response.data as Map<String, dynamic>;

    // Normalize Django flat format → nested format expected by UI
    return {
      'scores': {
        'environment': raw['environment_score'],
        'focus': raw['focus_score'],
        'sleep': raw['sleep_score'],
        'mood': raw['mood_score'],
        'comfort': raw['environment_score'], // derived
      },
      'deltas': {
        'environment': raw['environment_delta'],
        'focus': raw['focus_delta'],
        'sleep': raw['sleep_delta'],
        'mood': raw['mood_delta'],
        'comfort': raw['environment_delta'],
      },
      'weekly_scores': raw['weekly_scores'] ?? [],
      'total_scans': raw['total_scans'] ?? 0,
      'current_streak': raw['current_streak'] ?? 0,
      'rooms_scanned': raw['rooms_scanned'] ?? 0,
    };
  } catch (e) {
    return {};
  }
});

/// Provider for AI Recommendations.
final recommendationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return [];
  try {
    final response = await ApiClient().getRecommendations(userId: user.id);
    final data = response.data;
    if (data is List) return data;
    if (data is Map && data.containsKey('results')) return data['results'] as List;
    return [];
  } catch (e) {
    return [];
  }
});
