import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../providers/data_providers.dart';

/// Progress screen — ring gauge, metric cards with deltas, weekly line chart.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(userProgressProvider);
    final progressData = progressAsync.valueOrNull;
    final scores = (progressData?['scores'] as Map<String, dynamic>?);
    final deltas = (progressData?['deltas'] as Map<String, dynamic>?);

    final int? envScore = (scores?['environment'] as num?)?.toInt();
    final int? focusScore = (scores?['focus'] as num?)?.toInt();
    final int? sleepScore = (scores?['sleep'] as num?)?.toInt();
    final int? moodScore = (scores?['mood'] as num?)?.toInt();
    final int? comfortScore = (scores?['comfort'] as num?)?.toInt();

    final double focusDelta = (deltas?['focus'] as num?)?.toDouble() ?? 0.0;
    final double sleepDelta = (deltas?['sleep'] as num?)?.toDouble() ?? 0.0;
    final double moodDelta = (deltas?['mood'] as num?)?.toDouble() ?? 0.0;
    final double comfortDelta = (deltas?['comfort'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Progress')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Environment Score Ring
            Center(
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: CustomPaint(
                    painter: _RingPainter(progress: (envScore ?? 0) / 100.0),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            envScore != null ? '$envScore%' : '--',
                            style: AppTypography.scoreMedium
                                .copyWith(color: AppColors.primaryGreen),
                          ),
                          Text('Overall',
                              style: AppTypography.labelSmall
                                  .copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Metric mini-cards matching mockup image 6 (Brown icons on cards)
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'FOCUS',
                    value: focusScore,
                    delta: focusDelta,
                    icon: Icons.pause_circle_filled_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'SLEEP',
                    value: sleepScore,
                    delta: sleepDelta,
                    icon: Icons.nightlight_round,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'MOOD',
                    value: moodScore,
                    delta: moodDelta,
                    icon: Icons.sentiment_satisfied_alt_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'COMFORT',
                    value: comfortScore,
                    delta: comfortDelta,
                    icon: Icons.spa_rounded,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),


            // Weekly Improvement Chart matching mockup 6
            Text('Weekly Improvement',
                style: AppTypography.titleLarge.copyWith(fontSize: 17)),
            Text('Last 7 Days',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            Builder(builder: (context) {
              final weeklyRaw = (progressData?['weekly_scores'] as List<dynamic>?) ?? [];
              // Build FlSpots from real backend data
              final spots = <FlSpot>[];
              for (int i = 0; i < weeklyRaw.length; i++) {
                final entry = weeklyRaw[i] as Map<String, dynamic>;
                final score = (entry['environment'] as num?)?.toDouble() ?? 0;
                spots.add(FlSpot(i.toDouble(), score));
              }

              if (spots.isEmpty) {
                return Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF0F1F3)),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bar_chart_rounded,
                            size: 48, color: AppColors.primaryGreen),
                        const SizedBox(height: 12),
                        Text(
                          'No scan history yet',
                          style: AppTypography.titleMedium.copyWith(
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Scan a room to start tracking your progress',
                          style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Container(
                height: 220,
                padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF0F1F3)),
                ),
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (spots.length - 1).toDouble(),
                    minY: 0,
                    maxY: 100,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: AppColors.primaryGreen,
                        barWidth: 2,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                            radius: 3,
                            color: AppColors.primaryGreen,
                            strokeWidth: 1,
                            strokeColor: Colors.white,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.primaryGreen.withOpacity(0.4),
                              AppColors.primaryGreen.withOpacity(0.05),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 80),


          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final int? value;
  final double delta;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.delta,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0F1F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Brown icon container matching mockup 6
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFC7844C),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              Row(
                children: [
                  const Icon(Icons.arrow_upward_rounded,
                      size: 14, color: AppColors.primaryGreen),
                  Text(
                    '${delta.abs().toStringAsFixed(0)}%',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label.toUpperCase(),
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value != null ? '$value%' : '--',
            style: AppTypography.titleLarge
                .copyWith(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}


class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;

    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = AppColors.ringBackground
          ..strokeWidth = 12
          ..style = PaintingStyle.stroke);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = AppColors.primaryGreen
        ..strokeWidth = 12
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}
