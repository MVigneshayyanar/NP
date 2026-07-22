import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../providers/auth_provider.dart';

/// Profile Setup — Step 1/3
/// Name, age, country, occupation, living situation, property status.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _countryController = TextEditingController();
  final _occupationController = TextEditingController();

  String _livingSituation = 'apartment';
  String _propertyStatus = 'home_owner';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null && _nameController.text.isEmpty) {
        if (user.fullName.isNotEmpty) {
          _nameController.text = user.fullName;
        } else if (user.username.isNotEmpty) {
          _nameController.text = user.username;
        }
      }
    });
  }

  Future<void> _handleNext() async {
    final user = ref.read(authProvider).user;
    var name = _nameController.text.trim();
    if (name.isEmpty) {
      name = user?.fullName.isNotEmpty == true
          ? user!.fullName
          : (user?.username.isNotEmpty == true ? user!.username : 'Sensory User');
      _nameController.text = name;
    }

    setState(() => _isLoading = true);

    final payload = <String, dynamic>{
      'full_name': name,
      'living_situation': _livingSituation,
      'property_status': _propertyStatus,
    };

    final ageVal = int.tryParse(_ageController.text.trim());
    if (ageVal != null) payload['age'] = ageVal;
    if (_countryController.text.trim().isNotEmpty) {
      payload['country'] = _countryController.text.trim();
    }
    if (_occupationController.text.trim().isNotEmpty) {
      payload['occupation'] = _occupationController.text.trim();
    }

    // Update profile and navigate
    await ref.read(authProvider.notifier).updateProfile(payload);

    if (mounted) {
      setState(() => _isLoading = false);
      context.go('/onboarding/sensory');
    }
  }





  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _countryController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile Setup'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Step 1/3',
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.primaryGreen),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile picture (Optional) matching mockup 3
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: const Icon(Icons.camera_alt_outlined,
                        size: 32, color: AppColors.primaryGreen),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Full Name (Pill Input)
            Text('Full Name', style: AppTypography.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter your full name',
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Age (Pill Input)
            Text('Age', style: AppTypography.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter your age',
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Country (Dropdown Pill)
            Text('Country', style: AppTypography.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _countryController,
              decoration: InputDecoration(
                hintText: 'Select your country',
                suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Occupation (Dropdown Pill)
            Text('Occupation', style: AppTypography.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _occupationController,
              decoration: InputDecoration(
                hintText: 'What\'s your occupation?',
                suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Living Situation
            Text('Living Situation', style: AppTypography.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                _ToggleCard(
                  icon: Icons.apartment_rounded,
                  label: 'Appartment',
                  isSelected: _livingSituation == 'apartment' || _livingSituation == '',
                  onTap: () => setState(() => _livingSituation = 'apartment'),
                ),
                const SizedBox(width: 10),
                _ToggleCard(
                  icon: Icons.home_rounded,
                  label: 'House',
                  isSelected: _livingSituation == 'house',
                  onTap: () => setState(() => _livingSituation = 'house'),
                ),
                const SizedBox(width: 10),
                _ToggleCard(
                  icon: Icons.groups_rounded,
                  label: 'Shared Home',
                  isSelected: _livingSituation == 'shared_home',
                  onTap: () => setState(() => _livingSituation = 'shared_home'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Property Status (Radio Pill Options from mockup 3)
            Text('Property Status', style: AppTypography.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _RadioOptionCard(
                    label: 'Home Owner',
                    isSelected: _propertyStatus == 'home_owner' || _propertyStatus == '',
                    onTap: () => setState(() => _propertyStatus = 'home_owner'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RadioOptionCard(
                    label: 'Renter',
                    isSelected: _propertyStatus == 'renter',
                    onTap: () => setState(() => _propertyStatus = 'renter'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Privacy note card matching mockup 3
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF0F1F3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_outlined,
                        color: AppColors.primaryGreen, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your data is safe with us',
                          style: AppTypography.titleMedium.copyWith(fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'We use industry leading encryption to protect your Personal Information',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Next button matching mockup 3
            SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                onPressed: _isLoading ? null : _handleNext,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Continue',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primaryGreen : AppColors.inputBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Center(
                    child: Icon(icon,
                        color: isSelected
                            ? AppColors.primaryGreen
                            : AppColors.textSecondary,
                        size: 26),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 10, color: Colors.white),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioOptionCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RadioOptionCard({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.inputBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primaryGreen : AppColors.disabledText,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

