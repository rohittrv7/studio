import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_providers.dart';
import '../../../../core/storage/storage_providers.dart';
import '../../data/datasources/gallery_local_data_source.dart';
import '../../data/datasources/gallery_remote_data_source.dart';
import '../../data/repositories/gallery_repository_impl.dart';
import '../../domain/entities/folder.dart';
import '../../domain/entities/gallery.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../../domain/usecases/get_folder_tree_usecase.dart';
import '../../domain/usecases/get_galleries_usecase.dart';
import '../../domain/usecases/get_gallery_usecase.dart';

// ---------------------------------------------------------------------------
// Dependency providers
// ---------------------------------------------------------------------------

/// Provides the [GalleryRemoteDataSource] implementation.
final galleryRemoteDataSourceProvider =
    Provider<GalleryRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return GalleryRemoteDataSourceImpl(dio);
});

/// Provides the [GalleryLocalDataSource] backed by Hive.
final galleryLocalDataSourceProvider =
    Provider<GalleryLocalDataSource>((ref) {
  final storage = ref.watch(hiveStorageProvider);
  return GalleryLocalDataSource(
    galleryBox: storage.galleryBox,
    folderBox: storage.folderBox,
  );
});

/// Provides the [GalleryRepository] implementation.
final galleryRepositoryProvider = Provider<GalleryRepository>((ref) {
  return GalleryRepositoryImpl(
    remote: ref.watch(galleryRemoteDataSourceProvider),
    local: ref.watch(galleryLocalDataSourceProvider),
  );
});

/// Provides the [GetGalleriesUseCase].
final getGalleriesUseCaseProvider = Provider<GetGalleriesUseCase>((ref) {
  return GetGalleriesUseCase(ref.watch(galleryRepositoryProvider));
});

/// Provides the [GetGalleryUseCase].
final getGalleryUseCaseProvider = Provider<GetGalleryUseCase>((ref) {
  return GetGalleryUseCase(ref.watch(galleryRepositoryProvider));
});

/// Provides the [GetFolderTreeUseCase].
final getFolderTreeUseCaseProvider = Provider<GetFolderTreeUseCase>((ref) {
  return GetFolderTreeUseCase(ref.watch(galleryRepositoryProvider));
});

// ---------------------------------------------------------------------------
// Gallery list state
// ---------------------------------------------------------------------------

/// State for the gallery list screen.
class GalleryListState {
  const GalleryListState({
    this.galleries = const [],
    this.isOffline = false,
    this.hasCache = false,
  });

  final List<Gallery> galleries;
  final bool isOffline;
  final bool hasCache;

  GalleryListState copyWith({
    List<Gallery>? galleries,
    bool? isOffline,
    bool? hasCache,
  }) {
    return GalleryListState(
      galleries: galleries ?? this.galleries,
      isOffline: isOffline ?? this.isOffline,
      hasCache: hasCache ?? this.hasCache,
    );
  }
}

// ---------------------------------------------------------------------------
// GalleryListNotifier
// ---------------------------------------------------------------------------

class GalleryListNotifier extends AsyncNotifier<GalleryListState> {
  @override
  Future<GalleryListState> build() async {
    return _loadGalleries();
  }

  Future<GalleryListState> _loadGalleries() async {
    final useCase = ref.read(getGalleriesUseCaseProvider);
    final local = ref.read(galleryLocalDataSourceProvider);

    try {
      final galleries = await useCase();
      return GalleryListState(
        galleries: galleries,
        isOffline: false,
        hasCache: true,
      );
    } on GalleryException catch (_) {
      // The repository already tried the cache before throwing.
      // Check cache again here to set the correct offline/hasCache flags.
      final cached = local.getGalleries();
      final cachedEntities = cached.map((m) => m.toEntity()).toList();
      return GalleryListState(
        galleries: cachedEntities,
        isOffline: true,
        hasCache: cachedEntities.isNotEmpty,
      );
    }
  }

  /// Forces a reload of galleries from the remote source.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadGalleries);
  }

  /// Creates a new gallery and refreshes the list.
  Future<void> createGallery(String name) async {
    final repo = ref.read(galleryRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repo.createGallery(name);
      state = await AsyncValue.guard(_loadGalleries);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }
}

/// Provider for the gallery list state.
final galleryListProvider =
    AsyncNotifierProvider<GalleryListNotifier, GalleryListState>(
  GalleryListNotifier.new,
);

// ---------------------------------------------------------------------------
// Gallery detail and folder tree providers
// ---------------------------------------------------------------------------

/// Provides a single [Gallery] by id.
final galleryDetailProvider = FutureProvider.family<Gallery, String>(
  (ref, id) {
    final useCase = ref.watch(getGalleryUseCaseProvider);
    return useCase(id);
  },
);

/// Provides the folder tree for a gallery by galleryId.
final folderTreeProvider = FutureProvider.family<List<Folder>, String>(
  (ref, galleryId) {
    final useCase = ref.watch(getFolderTreeUseCaseProvider);
    return useCase(galleryId);
  },
);

/// Provides the list of customers fetched from backend.
final customersListProvider = FutureProvider.autoDispose<List<Customer>>((ref) {
  final repo = ref.watch(galleryRepositoryProvider);
  return repo.getCustomers();
});
