import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../providers/gallery_provider.dart';
import '../widgets/gallery_card.dart';
import '../widgets/home_view.dart';
import '../widgets/profile_view.dart';
import '../../../../core/widgets/error_display.dart';
import '../../../studios/presentation/screens/studios_tab.dart';
import '../../../bookings/presentation/screens/bookings_screen.dart';
import '../../../bookings/data/repositories/bookings_repository.dart';

/// Gallery list screen — the main landing screen after login.
class GalleriesScreen extends ConsumerStatefulWidget {
  final int? initialTab;
  const GalleriesScreen({super.key, this.initialTab});

  @override
  ConsumerState<GalleriesScreen> createState() => _GalleriesScreenState();
}

class _GalleriesScreenState extends ConsumerState<GalleriesScreen> {
  // Toggle between grid and list view.
  bool _isGrid = true;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab ?? 0;
  }

  Widget _buildErrorWidget(Object error) {
    return ErrorDisplay(
      title: 'Failed to Load Galleries',
      message: 'Something went wrong: ${error.toString()}',
      onRetry: () => ref.read(galleryListProvider.notifier).refresh(),
      retryLabel: 'Retry',
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ConnectivityState>(connectivityStatusProvider, (prev, next) {
      if (next.justReconnected) {
        ref.read(galleryListProvider.notifier).refresh();
        ref.read(connectivityStatusProvider.notifier).acknowledgeReconnect();
      }
    });

    final authState = ref.watch(authNotifierProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final isStudio = user?.isStudioOwner ?? false;
    const gold = Color(0xFFE8B86D);

    final List<Widget> tabs;
    if (isStudio) {
      tabs = [
        HomeView(
          onCreateGallery: () => _showCreateGalleryDialog(),
          onCreateFolder: () => _showCreateFolderFromOutsideDialog(),
          onUploadMedia: () => _showUploadMediaFromOutsideDialog(),
          onShowGalleries: () {
            setState(() => _currentIndex = 1);
          },
        ),
        Consumer(
          builder: (context, ref, child) {
            final asyncState = ref.watch(galleryListProvider);
            return asyncState.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: gold, strokeWidth: 2),
              ),
              error: (error, _) => _buildErrorWidget(error),
              data: (state) => _buildBody(state),
            );
          },
        ),
        const BookingsScreen(),
        ProfileView(
          onEditProfile: () => _showEditProfileDialog(context, user!),
        ),
      ];
    } else {
      tabs = [
        HomeView(
          onCreateGallery: () => _showCreateGalleryDialog(),
          onCreateFolder: () => _showCreateFolderFromOutsideDialog(),
          onUploadMedia: () => _showUploadMediaFromOutsideDialog(),
          onShowGalleries: () {
            setState(() => _currentIndex = 3);
          },
        ),
        const StudiosTab(),
        const BookingsScreen(),
        Consumer(
          builder: (context, ref, child) {
            final asyncState = ref.watch(galleryListProvider);
            return asyncState.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: gold, strokeWidth: 2),
              ),
              error: (error, _) => _buildErrorWidget(error),
              data: (state) => _buildBody(state),
            );
          },
        ),
        ProfileView(
          onEditProfile: () => _showEditProfileDialog(context, user!),
        ),
      ];
    }
    final List<BottomNavigationBarItem> navItems = [];
    final List<String> titles = [];

    // 1. Home Tab (Both Roles)
    navItems.add(const BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ));
    titles.add('Studio Gallery');

    if (isStudio) {
      // Studio Owner View List
      // Index 1: Galleries list
      navItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.photo_library_outlined),
        activeIcon: Icon(Icons.photo_library_rounded),
        label: 'Gallery',
      ));
      titles.add('My Galleries');

      // Index 2: Bookings received
      navItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.event_note_outlined),
        activeIcon: Icon(Icons.event_note_rounded),
        label: 'Bookings',
      ));
      titles.add('Booking Requests');

      // Index 3: Profile
      navItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ));
      titles.add('My Profile');
    } else {
      // Customer View List
      // Index 1: Explore Studios tab
      navItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.storefront_outlined),
        activeIcon: Icon(Icons.storefront_rounded),
        label: 'Studios',
      ));
      titles.add('Explore Studios');

      // Index 2: Bookings placed
      navItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.event_note_outlined),
        activeIcon: Icon(Icons.event_note_rounded),
        label: 'Bookings',
      ));
      titles.add('My Bookings');

      // Index 3: Galleries assigned to them
      navItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.photo_library_outlined),
        activeIcon: Icon(Icons.photo_library_rounded),
        label: 'Gallery',
      ));
      titles.add('My Galleries');

      // Index 4: Profile
      navItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ));
      titles.add('My Profile');
    }

    if (_currentIndex >= tabs.length) {
      _currentIndex = 0;
    }

    final title = titles[_currentIndex];
    final showGridListToggle = (isStudio && _currentIndex == 1) || (!isStudio && _currentIndex == 3);
    final showRefreshButton = (_currentIndex == 2);

    return BackButtonListener(
      onBackButtonPressed: () async {
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return true; // handled
        }
        return false; // let system pop/exit
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // ── Custom AppBar ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                  child: Row(
                    children: [
                      // Brand icon
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: gold.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: gold, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      // Toggle grid/list
                      if (showGridListToggle)
                        IconButton(
                          icon: Icon(
                            _isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded,
                            color: const Color(0xFF888888),
                            size: 22,
                          ),
                          tooltip: _isGrid ? 'List view' : 'Grid view',
                          onPressed: () => setState(() => _isGrid = !_isGrid),
                        ),
                      // Add Direct Booking (Studio Owner only)
                      if (isStudio && _currentIndex == 2)
                        IconButton(
                          icon: const Icon(Icons.add_rounded, color: gold, size: 24),
                          tooltip: 'Add Booking',
                          onPressed: () => _showAddBookingDialog(),
                        ),
                      // Refresh button (Bookings)
                      if (showRefreshButton)
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF888888), size: 22),
                          tooltip: 'Refresh bookings',
                          onPressed: () => ref.read(bookingsListProvider.notifier).loadBookings(),
                        ),
                      // QR scanner
                      IconButton(
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Color(0xFF888888),
                          size: 22,
                        ),
                        tooltip: 'Scan QR code',
                        onPressed: () => context.push('/qr'),
                      ),
                    ],
                  ),
                ),

                // ── Offline banner ──────────────────────────────────────────────
                const OfflineBanner(),

                // ── Body ────────────────────────────────────────────────────────
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: tabs,
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: user != null && user.isStudioOwner && (isStudio && _currentIndex == 1)
              ? FloatingActionButton(
                  backgroundColor: gold,
                  foregroundColor: Colors.black,
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF161616)
                          : const Color(0xFFF7F7F7),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) {
                        return SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.collections_outlined, color: gold),
                                title: Text(
                                  'Create Gallery',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _showCreateGalleryDialog();
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.create_new_folder_outlined, color: gold),
                                title: Text(
                                  'Create Folder in Gallery',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _showCreateFolderFromOutsideDialog();
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.upload_file_outlined, color: gold),
                                title: Text(
                                  'Upload to Gallery',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _showUploadMediaFromOutsideDialog();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: const Icon(Icons.add_rounded),
                )
              : null,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF161616)
                : const Color(0xFFF7F7F7),
            selectedItemColor: gold,
            unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            onTap: (index) {
              if (_currentIndex != index) {
                setState(() {
                  _currentIndex = index;
                });
              }
            },
            items: navItems,
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateFolderFromOutsideDialog() async {
    final galleries = ref.read(galleryListProvider).value?.galleries ?? [];
    final messenger = ScaffoldMessenger.of(context);
    if (galleries.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please create a gallery first.')),
      );
      return;
    }

    String selectedGalleryId = galleries.first.id;
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF161616) : const Color(0xFFF7F7F7),
              title: Text('Create Folder', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Gallery:', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                  DropdownButton<String>(
                    value: selectedGalleryId,
                    dropdownColor: isDark ? const Color(0xFF161616) : const Color(0xFFF7F7F7),
                    isExpanded: true,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    items: galleries.map((g) {
                      return DropdownMenuItem<String>(
                        value: g.id,
                        child: Text(g.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => selectedGalleryId = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Folder Name',
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                    autofocus: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isEmpty) return;
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    try {
                      await ref.read(galleryRepositoryProvider).createFolder(
                        selectedGalleryId,
                        name: name,
                      );
                      ref.invalidate(folderTreeProvider(selectedGalleryId));
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Folder created successfully!')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Failed to create folder: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Create', style: TextStyle(color: Color(0xFFE8B86D))),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showUploadMediaFromOutsideDialog() async {
    final galleries = ref.read(galleryListProvider).value?.galleries ?? [];
    final messenger = ScaffoldMessenger.of(context);
    if (galleries.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please create a gallery first.')),
      );
      return;
    }

    String selectedGalleryId = galleries.first.id;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'avi'],
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;
      final totalFiles = result.files.length;
      final validFiles = result.files.where((f) => f.path != null).toList();
      if (validFiles.isEmpty) return;

      if (!mounted) return;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return AlertDialog(
                backgroundColor: isDark ? const Color(0xFF161616) : const Color(0xFFF7F7F7),
                title: Text('Select Gallery to Upload', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Uploading $totalFiles selected files.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 16),
                    Text('Select Target Gallery:', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                    DropdownButton<String>(
                      value: selectedGalleryId,
                      dropdownColor: isDark ? const Color(0xFF161616) : const Color(0xFFF7F7F7),
                      isExpanded: true,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      items: galleries.map((g) {
                        return DropdownMenuItem<String>(
                          value: g.id,
                          child: Text(g.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => selectedGalleryId = val);
                        }
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  TextButton(
                    onPressed: () async {
                      final selectNavigator = Navigator.of(context);
                      selectNavigator.pop(); // close select dialog
                      
                      int completedCount = 0;
                      double currentFileProgress = 0.0;
                      String statusText = 'Starting upload...';
                      void Function(void Function())? dialogStateSetter;

                      if (!mounted) return;

                      final uploadNavigator = Navigator.of(context);

                      showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (dialogCtx) {
                          return StatefulBuilder(
                            builder: (statefulCtx, setDialogState) {
                              dialogStateSetter = setDialogState;
                              final double overallProgress = totalFiles > 0
                                  ? (completedCount + currentFileProgress) / totalFiles
                                  : 0.0;
                              final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
                              return AlertDialog(
                                backgroundColor: isDark ? const Color(0xFF161616) : const Color(0xFFF7F7F7),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.cloud_upload_outlined, color: Color(0xFFE8B86D), size: 40),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Uploading Media (${completedCount + 1}/$totalFiles)',
                                      style: TextStyle(
                                        color: Theme.of(dialogCtx).colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    LinearProgressIndicator(
                                      value: overallProgress,
                                      backgroundColor: Theme.of(dialogCtx).colorScheme.surfaceContainerHighest,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE8B86D)),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '${(overallProgress * 100).toInt()}% completed',
                                      style: TextStyle(
                                        color: Theme.of(dialogCtx).colorScheme.onSurface,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        color: Theme.of(dialogCtx).colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );

                      try {
                        for (int i = 0; i < validFiles.length; i++) {
                          final pickedFile = validFiles[i];
                          final path = pickedFile.path!;
                          final file = File(path);
                          final extension = path.split('.').last.toLowerCase();
                          final isVideo = ['mp4', 'mov', 'avi'].contains(extension);
                          final mediaType = isVideo ? 'video' : 'photo';
                          final fileName = pickedFile.name;

                          if (dialogStateSetter != null) {
                            dialogStateSetter!(() {
                              currentFileProgress = 0.0;
                              statusText = 'Uploading $fileName...';
                            });
                          }

                          await ref.read(galleryRepositoryProvider).uploadMedia(
                            selectedGalleryId,
                            file: file,
                            mediaType: mediaType,
                            onProgress: (progress) {
                              if (dialogStateSetter != null) {
                                dialogStateSetter!(() {
                                  currentFileProgress = progress;
                                  if (progress >= 0.99) {
                                    statusText = 'Processing $fileName on server...';
                                  } else {
                                    statusText = 'Uploading $fileName (${(progress * 100).toInt()}%)...';
                                  }
                                });
                              }
                            },
                          );

                          completedCount++;
                          currentFileProgress = 0.0;
                        }
                      } finally {
                        if (mounted) {
                          uploadNavigator.pop();
                        }
                      }

                      if (mounted) {
                        ref.invalidate(folderTreeProvider(selectedGalleryId));
                        messenger.showSnackBar(
                          SnackBar(content: Text('Successfully uploaded $totalFiles files to gallery!')),
                        );
                      }
                    },
                    child: const Text('Start Upload', style: TextStyle(color: Color(0xFFE8B86D), fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to select or upload media: $e')),
        );
      }
    }
  }

  Future<void> _showCreateGalleryDialog() async {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161616) : const Color(0xFFF7F7F7),
          title: Text('Create Gallery', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Gallery Name',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(context);
                try {
                  await ref.read(galleryListProvider.notifier).createGallery(name);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gallery created successfully!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create gallery: $e')),
                    );
                  }
                }
              },
              child: const Text('Create', style: TextStyle(color: Color(0xFFE8B86D))),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody(GalleryListState state) {
    if (state.isOffline && !state.hasCache) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: Color(0xFF555555), size: 40),
            SizedBox(height: 12),
            Text(
              'No cached galleries available.',
              style: TextStyle(color: Color(0xFF777777)),
            ),
          ],
        ),
      );
    }

    if (state.galleries.isEmpty) {
      return const _EmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(galleryListProvider.notifier).refresh(),
      color: const Color(0xFFE8B86D),
      backgroundColor: const Color(0xFF1A1A1A),
      child: _isGrid ? _buildGrid(state) : _buildList(state),
    );
  }

  Widget _buildGrid(GalleryListState state) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: state.galleries.length,
      itemBuilder: (context, i) {
        final g = state.galleries[i];
        return GalleryCard(
          gallery: g,
          isGrid: true,
          onTap: () => context.push('/galleries/${g.id}'),
        );
      },
    );
  }

  Widget _buildList(GalleryListState state) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: state.galleries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final g = state.galleries[i];
        return GalleryCard(
          gallery: g,
          isGrid: false,
          onTap: () => context.push('/galleries/${g.id}'),
        );
      },
    );
  }

  Widget _buildAvatar(AuthUser user, double size, {double fontSize = 24}) {
    final photo = user.profilePhoto;

    if (photo != null && photo.isNotEmpty) {
      if (photo.startsWith('data:image/') && photo.contains('base64,')) {
        try {
          final base64Data = photo.split('base64,').last;
          final bytes = base64Decode(base64Data);
          return ClipOval(
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
        } catch (_) {}
      } else if (photo.startsWith('http')) {
        return ClipOval(
          child: Image.network(
            photo,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, _, __) => _buildInitials(user, size, fontSize),
          ),
        );
      }
    }
    return _buildInitials(user, size, fontSize);
  }

  Widget _buildInitials(AuthUser user, double size, double fontSize) {
    const gold = Color(0xFFE8B86D);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: gold.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Center(
        child: Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
          style: TextStyle(
            color: gold,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, AuthUser user) {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email ?? '');
    String? newImageBase64 = user.profilePhoto;
    File? localImageFile;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickImage() async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                  allowMultiple: false,
                );
                if (result != null && result.files.single.path != null) {
                  final path = result.files.single.path!;
                  final file = File(path);
                  final bytes = await file.readAsBytes();
                  final extension = path.split('.').last.toLowerCase();
                  final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
                  final base64String = base64Encode(bytes);

                  setDialogState(() {
                    localImageFile = file;
                    newImageBase64 = 'data:$mimeType;base64,$base64String';
                  });
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to pick image: $e')),
                  );
                }
              }
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF161616) : const Color(0xFFF7F7F7),
              title: Text(
                'Edit Profile',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar picker
                    GestureDetector(
                      onTap: pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEEEEEE),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE8B86D).withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                            child: localImageFile != null
                                ? ClipOval(
                                    child: Image.file(
                                      localImageFile!,
                                      width: 90,
                                      height: 90,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : _buildAvatar(user, 90, fontSize: 24),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8B86D),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 14,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () async {
                    final newName = nameController.text.trim();
                    final newEmail = emailController.text.trim();
                    if (newName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Name cannot be empty')),
                      );
                      return;
                    }
                    Navigator.pop(context); // close dialog

                    final success = await ref
                        .read(authNotifierProvider.notifier)
                        .updateProfile(
                          name: newName,
                          email: newEmail.isNotEmpty ? newEmail : null,
                          profilePhoto: newImageBase64,
                        );

                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile updated!')),
                      );
                    }
                  },
                  child: const Text('Save', style: TextStyle(color: Color(0xFFE8B86D))),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddBookingDialog() {
    ref.read(plansListProvider.notifier).loadPlans();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFE8B86D);

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String? selectedPlanId;
    bool isPaid = false;
    String paymentMethod = 'CASH';
    bool isSaving = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> selectDate() async {
              final date = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(selectedDate),
                );
                if (time != null) {
                  setDialogState(() {
                    selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                  });
                }
              }
            }

            Future<void> submit() async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              if (selectedPlanId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a pricing package.')),
                );
                return;
              }

              setDialogState(() {
                isSaving = true;
              });

              final success = await ref.read(bookingsListProvider.notifier).createBooking(
                selectedPlanId!,
                selectedDate.toUtc().toIso8601String(),
                addressController.text.trim(),
                customerName: nameController.text.trim(),
                customerPhone: phoneController.text.trim(),
                isPaid: isPaid,
                paymentMethod: paymentMethod,
              );

              if (context.mounted) {
                setDialogState(() {
                  isSaving = false;
                });
                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Direct booking created successfully!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to create booking. Please try again.')),
                  );
                }
              }
            }

            final plansAsync = ref.watch(plansListProvider);

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Create Direct Booking',
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: nameController,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        decoration: const InputDecoration(labelText: 'Client Name *', hintText: 'Enter client name'),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Client name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        decoration: const InputDecoration(labelText: 'Client Phone *', hintText: 'Enter 10-digit number'),
                        keyboardType: TextInputType.phone,
                        validator: (value) => value == null || value.trim().isEmpty ? 'Client phone is required' : null,
                      ),
                      const SizedBox(height: 12),
                      plansAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator(color: gold)),
                        error: (err, _) => Text('Error loading packages: $err', style: const TextStyle(color: Colors.red)),
                        data: (plans) {
                          if (plans.isEmpty) {
                            return const Text('No packages available. Please add a pricing package first.', style: TextStyle(color: Colors.redAccent, fontSize: 12));
                          }
                          return DropdownButtonFormField<String>(
                            value: selectedPlanId,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black),
                            decoration: const InputDecoration(labelText: 'Select Package *'),
                            dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                            items: plans.map((p) {
                              return DropdownMenuItem<String>(
                                value: p.id,
                                child: Text('${p.name} (₹${p.price.toStringAsFixed(0)})', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                              );
                            }).toList(),
                            onChanged: (val) => setDialogState(() => selectedPlanId = val),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Shoot Date & Time', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        subtitle: Text(
                          '${selectedDate.toLocal().toString().split(' ')[0]} at ${TimeOfDay.fromDateTime(selectedDate.toLocal()).format(context)}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black),
                        ),
                        trailing: const Icon(Icons.calendar_today_rounded, color: gold),
                        onTap: selectDate,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressController,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        decoration: const InputDecoration(labelText: 'Shoot Address/Venue *', hintText: 'Enter shoot location'),
                        maxLines: 2,
                        validator: (value) => value == null || value.trim().isEmpty ? 'Shoot address is required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: isPaid,
                            activeColor: gold,
                            onChanged: (val) => setDialogState(() => isPaid = val ?? false),
                          ),
                          const Expanded(child: Text('Advance Paid (25%)', style: TextStyle(fontSize: 13))),
                        ],
                      ),
                      if (isPaid) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: paymentMethod,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          decoration: const InputDecoration(labelText: 'Payment Method'),
                          dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                          items: const [
                            DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                            DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                            DropdownMenuItem(value: 'QR_CODE', child: Text('QR Code')),
                          ],
                          onChanged: (val) => setDialogState(() => paymentMethod = val ?? 'CASH'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black),
                  onPressed: isSaving ? null : submit,
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Text('Create Booking'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE8B86D);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: gold.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.photo_library_outlined,
                  color: gold, size: 32),
            ),
            const SizedBox(height: 20),
            const Text(
              'No galleries yet',
              style: TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Galleries assigned to you will appear here.',
              style: TextStyle(color: Color(0xFF666666), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
