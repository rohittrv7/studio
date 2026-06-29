import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/qr_provider.dart';

class QrDisplayDialog extends ConsumerWidget {
  const QrDisplayDialog({
    super.key,
    required this.galleryId,
    this.folderId,
    this.mediaFileId,
    this.title = 'QR Access Code',
  });

  final String galleryId;
  final String? folderId;
  final String? mediaFileId;
  final String title;

  static Future<void> show(
    BuildContext context, {
    required String galleryId,
    String? folderId,
    String? mediaFileId,
    String title = 'QR Access Code',
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => QrDisplayDialog(
        galleryId: galleryId,
        folderId: folderId,
        mediaFileId: mediaFileId,
        title: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final param = QrGenerationParam(
      galleryId: galleryId,
      folderId: folderId,
      mediaFileId: mediaFileId,
    );
    final qrAsync = ref.watch(qrGenerationProvider(param));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE8B86D).withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE8B86D).withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFFE8B86D),
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Content
            qrAsync.when(
              data: (result) {
                Uint8List imageBytes;
                try {
                  final base64Str = result.qrImageUrl.split(',').last;
                  imageBytes = base64Decode(base64Str);
                } catch (e) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'Failed to decode QR code image',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Glassmorphic-like container for QR code
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.memory(
                        imageBytes,
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Scan this code using the in-app scanner or camera to gain instant access.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFAAAAAA),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Copy Deep Link
                    _ActionButton(
                      icon: Icons.link_rounded,
                      label: 'Copy Deep Link',
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: result.deepLink));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Deep link copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Copy Share Link (fallback)
                    _ActionButton(
                      icon: Icons.share_outlined,
                      label: 'Copy Shareable URL',
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: result.fallbackUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Shareable link copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(
                height: 280,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE8B86D)),
                  ),
                ),
              ),
              error: (error, stack) => SizedBox(
                height: 280,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to generate QR Code',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE8B86D),
                          foregroundColor: const Color(0xFF1A1100),
                        ),
                        onPressed: () => ref.invalidate(qrGenerationProvider(param)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF262626),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: const Color(0xFFE8B86D).withValues(alpha: 0.1),
        highlightColor: const Color(0xFFE8B86D).withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFE8B86D), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white30, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
