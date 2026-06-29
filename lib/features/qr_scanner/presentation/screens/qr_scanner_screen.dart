import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

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

class _QrScannerScreenState extends State<QrScannerScreen> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(autoStart: false);
  bool _hasPermission = false;
  bool _isCheckingPermission = true;

  /// Prevents multiple simultaneous detections from being processed.
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  void _onPermissionGranted() {
    if (mounted) {
      setState(() {
        _hasPermission = true;
        _isCheckingPermission = false;
      });
      // Delay starting the camera slightly to ensure the widget tree is fully mounted
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _hasPermission) {
          try {
            _controller.start();
          } catch (e) {
            debugPrint('Failed to start camera after permission granted: $e');
          }
        }
      });
    }
  }

  Future<void> _checkPermission({bool isLifecycleCheck = false}) async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      _onPermissionGranted();
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        setState(() {
          _isCheckingPermission = false;
        });
        _showSettingsDialog();
      }
    } else {
      if (!isLifecycleCheck) {
        final reqStatus = await Permission.camera.request();
        if (reqStatus.isGranted) {
          _onPermissionGranted();
        } else if (reqStatus.isPermanentlyDenied) {
          if (mounted) {
            setState(() {
              _isCheckingPermission = false;
            });
            _showSettingsDialog();
          }
        } else {
          _showPermissionDeniedSnackBar();
        }
      }
    }
  }

  void _showPermissionDeniedSnackBar() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required to use the scanner.'),
        ),
      );
      context.pop(); // Close scanner screen
    }
  }

  void _showSettingsDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161616) : const Color(0xFFF7F7F7),
          title: Text(
            'Camera Permission Required',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Camera access is required to scan QR codes. Please enable it in the app settings.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(this.context).pop(); // Close scanner screen
              },
            ),
            TextButton(
              child: const Text('Open Settings', style: TextStyle(color: Color(0xFFE8B86D))),
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      _controller.stop();
    } catch (e) {
      debugPrint('Error stopping camera in dispose: $e');
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission(isLifecycleCheck: true);
      if (_hasPermission) {
        try {
          _controller.start();
        } catch (e) {
          debugPrint('Error starting camera on resume: $e');
        }
      }
    } else if (state == AppLifecycleState.inactive ||
               state == AppLifecycleState.paused ||
               state == AppLifecycleState.detached) {
      if (_hasPermission) {
        try {
          _controller.stop();
        } catch (e) {
          debugPrint('Error stopping camera on pause: $e');
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Barcode handling
  // ---------------------------------------------------------------------------

  String? _extractToken(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return null;

    // 1. If it contains URL indicators, parse as Uri
    if (clean.contains('://') || clean.startsWith('http://') || clean.startsWith('https://')) {
      final uri = Uri.tryParse(clean);
      if (uri == null) return null;

      if (uri.scheme == 'studiogallery' && uri.host == 'gallery') {
        final segments = uri.pathSegments;
        if (segments.isNotEmpty) {
          return segments.first;
        }
      }

      if (uri.scheme == 'http' || uri.scheme == 'https') {
        final segments = uri.pathSegments;
        final redirectIdx = segments.indexOf('redirect');
        if (redirectIdx != -1 && redirectIdx + 1 < segments.length) {
          return segments[redirectIdx + 1];
        }
        final galleryIdx = segments.indexOf('gallery');
        if (galleryIdx != -1 && galleryIdx + 1 < segments.length) {
          return segments[galleryIdx + 1];
        }
      }
    }

    // 2. Fall back to raw alphanumeric/base64 URL token
    if (!clean.contains('/') && !clean.contains(':') && !clean.contains('?')) {
      return clean;
    }

    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    // Vibrate to signal scan success
    HapticFeedback.vibrate();

    _isProcessing = true;

    final token = _extractToken(raw);

    if (token != null && token.isNotEmpty) {
      if (!mounted) return;
      context.go('/gallery/$token');
      return;
    }

    // Not a valid Studio Gallery QR code.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This QR is not valid'),
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
    if (_isCheckingPermission) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFE8B86D),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (!_hasPermission) {
      return const SizedBox.shrink();
    }

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
                final picker = ImagePicker();
                final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                if (image == null) return;
                final path = image.path;
                
                final capture = await _controller.analyzeImage(path);
                if (capture != null && capture.barcodes.isNotEmpty) {
                  _onDetect(capture);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('This QR is not valid'),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('This QR is not valid'),
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
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Container(
                color: const Color(0xFF0D0D0D),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFE8B86D),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Camera Initialization Failed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please ensure the camera is not in use by another app or try restarting the scanner.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Error Details: ${error.errorCode.name}\n${error.errorDetails ?? "No additional hardware details."}',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE8B86D),
                            foregroundColor: const Color(0xFF1A1100),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            try {
                              await _controller.start();
                            } catch (e) {
                              debugPrint('Failed to start camera on retry: $e');
                            }
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
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
              child: const Stack(
                children: [
                  _ScanCorners(),
                  _LaserLine(width: 260),
                ],
              ),
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

// ---------------------------------------------------------------------------
// Sliding laser scanner line animation
// ---------------------------------------------------------------------------

class _LaserLine extends StatefulWidget {
  const _LaserLine({required this.width});
  final double width;

  @override
  State<_LaserLine> createState() => _LaserLineState();
}

class _LaserLineState extends State<_LaserLine> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 10, end: 240).animate(CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Positioned(
          top: _anim.value,
          left: 10,
          right: 10,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(1.5),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.8),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
