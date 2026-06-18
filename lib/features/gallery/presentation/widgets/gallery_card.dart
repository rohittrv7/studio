import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/gallery.dart';

/// A card widget representing a single [Gallery].
///
/// Supports both grid ([isGrid] = true) and list ([isGrid] = false) layouts.
class GalleryCard extends StatelessWidget {
  const GalleryCard({
    super.key,
    required this.gallery,
    required this.onTap,
    this.isGrid = true,
  });

  final Gallery gallery;
  final VoidCallback onTap;
  final bool isGrid;

  @override
  Widget build(BuildContext context) {
    return isGrid ? _buildGrid(context) : _buildList(context);
  }

  // ── Grid card ──────────────────────────────────────────────────────────────

  Widget _buildGrid(BuildContext context) {
    const gold = Color(0xFFE8B86D);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Cover image / placeholder ─────────────────────────────────────
            _buildCoverImage(),

            // ── Gradient overlay ──────────────────────────────────────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.45, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
            ),

            // ── Text info at bottom ───────────────────────────────────────────
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    gallery.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.photo_rounded,
                          color: Color(0xFFAAAAAA), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${gallery.mediaCount} photos',
                        style: const TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Download badge ────────────────────────────────────────────────
            if (gallery.downloadEnabled)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_rounded,
                          color: Colors.black, size: 11),
                      SizedBox(width: 3),
                      Text(
                        'DL',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── List card ──────────────────────────────────────────────────────────────

  Widget _buildList(BuildContext context) {
    const gold = Color(0xFFE8B86D);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(13)),
              child: SizedBox(
                width: 80,
                height: 80,
                child: _buildCoverImage(),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    gallery.name,
                    style: const TextStyle(
                      color: Color(0xFFF2F2F2),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.photo_rounded,
                          color: Color(0xFF666666), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${gallery.mediaCount} photos',
                        style: const TextStyle(
                            color: Color(0xFF777777), fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (gallery.downloadEnabled)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.download_rounded,
                        color: gold.withValues(alpha: 0.6), size: 16),
                  ),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF444444), size: 20),
                const SizedBox(width: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildCoverImage() {
    final url = gallery.coverThumbnailUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: const Center(
        child: Icon(
          Icons.photo_rounded,
          color: Color(0xFF333333),
          size: 28,
        ),
      ),
    );
  }
}
