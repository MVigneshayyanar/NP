import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/api_client.dart';

class ScanRoomScreen extends ConsumerStatefulWidget {
  const ScanRoomScreen({super.key});

  @override
  ConsumerState<ScanRoomScreen> createState() => _ScanRoomScreenState();
}

class _ScanRoomScreenState extends ConsumerState<ScanRoomScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  bool _photoTaken = false;
  bool _recordingAudio = false;
  bool _isAnalyzing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        // Find the back camera
        final backCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );

        _controller = CameraController(
          backCamera,
          ResolutionPreset.medium,
          enableAudio: true,
        );

        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      } else {
        setState(() {
          _errorMessage = "No cameras found on this device.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to initialize camera: $e";
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile photo = await _controller!.takePicture();
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _photoTaken = true;
          _recordingAudio = true;
        });

        // Simulate recording ambient audio alongside camera capture
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _recordingAudio) {
            setState(() {
              _recordingAudio = false;
              _isAnalyzing = true;
            });
            _analyze(photo.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _errorMessage = "Failed to capture photo: $e";
        });
      }
    }
  }

  Future<void> _analyze(String imagePath) async {
    try {
      final user = ref.read(authProvider).user;
      if (user != null) {
        // Send image to backend for analysis via API Client
        await ApiClient().analyzeEnvironment(
          imagePath: imagePath,
          roomName: 'Bedroom',
        );

        // Invalidate providers to fetch fresh data
        ref.invalidate(userScansProvider);
        ref.invalidate(userProgressProvider);
        ref.invalidate(recommendationsProvider);

        if (mounted) {
          setState(() => _isAnalyzing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Room analysis completed successfully!')),
          );
          context.go('/home');
        }
      }
    } catch (e) {
      debugPrint("Analysis error: $e");
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: ${e is DioException && e.response != null ? "Server returned error (${e.response?.statusCode}). Please try again." : (e.toString().contains("timeout") ? "Request timed out. Please try again." : "Could not reach server.")}'),
            backgroundColor: AppColors.critical,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview or placeholder
          Positioned.fill(
            child: _isCameraInitialized && _controller != null
                ? AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: CameraPreview(_controller!),
                  )
                : Container(
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
                            _errorMessage ?? 'Initializing Camera...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
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
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // Audio recording indicator overlay
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
