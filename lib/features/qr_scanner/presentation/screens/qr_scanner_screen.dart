import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Full-screen QR scanner that reads Studio Gallery QR codes.
///
/// Expected QR URI format: `studiogallery://gallery/{token}`
/// On a valid scan → navigates to `/gallery/{token}`.
/// On an invalid scan → shows a SnackBar error.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  late final MobileScannerController _controller;

  /// Prevents multiple simultaneous detections from being processed.
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Barcode handling
  // ---------------------------------------------------------------------------

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    _isProcessing = true;

    // Attempt to parse the scanned value as a URI.
    final uri = Uri.tryParse(raw);

    if (uri != null &&
        uri.scheme == 'studiogallery' &&
        uri.host == 'gallery') {
      // Extract token from path: /gallery/{token} → pathSegments[1]
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final token = segments.first;
        if (!mounted) return;
        context.go('/gallery/$token');
        return; // _isProcessing stays true — we navigated away.
      }
    }

    // Not a valid Studio Gallery QR code.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid QR code — not a Studio Gallery link'),
        ),
      );
    }

    // Allow re-scanning after a brief debounce.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        centerTitle: true,
        actions: [
          // Scan from Gallery
          IconButton(
            icon: const Icon(Icons.photo_library_rounded),
            tooltip: 'Scan from Gallery',
            onPressed: () async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                  allowMultiple: false,
                );
                if (result == null || result.files.isEmpty) return;
                final path = result.files.single.path;
                if (path == null) return;
                
                final capture = await _controller.analyzeImage(path);
                if (capture != null && capture.barcodes.isNotEmpty) {
                  _onDetect(capture);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No QR code found in the selected image'),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to read image: $e'),
                    ),
                  );
                }
              }
            },
          ),
          // Torch toggle
          IconButton(
            icon: const Icon(Icons.flashlight_on),
            tooltip: 'Toggle torch',
            onPressed: () => _controller.toggleTorch(),
          ),
          // Camera flip
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            tooltip: 'Flip camera',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera viewfinder
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Scanning overlay frame
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const _ScanCorners(),
            ),
          ),

          // Instruction label below the frame
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Text(
              'Align the QR code within the frame',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Decorative corner markers for the scan overlay
// ---------------------------------------------------------------------------

class _ScanCorners extends StatelessWidget {
  const _ScanCorners();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    const cornerLength = 24.0;
    const cornerThickness = 4.0;

    return Stack(
      children: [
        // Top-left
        Positioned(
          top: 0,
          left: 0,
          child: _Corner(color: color, length: cornerLength, thickness: cornerThickness),
        ),
        // Top-right
        Positioned(
          top: 0,
          right: 0,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(3.14159),
            child: _Corner(color: color, length: cornerLength, thickness: cornerThickness),
          ),
        ),
        // Bottom-left
        Positioned(
          bottom: 0,
          left: 0,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationX(3.14159),
            child: _Corner(color: color, length: cornerLength, thickness: cornerThickness),
          ),
        ),
        // Bottom-right
        Positioned(
          bottom: 0,
          right: 0,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationZ(3.14159),
            child: _Corner(color: color, length: cornerLength, thickness: cornerThickness),
          ),
        ),
      ],
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({
    required this.color,
    required this.length,
    required this.thickness,
  });

  final Color color;
  final double length;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: length,
      height: length,
      child: CustomPaint(
        painter: _CornerPainter(color: color, thickness: thickness),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({required this.color, required this.thickness});

  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.thickness != thickness;
}
