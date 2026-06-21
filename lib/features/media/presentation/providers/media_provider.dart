import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_providers.dart';
import '../../data/datasources/media_remote_data_source.dart';
import '../../data/repositories/media_repository_impl.dart';
import '../../domain/entities/media_file.dart';
import '../../domain/repositories/media_repository.dart';
import '../../domain/usecases/download_media_usecase.dart';
import '../../domain/usecases/get_media_usecase.dart';

// ---------------------------------------------------------------------------
// Parameters class
// ---------------------------------------------------------------------------

/// Parameters used to identify a media list query (gallery + page + folder).
///
/// Implements value equality manually — no equatable dependency required.
class MediaListParams {
  const MediaListParams({
    required this.galleryId,
    this.page = 1,
    this.folderId,
  });

  final String galleryId;
  final int page;
  final String? folderId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaListParams &&
          runtimeType == other.runtimeType &&
          galleryId == other.galleryId &&
          page == other.page &&
          folderId == other.folderId;

  @override
  int get hashCode => Object.hash(galleryId, page, folderId);
}

// ---------------------------------------------------------------------------
// Dependency providers
// ---------------------------------------------------------------------------

/// Provides the [MediaRemoteDataSource] implementation.
final mediaRemoteDataSourceProvider = Provider<MediaRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return MediaRemoteDataSourceImpl(dio);
});

/// Provides the [MediaRepository] implementation.
final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepositoryImpl(
    remote: ref.watch(mediaRemoteDataSourceProvider),
  );
});

/// Provides the [GetMediaUseCase].
final getMediaUseCaseProvider = Provider<GetMediaUseCase>((ref) {
  return GetMediaUseCase(ref.watch(mediaRepositoryProvider));
});

/// Provides the [DownloadMediaUseCase].
final downloadMediaUseCaseProvider = Provider<DownloadMediaUseCase>((ref) {
  return DownloadMediaUseCase(ref.watch(mediaRepositoryProvider));
});

// ---------------------------------------------------------------------------
// FutureProvider families
// ---------------------------------------------------------------------------

/// Provides a paginated list of [MediaFile]s for the given [MediaListParams].
final mediaListProvider =
    FutureProvider.family<List<MediaFile>, MediaListParams>(
  (ref, params) async {
    final useCase = ref.watch(getMediaUseCaseProvider);
    return useCase(
      GetMediaParams(
        galleryId: params.galleryId,
        page: params.page,
        folderId: params.folderId,
      ),
    );
  },
);

/// Provides a single [MediaFile] by `(galleryId, mediaId)`.
final mediaFileProvider =
    FutureProvider.family<MediaFile, (String, String)>((ref, args) async {
  final (galleryId, mediaId) = args;
  final repo = ref.watch(mediaRepositoryProvider);
  return repo.getMediaFile(galleryId, mediaId);
});

// ---------------------------------------------------------------------------
// Download state
// ---------------------------------------------------------------------------

/// Progress state for a single media file download.
class DownloadState {
  const DownloadState({
    this.progress = 0.0,
    this.isDownloading = false,
    this.error,
    this.completed = false,
    this.savePath,
  });

  final double progress; // 0.0 – 1.0
  final bool isDownloading;
  final String? error;
  final bool completed;
  final String? savePath;

  DownloadState copyWith({
    double? progress,
    bool? isDownloading,
    String? error,
    bool? completed,
    String? savePath,
  }) {
    return DownloadState(
      progress: progress ?? this.progress,
      isDownloading: isDownloading ?? this.isDownloading,
      error: error ?? this.error,
      completed: completed ?? this.completed,
      savePath: savePath ?? this.savePath,
    );
  }
}

/// Manages download state for multiple media files simultaneously.
///
/// State is a map of `mediaId → DownloadState`.  Completed entries are
/// removed automatically after 3 seconds.
class DownloadNotifier extends StateNotifier<Map<String, DownloadState>> {
  DownloadNotifier(this._downloadUseCase, this._dio) : super({});

  final DownloadMediaUseCase _downloadUseCase;
  final Dio _dio;

  Future<void> startDownload({
    required String galleryId,
    required String mediaId,
    required String fileName,
  }) async {
    // Mark as downloading
    state = {
      ...state,
      mediaId: const DownloadState(isDownloading: true, progress: 0.0),
    };

    try {
      String? resolvedPath;
      try {
        if (Platform.isAndroid) {
          final publicDownloadDir = Directory('/storage/emulated/0/Download');
          if (await publicDownloadDir.exists()) {
            resolvedPath = '${publicDownloadDir.path}/$fileName';
          } else {
            final extDir = await getExternalStorageDirectory();
            resolvedPath = '${(extDir ?? await getApplicationDocumentsDirectory()).path}/$fileName';
          }
        } else {
          final docDir = await getApplicationDocumentsDirectory();
          resolvedPath = '${docDir.path}/$fileName';
        }
      } catch (_) {
        final extDir = await getExternalStorageDirectory();
        resolvedPath = '${(extDir ?? await getApplicationDocumentsDirectory()).path}/$fileName';
      }

      try {
        await _downloadUseCase(
          galleryId: galleryId,
          mediaId: mediaId,
          savePath: resolvedPath!,
          onReceiveProgress: (received, total) {
            if (total > 0 && mounted) {
              state = {
                ...state,
                mediaId: DownloadState(
                  isDownloading: true,
                  progress: received / total,
                ),
              };
            }
          },
        );
      } catch (e) {
        if (Platform.isAndroid && resolvedPath!.startsWith('/storage/emulated/0/Download')) {
          try {
            final extDir = await getExternalStorageDirectory();
            resolvedPath = '${(extDir ?? await getApplicationDocumentsDirectory()).path}/$fileName';
            await _downloadUseCase(
              galleryId: galleryId,
              mediaId: mediaId,
              savePath: resolvedPath,
              onReceiveProgress: (received, total) {
                if (total > 0 && mounted) {
                  state = {
                    ...state,
                    mediaId: DownloadState(
                      isDownloading: true,
                      progress: received / total,
                    ),
                  };
                }
              },
            );
          } catch (err) {
            state = {
              ...state,
              mediaId: DownloadState(
                isDownloading: false,
                error: err.toString(),
              ),
            };
            return;
          }
        } else {
          state = {
            ...state,
            mediaId: DownloadState(
              isDownloading: false,
              error: e.toString(),
            ),
          };
          return;
        }
      }

      // Mark completed
      state = {
        ...state,
        mediaId: DownloadState(
          isDownloading: false,
          completed: true,
          savePath: resolvedPath,
        ),
      };

      // Fire-and-forget analytics: record the download as a view event.
      // Errors are intentionally swallowed — analytics must not block the UX.
      _recordDownloadAnalytics(galleryId);

      // Clear entry after 3 seconds
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        final updated = Map<String, DownloadState>.from(state);
        updated.remove(mediaId);
        state = updated;
      }
    } catch (e) {
      state = {
        ...state,
        mediaId: DownloadState(
          isDownloading: false,
          error: e.toString(),
        ),
      };
    }
  }

  /// Fire-and-forget POST to [ApiConstants.analyticsView] to signal a download
  /// event.  The backend records the gallery view; download counts are tracked
  /// server-side per Requirement 13.5.
  void _recordDownloadAnalytics(String galleryId) {
    _dio
        .post<void>(
          ApiConstants.analyticsView,
          data: {'galleryId': galleryId},
        )
        .ignore(); // intentionally fire-and-forget
  }
}

/// Provider that exposes [DownloadNotifier] to the widget tree.
final downloadNotifierProvider =
    StateNotifierProvider<DownloadNotifier, Map<String, DownloadState>>(
  (ref) => DownloadNotifier(
    ref.watch(downloadMediaUseCaseProvider),
    ref.watch(dioProvider),
  ),
);
