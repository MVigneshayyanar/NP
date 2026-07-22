import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';


/// Profile screen — avatar, stats, goals, settings.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final scansAsync = ref.watch(userScansProvider);
    final progressAsync = ref.watch(userProgressProvider);

    final scansList = scansAsync.valueOrNull ?? [];
    final progressData = progressAsync.valueOrNull ?? {};
    final scores = (progressData['scores'] as Map<String, dynamic>?) ?? {};
    final envScore = (scores['environment'] as num?)?.toInt() ?? 85;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar & Name
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
              child: const Icon(Icons.person_rounded,
                  size: 48, color: AppColors.primaryGreen),
            ),
            const SizedBox(height: 14),
            Text(
              user?.fullName.isNotEmpty == true ? user!.fullName : (user?.username ?? 'User'),
              style: AppTypography.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(user?.email ?? '',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                context.push('/onboarding/profile');
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Profile'),
            ),
            const SizedBox(height: 28),

            // Stats row
            Row(
              children: [
                _StatCard(label: 'Environment', value: envScore > 0 ? '$envScore%' : '--'),
                const SizedBox(width: 10),
                _StatCard(label: 'Rooms Scanned', value: '${scansList.length}'),
                const SizedBox(width: 10),
                _StatCard(label: 'Streak', value: scansList.isNotEmpty ? '${scansList.length} d' : '0 d'),
              ],
            ),
            const SizedBox(height: 28),

            // My Goals
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Goals', style: AppTypography.titleLarge),
                  const SizedBox(height: 16),
                  _GoalProgress(label: 'Better Sleep', progress: (envScore > 0) ? (envScore / 100.0) : 0.0),
                  const SizedBox(height: 14),
                  _GoalProgress(label: 'Improve Focus', progress: (envScore > 0) ? ((envScore * 0.9) / 100.0) : 0.0),
                  const SizedBox(height: 14),
                  _GoalProgress(label: 'Reduce Overload', progress: (envScore > 0) ? ((envScore * 0.85) / 100.0) : 0.0),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Account & Security
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _SettingsItem(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notifications preference updated')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _SettingsItem(
                    icon: Icons.shield_outlined,
                    label: 'Privacy & Data',
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Sensory AI',
                        applicationVersion: '1.0.0',
                        children: const [
                          Text('Your sensory profiles and room scans are securely encrypted and saved on Neon PostgreSQL.'),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _SettingsItem(
                    icon: Icons.card_membership_outlined,
                    label: 'Subscription',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Sensory AI Plan'),
                          content: const Text('You are on the Pro Tier with unlimited multimodal room analysis & Gemini LLM coaching.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _SettingsItem(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Help & Support'),
                          content: const Text('For assistance or technical feedback, contact support@sensory.ai'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _SettingsItem(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    isDestructive: true,
                    onTap: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value,
                style: AppTypography.statNumber
                    .copyWith(color: AppColors.primaryGreen)),
            const SizedBox(height: 4),
            Text(label,
                style: AppTypography.labelSmall
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _GoalProgress extends StatelessWidget {
  final String label;
  final double progress;

  const _GoalProgress({required this.label, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTypography.bodyMedium),
            Text('${(progress * 100).round()}%',
                style: AppTypography.labelMedium
                    .copyWith(color: AppColors.primaryGreen)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.primaryGreen.withOpacity(0.12),
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.critical : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: AppTypography.bodyMedium.copyWith(color: color)),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
