import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';

/// Home screen — greeting, ring gauge, recommendations, quick actions, progress bars.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final firstName = (user?.fullName.isNotEmpty == true
            ? user!.fullName
            : (user?.username ?? 'there'))
        .split(' ')
        .first;

    final progressAsync = ref.watch(userProgressProvider);
    final recsAsync = ref.watch(recommendationsProvider);

    final progressData = progressAsync.valueOrNull;
    final recsList = recsAsync.valueOrNull ?? [];

    final scores = (progressData?['scores'] as Map<String, dynamic>?);
    final deltas = (progressData?['deltas'] as Map<String, dynamic>?);

    final int? envScore = (scores?['environment'] as num?)?.toInt();
    final int? focusScore = (scores?['focus'] as num?)?.toInt();
    final int? sleepScore = (scores?['sleep'] as num?)?.toInt();
    final int? moodScore = (scores?['mood'] as num?)?.toInt();
    final double? envDelta = (deltas?['environment'] as num?)?.toDouble();

    final recTitle = recsList.isNotEmpty
        ? (recsList.first['title'] ?? 'No recommendation available yet')
        : 'Scan a room to get recommendations';
    final recDesc = recsList.isNotEmpty
        ? (recsList.first['action_text'] ?? recsList.first['description'] ?? 'Use room scanner to analyze your space')
        : 'Perform your first room scan using the camera button below to generate personalized AI recommendations.';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getGreeting()},',
                        style: AppTypography.bodyLarge
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      Text(firstName, style: AppTypography.headlineLarge),
                    ],
                  ),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                    child: const Icon(Icons.person_rounded,
                        color: AppColors.primaryGreen),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Environment Score Card matching mockup 4
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF0F1F3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your environment score',
                              style: AppTypography.titleMedium.copyWith(
                                  color: AppColors.textPrimary, fontSize: 15)),
                          const SizedBox(height: 8),
                          Text(
                            envScore != null ? '$envScore%' : '--',
                            style: AppTypography.scoreDisplay.copyWith(
                                color: AppColors.primaryGreen,
                                fontSize: 44,
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            envScore != null
                                ? 'Your environment data is updated from your latest room scan.'
                                : 'No room scan recorded yet. Tap Scan Room to measure your space.',
                            style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: CustomPaint(
                        painter: _ArcGaugePainter(
                          progress: (envScore ?? 0) / 100.0,
                          strokeWidth: 12,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                envScore != null ? (envScore > 75 ? 'Good' : 'Needs Setup') : 'Pending',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                envDelta != null
                                    ? '${envDelta >= 0 ? '+' : ''}${envDelta.toStringAsFixed(0)}% from last\nscan'
                                    : 'Scan required',
                                style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.textSecondary,
                                    height: 1.2),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Today's Recommendation Banner matching mockup 4
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF0F1F3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome,
                                  size: 16, color: AppColors.primaryGreen),
                              const SizedBox(width: 6),
                              Text(
                                'Today Recommendation',
                                style: AppTypography.titleMedium.copyWith(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            recTitle,
                            style: AppTypography.titleMedium.copyWith(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            recDesc,
                            style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Quick Actions matching mockup 4 (Orange scan room icon, Purple view report icon)
              Text('Quick Actions',
                  style: AppTypography.titleLarge.copyWith(fontSize: 17)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.camera_alt_rounded,
                      iconBgColor: const Color(0xFFFF9500),
                      title: 'Scan Room',
                      subtitle: 'Analyze your space\nin seconds',
                      onTap: () => context.push('/scan'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.article_rounded,
                      iconBgColor: const Color(0xFF7C7bad),
                      title: 'View Report',
                      subtitle: 'See AI Insights &\nRecommendations',
                      onTap: () => context.go('/progress'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Your Progress section matching mockup 4
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Your Progress',
                      style: AppTypography.titleLarge.copyWith(fontSize: 17)),
                  const Text('This Week',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryGreen)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF0F1F3)),
                ),
                child: Column(
                  children: [
                    _ProgressRow(
                        icon: Icons.pause_circle_filled_rounded,
                        label: 'Focus',
                        percent: (focusScore ?? 0) / 100.0,
                        scoreText: focusScore != null ? '$focusScore%' : '--'),
                    const SizedBox(height: 20),
                    _ProgressRow(
                        icon: Icons.nightlight_round,
                        label: 'Sleep Quality',
                        percent: (sleepScore ?? 0) / 100.0,
                        scoreText: sleepScore != null ? '$sleepScore%' : '--'),
                    const SizedBox(height: 20),
                    _ProgressRow(
                        icon: Icons.sentiment_satisfied_alt_rounded,
                        label: 'Mood',
                        percent: (moodScore ?? 0) / 100.0,
                        scoreText: moodScore != null ? '$moodScore%' : '--'),
                  ],
                ),

              ),
              const SizedBox(height: 80), // Space for bottom nav
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF0F1F3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 14),
            Text(title, style: AppTypography.titleLarge.copyWith(fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textSecondary, fontSize: 11, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double percent;
  final String scoreText;

  const _ProgressRow({
    required this.icon,
    required this.label,
    required this.percent,
    required this.scoreText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: AppTypography.titleMedium.copyWith(fontSize: 14)),
                  Text(scoreText,
                      style: AppTypography.titleMedium.copyWith(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percent,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primaryGreen),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Teal arc gauge painter matching mockup image 4
class _ArcGaugePainter extends CustomPainter {
  final double progress;
  final double strokeWidth;

  _ArcGaugePainter({required this.progress, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Gray background arc
    final bgPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2 * pi,
      false,
      bgPaint,
    );

    // Teal progress arc matching mockup 4 & 6
    final progressPaint = Paint()
      ..color = const Color(0xFF00BBA7)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi * 0.7,
      2 * pi * progress * 0.8,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainter old) => old.progress != progress;
}


