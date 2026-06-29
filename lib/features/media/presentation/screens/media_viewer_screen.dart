import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/media_file.dart';
import '../providers/media_provider.dart';
import 'photo_viewer_screen.dart';
import 'video_player_screen.dart';

/// Full-screen media viewer that loads details for the scanned media ID
/// and redirects to either PhotoViewerScreen or VideoPlayerScreen.
class MediaViewerScreen extends ConsumerWidget {
  const MediaViewerScreen({
    super.key,
    required this.galleryId,
    required this.mediaId,
  });

  final String galleryId;
  final String mediaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(mediaFileProvider((galleryId, mediaId)));

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/galleries/$galleryId');
      },
      child: mediaAsync.when(
        loading: () => const Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
        error: (error, _) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Error loading media: $error',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        data: (mediaFile) {
          if (mediaFile.mediaType == MediaType.photo) {
            return PhotoViewerScreen(
              galleryId: galleryId,
              mediaIds: [mediaId],
              initialIndex: 0,
            );
          } else {
            return VideoPlayerScreen(mediaFile: mediaFile);
          }
        },
      ),
    );
  }
}
