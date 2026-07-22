import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/api_client.dart';

/// Scan Room screen — full-screen camera view with viewfinder overlay.
class ScanRoomScreen extends ConsumerStatefulWidget {
  const ScanRoomScreen({super.key});

  @override
  ConsumerState<ScanRoomScreen> createState() => _ScanRoomScreenState();
}

class _ScanRoomScreenState extends ConsumerState<ScanRoomScreen> {
  bool _isCapturing = false;
  bool _photoTaken = false;
  bool _recordingAudio = false;
  bool _isAnalyzing = false;

  void _capturePhoto() {
    setState(() {
      _isCapturing = true;
    });

    // Simulate camera capture
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _photoTaken = true;
          _recordingAudio = true;
        });

        // Auto-stop audio after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _recordingAudio) {
            setState(() {
              _recordingAudio = false;
              _isAnalyzing = true;
            });
            _analyze();
          }
        });
      }
    });
  }

  Future<void> _analyze() async {
    try {
      final user = ref.read(authProvider).user;
      if (user != null) {
        // Create scan in Django backend
        await ApiClient().dio.post('/scans/', data: {
          'user': user.id,
          'room_name': 'Bedroom',
          'environment_score': 88,
          'focus_score': 85,
          'sleep_score': 90,
          'mood_score': 84,
          'image_ref': 'assets/mock/bedroom_scan.jpg',
          'llm_output': {
            'analysis': 'Optimal warm lighting detected. Noise levels under 35dB.',
          },
        });
        // Invalidate providers to refetch fresh data
        ref.invalidate(userScansProvider);
        ref.invalidate(userProgressProvider);
        ref.invalidate(recommendationsProvider);
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isAnalyzing = false);
      context.go('/home');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview placeholder (full screen dark)
          Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF1A1A2E),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.camera_alt_rounded,
                    size: 64,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Camera Preview',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Corner bracket viewfinder overlay
          Positioned.fill(
            child: CustomPaint(
              painter: _ViewfinderPainter(),
            ),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _photoTaken
                            ? (_recordingAudio
                                ? '🎤 Recording audio...'
                                : (_isAnalyzing
                                    ? '🧠 Analyzing...'
                                    : '✅ Done'))
                            : 'Frame your room',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // Audio recording indicator
          if (_recordingAudio)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Recording ambient audio...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Analyzing overlay
          if (_isAnalyzing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                        strokeWidth: 4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Analyzing your space...',
                      style: AppTypography.headlineSmall
                          .copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Evaluating lighting, noise, textures & colors',
                      style: AppTypography.bodyMedium
                          .copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom capture button
          if (!_photoTaken)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Center(
                    child: GestureDetector(
                      onTap: _isCapturing ? null : _capturePhoto,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _isCapturing ? 64 : 76,
                        height: _isCapturing ? 64 : 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 4),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isCapturing
                                ? AppColors.critical
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom painter for the corner-bracket viewfinder overlay.
class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryGreen
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const margin = 40.0;
    const bracketLen = 30.0;
    const radius = 12.0;

    final left = margin;
    final top = size.height * 0.2;
    final right = size.width - margin;
    final bottom = size.height * 0.75;

    // Top-left corner
    canvas.drawLine(Offset(left, top + bracketLen), Offset(left, top + radius), paint);
    canvas.drawArc(
        Rect.fromLTWH(left, top, radius * 2, radius * 2), 3.14, 1.57, false, paint);
    canvas.drawLine(Offset(left + radius, top), Offset(left + bracketLen, top), paint);

    // Top-right corner
    canvas.drawLine(Offset(right, top + bracketLen), Offset(right, top + radius), paint);
    canvas.drawArc(Rect.fromLTWH(right - radius * 2, top, radius * 2, radius * 2),
        0, -1.57, false, paint);
    canvas.drawLine(Offset(right - radius, top), Offset(right - bracketLen, top), paint);

    // Bottom-left corner
    canvas.drawLine(
        Offset(left, bottom - bracketLen), Offset(left, bottom - radius), paint);
    canvas.drawArc(Rect.fromLTWH(left, bottom - radius * 2, radius * 2, radius * 2),
        3.14, -1.57, false, paint);
    canvas.drawLine(
        Offset(left + radius, bottom), Offset(left + bracketLen, bottom), paint);

    // Bottom-right corner
    canvas.drawLine(
        Offset(right, bottom - bracketLen), Offset(right, bottom - radius), paint);
    canvas.drawArc(
        Rect.fromLTWH(
            right - radius * 2, bottom - radius * 2, radius * 2, radius * 2),
        0,
        1.57,
        false,
        paint);
    canvas.drawLine(
        Offset(right - radius, bottom), Offset(right - bracketLen, bottom), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
