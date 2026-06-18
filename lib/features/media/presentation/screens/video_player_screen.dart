import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../gallery/presentation/providers/gallery_provider.dart';
import '../../../qr_scanner/presentation/widgets/qr_display_dialog.dart';
import '../../domain/entities/media_file.dart';
import '../../../../core/utils/security_util.dart';

/// Full-featured video player screen using Chewie + video_player.
class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key, required this.mediaFile});

  final MediaFile mediaFile;

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late final VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Secure by default when entering the video player
    SecurityUtil.setSecure(true);
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(widget.mediaFile.secureUrl),
    );

    try {
      await _videoPlayerController.initialize();

      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        showControlsOnInitialize: true,
      );

      // Listen for state changes (playback complete, errors, etc.)
      _videoPlayerController.addListener(_onVideoPlayerUpdate);

      setState(() {
        _initialized = true;
      });
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  void _onVideoPlayerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _replayVideo() async {
    await _videoPlayerController.seekTo(Duration.zero);
    await _videoPlayerController.play();
  }

  bool get _isPlaybackComplete {
    final value = _videoPlayerController.value;
    if (!value.isInitialized) return false;
    final duration = value.duration;
    final position = value.position;
    return duration > Duration.zero && position >= duration;
  }

  @override
  void dispose() {
    // Clear secure flag when leaving the screen
    SecurityUtil.setSecure(false);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _videoPlayerController.removeListener(_onVideoPlayerUpdate);
    _chewieController?.dispose();
    _videoPlayerController.dispose();
    super.dispose();
  }

  Widget _buildPosterFrame() {
    return CachedNetworkImage(
      imageUrl: widget.mediaFile.thumbnailUrl,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final isStudioOwner = user?.isStudioOwner ?? false;

    final galleryAsync = ref.watch(galleryDetailProvider(widget.mediaFile.galleryId));
    final hasFullAccess = galleryAsync.maybeWhen(
      data: (g) => isStudioOwner || (g.customerId == user?.id),
      orElse: () => false,
    );

    // Apply or clear window flags dynamically based on access permissions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasFullAccess) {
        SecurityUtil.setSecure(false);
      } else {
        SecurityUtil.setSecure(true);
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Video'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/galleries/${widget.mediaFile.galleryId}');
            }
          },
        ),
        actions: [
          if (isStudioOwner)
            IconButton(
              icon: const Icon(Icons.qr_code_rounded, color: Color(0xFFE8B86D)),
              tooltip: 'Get Video QR Code',
              onPressed: () {
                QrDisplayDialog.show(
                  context,
                  galleryId: widget.mediaFile.galleryId,
                  mediaFileId: widget.mediaFile.id,
                  title: 'Video QR Code',
                );
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Error state
    if (_videoPlayerController.value.hasError) {
      return const Center(
        child: Text(
          'Failed to load video. Please try again.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    // Buffering / not yet initialized
    if (!_initialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _buildPosterFrame(),
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ],
      );
    }

    // Playback complete — show replay overlay
    if (_isPlaybackComplete) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _buildPosterFrame(),
          Center(
            child: IconButton(
              icon: const Icon(
                Icons.replay,
                size: 64,
                color: Colors.white,
              ),
              onPressed: _replayVideo,
            ),
          ),
        ],
      );
    }

    // Normal playback via Chewie
    return Chewie(controller: _chewieController!);
  }
}
