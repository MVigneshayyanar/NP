import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../providers/auth_provider.dart';


/// Sensory Assessment — Step 2/3
/// 4 sensitivity sliders (0-100): Light, Sound, Texture, Colors.
class SensoryAssessmentScreen extends ConsumerStatefulWidget {
  const SensoryAssessmentScreen({super.key});

  @override
  ConsumerState<SensoryAssessmentScreen> createState() =>
      _SensoryAssessmentScreenState();
}

class _SensoryAssessmentScreenState
    extends ConsumerState<SensoryAssessmentScreen> {
  double _lightSensitivity = 50;
  double _soundSensitivity = 50;
  double _textureSensitivity = 50;
  double _colorSensitivity = 50;
  bool _isLoading = false;

  Future<void> _handleNext() async {
    setState(() => _isLoading = true);

    try {
      var user = ref.read(authProvider).user;
      if (user == null) {
        final resp = await ApiClient().getMe();
        user = User.fromJson(resp.data);
      }
      await ApiClient().updateSensoryProfile(user.id, {
        'light_sensitivity': _lightSensitivity.round(),
        'sound_sensitivity': _soundSensitivity.round(),
        'texture_sensitivity': _textureSensitivity.round(),
        'color_sensitivity': _colorSensitivity.round(),
      });
      if (mounted) context.go('/onboarding/goals');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sensory Assessment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/onboarding/profile'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('Step 2/3',
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
            Text(
              'How sensitive are you to these?',
              style: AppTypography.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Drag each slider from low (not sensitive) to high (very sensitive)',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),

            _SensitivitySlider(
              icon: Icons.light_mode_rounded,
              label: 'Light & Brightness',
              description:
                  'How much does bright or flickering light bother you?',
              value: _lightSensitivity,
              onChanged: (v) => setState(() => _lightSensitivity = v),
            ),
            const SizedBox(height: 24),

            _SensitivitySlider(
              icon: Icons.volume_up_rounded,
              label: 'Sound',
              description:
                  'How much do loud or unexpected sounds distract you?',
              value: _soundSensitivity,
              onChanged: (v) => setState(() => _soundSensitivity = v),
            ),
            const SizedBox(height: 24),

            _SensitivitySlider(
              icon: Icons.touch_app_rounded,
              label: 'Touch & Texture',
              description:
                  'How sensitive are you to fabric textures and surfaces?',
              value: _textureSensitivity,
              onChanged: (v) => setState(() => _textureSensitivity = v),
            ),
            const SizedBox(height: 24),

            _SensitivitySlider(
              icon: Icons.palette_rounded,
              label: 'Colors',
              description:
                  'How much do strong colors or contrasts affect you?',
              value: _colorSensitivity,
              onChanged: (v) => setState(() => _colorSensitivity = v),
            ),
            const SizedBox(height: 40),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleNext,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SensitivitySlider extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final double value;
  final ValueChanged<double> onChanged;

  const _SensitivitySlider({
    required this.icon,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0F1F3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large filled green icon container matching mockup 2
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.titleLarge.copyWith(fontSize: 15)),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Low',
                        style: AppTypography.labelSmall
                            .copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppColors.primaryGreen,
                          inactiveTrackColor: const Color(0xFFE5E7EB),
                          thumbColor: AppColors.primaryGreen,
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                          overlayShape: SliderComponentShape.noOverlay,
                        ),
                        child: Slider(
                          value: value,
                          min: 0,
                          max: 100,
                          divisions: 100,
                          onChanged: onChanged,
                        ),
                      ),
                    ),
                    Text('High',
                        style: AppTypography.labelSmall
                            .copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

