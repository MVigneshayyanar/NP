import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../providers/auth_provider.dart';


/// Goals — Step 3/3
/// Multi-select goal chips, daily routine time picker, sleep schedule, notification toggle.
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  final Set<String> _selectedGoals = {};
  TimeOfDay _routineStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _routineEnd = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _bedtime = const TimeOfDay(hour: 23, minute: 0);
  double _sleepDuration = 8.0;
  bool _notificationsEnabled = true;
  bool _isLoading = false;

  static const _goals = [
    {'id': 'better_sleep', 'label': 'Better Sleep', 'icon': Icons.bedtime_rounded},
    {'id': 'improve_focus', 'label': 'Improve Focus', 'icon': Icons.center_focus_strong_rounded},
    {'id': 'reduce_anxiety', 'label': 'Reduce Anxiety', 'icon': Icons.spa_rounded},
    {'id': 'boost_mood', 'label': 'Boost Mood', 'icon': Icons.mood_rounded},
    {'id': 'increase_productivity', 'label': 'Increase Productivity', 'icon': Icons.trending_up_rounded},
    {'id': 'manage_sensory', 'label': 'Manage Sensory Overload', 'icon': Icons.shield_rounded},
    {'id': 'create_calm', 'label': 'Create Calm Space', 'icon': Icons.self_improvement_rounded},
    {'id': 'better_energy', 'label': 'Better Energy', 'icon': Icons.bolt_rounded},
  ];

  Future<void> _handleComplete() async {
    if (_selectedGoals.isEmpty) {
      _selectedGoals.add('better_sleep');
    }

    setState(() => _isLoading = true);


    try {
      var user = ref.read(authProvider).user;
      if (user == null) {
        final meResp = await ApiClient().getMe();
        user = User.fromJson(meResp.data);
      }
      // Update sensory profile with goals and schedule
      await ApiClient().updateSensoryProfile(user.id, {
        'goals': _selectedGoals.toList(),
        'daily_routine_start':
            '${_routineStart.hour.toString().padLeft(2, '0')}:${_routineStart.minute.toString().padLeft(2, '0')}:00',
        'daily_routine_end':
            '${_routineEnd.hour.toString().padLeft(2, '0')}:${_routineEnd.minute.toString().padLeft(2, '0')}:00',
        'bedtime':
            '${_bedtime.hour.toString().padLeft(2, '0')}:${_bedtime.minute.toString().padLeft(2, '0')}:00',
        'sleep_duration_hours': _sleepDuration,
      });

      // Mark onboarding as complete
      await ref.read(authProvider.notifier).updateProfile({
        'onboarding_completed': true,
        'notifications_enabled': _notificationsEnabled,
      });

      if (mounted) context.go('/home');
    } catch (e) {

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _pickTime(String type) async {
    TimeOfDay initial;
    switch (type) {
      case 'start':
        initial = _routineStart;
        break;
      case 'end':
        initial = _routineEnd;
        break;
      case 'bedtime':
        initial = _bedtime;
        break;
      default:
        return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme:
                Theme.of(context).colorScheme.copyWith(primary: AppColors.primaryGreen),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        switch (type) {
          case 'start':
            _routineStart = picked;
            break;
          case 'end':
            _routineEnd = picked;
            break;
          case 'bedtime':
            _bedtime = picked;
            break;
        }
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final m = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your Goals'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/onboarding/sensory'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('Step 3/3',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.primaryGreen)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('What would you like to improve?',
                style: AppTypography.headlineMedium),
            const SizedBox(height: 8),
            Text('Select all that apply',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 20),

            // Goal chips
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _goals.map((goal) {
                final isSelected =
                    _selectedGoals.contains(goal['id'] as String);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedGoals.remove(goal['id'] as String);
                      } else {
                        _selectedGoals.add(goal['id'] as String);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryGreen.withOpacity(0.12)
                          : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryGreen
                            : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          goal['icon'] as IconData,
                          size: 18,
                          color: isSelected
                              ? AppColors.primaryGreen
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          goal['label'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? AppColors.primaryGreen
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Daily Routine
            Text('Daily Routine', style: AppTypography.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimePickerCard(
                    label: 'Start',
                    time: _formatTime(_routineStart),
                    onTap: () => _pickTime('start'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimePickerCard(
                    label: 'End',
                    time: _formatTime(_routineEnd),
                    onTap: () => _pickTime('end'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Sleep Schedule
            Text('Sleep Schedule', style: AppTypography.titleMedium),
            const SizedBox(height: 12),
            _TimePickerCard(
              label: 'Bedtime',
              time: _formatTime(_bedtime),
              onTap: () => _pickTime('bedtime'),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Sleep Duration', style: AppTypography.bodyMedium),
                      Text('${_sleepDuration.toStringAsFixed(1)} hours',
                          style: AppTypography.titleMedium
                              .copyWith(color: AppColors.primaryGreen)),
                    ],
                  ),
                  Slider(
                    value: _sleepDuration,
                    min: 4,
                    max: 12,
                    divisions: 16,
                    onChanged: (v) => setState(() => _sleepDuration = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Notifications toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_outlined,
                      color: AppColors.primaryGreen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Enable Notifications',
                            style: AppTypography.bodyMedium),
                        Text('Get reminders and insights',
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _notificationsEnabled,
                    activeColor: AppColors.primaryGreen,
                    onChanged: (v) =>
                        setState(() => _notificationsEnabled = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Complete Setup
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleComplete,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Complete Setup'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TimePickerCard extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimePickerCard({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, color: AppColors.primaryGreen, size: 20),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.textSecondary)),
                Text(time, style: AppTypography.titleMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
