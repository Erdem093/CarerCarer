import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class LetterCameraScreen extends StatefulWidget {
  const LetterCameraScreen({super.key});

  @override
  State<LetterCameraScreen> createState() => _LetterCameraScreenState();
}

class _LetterCameraScreenState extends State<LetterCameraScreen> {
  CameraController? _controller;
  bool _isInitialised = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    _controller = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
    if (mounted) setState(() => _isInitialised = true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final xFile = await _controller!.takePicture();
      if (mounted) Navigator.pop(context, File(xFile.path));
    } catch (_) {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_isInitialised && _controller != null)
            CameraPreview(_controller!)
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Document alignment overlay
          if (_isInitialised) _DocumentOverlay(),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Line up your letter inside the box',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Capture button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Center(
                  child: GestureDetector(
                    onTap: _isCapturing ? null : _capture,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: _isCapturing ? 72 : 80,
                      height: _isCapturing ? 72 : 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isCapturing
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.white,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 4,
                        ),
                      ),
                      child: _isCapturing
                          ? const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          : null,
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

class _DocumentOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final hPad = size.width * 0.07;
    final vPad = size.height * 0.18;
    final rectW = size.width - hPad * 2;
    final rectH = size.height - vPad * 2;

    return CustomPaint(
      size: size,
      painter: _OverlayPainter(
        rect: Rect.fromLTWH(hPad, vPad, rectW, rectH),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect rect;
  _OverlayPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.52);
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    // Dim everything outside the rectangle
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(full),
        Path()..addRRect(rrect),
      ),
      dimPaint,
    );

    // White border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(rrect, borderPaint);

    // Corner accents
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const cLen = 28.0;
    const r = 16.0;

    // Top-left
    canvas.drawLine(Offset(rect.left + r, rect.top), Offset(rect.left + r + cLen, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.top + r), Offset(rect.left, rect.top + r + cLen), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(rect.right - r - cLen, rect.top), Offset(rect.right - r, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.top + r), Offset(rect.right, rect.top + r + cLen), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(rect.left + r, rect.bottom), Offset(rect.left + r + cLen, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.bottom - r - cLen), Offset(rect.left, rect.bottom - r), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(rect.right - r - cLen, rect.bottom), Offset(rect.right - r, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.bottom - r - cLen), Offset(rect.right, rect.bottom - r), cornerPaint);
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.rect != rect;
}
