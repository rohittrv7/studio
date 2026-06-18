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

/// Gallery list screen — the main landing screen after login.
class GalleriesScreen extends ConsumerStatefulWidget {
  const GalleriesScreen({super.key});

  @override
  ConsumerState<GalleriesScreen> createState() => _GalleriesScreenState();
}

class _GalleriesScreenState extends ConsumerState<GalleriesScreen> {
  // Toggle between grid and list view.
  bool _isGrid = true;
  int _currentIndex = 0; // 0: Home, 1: Galleries, 2: Profile

  @override
  Widget build(BuildContext context) {
    ref.listen<ConnectivityState>(connectivityStatusProvider, (prev, next) {
      if (next.justReconnected) {
        ref.read(galleryListProvider.notifier).refresh();
        ref.read(connectivityStatusProvider.notifier).acknowledgeReconnect();
      }
    });

    final asyncState = ref.watch(galleryListProvider);
    final authState = ref.watch(authNotifierProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    const gold = Color(0xFFE8B86D);

    Widget activeBody;
    late final String title;
    bool showGridListToggle = false;

    if (_currentIndex == 0) {
      activeBody = HomeView(
        onCreateGallery: () => _showCreateGalleryDialog(),
        onCreateFolder: () => _showCreateFolderFromOutsideDialog(),
        onUploadMedia: () => _showUploadMediaFromOutsideDialog(),
        onShowGalleries: () => setState(() => _currentIndex = 1),
      );
      title = 'Studio Gallery';
    } else if (_currentIndex == 2) {
      activeBody = user != null
          ? ProfileView(
              onEditProfile: () => _showEditProfileDialog(context, user),
            )
          : const Center(child: Text('Not logged in'));
      title = 'My Profile';
    } else {
      activeBody = asyncState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: gold,
            strokeWidth: 2,
          ),
        ),
        error: (error, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error.toString())),
              );
            }
          });
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFF666666), size: 40),
                const SizedBox(height: 12),
                const Text(
                  'Failed to load galleries.',
                  style: TextStyle(color: Color(0xFF888888)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () =>
                      ref.read(galleryListProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        },
        data: (state) => _buildBody(state),
      );
      title = 'My Galleries';
      showGridListToggle = true;
    }

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
        backgroundColor: const Color(0xFF0D0D0D),
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
                      child:
                          const Icon(Icons.camera_alt_rounded, color: gold, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFFF2F2F2),
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
                child: activeBody,
              ),
            ],
          ),
        ),
        floatingActionButton: user != null && user.isStudioOwner && _currentIndex == 1
            ? FloatingActionButton(
                backgroundColor: gold,
                foregroundColor: Colors.black,
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: const Color(0xFF161616),
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
                              title: const Text('Create Gallery', style: TextStyle(color: Colors.white)),
                              onTap: () {
                                Navigator.pop(context);
                                _showCreateGalleryDialog();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.create_new_folder_outlined, color: gold),
                              title: const Text('Create Folder in Gallery', style: TextStyle(color: Colors.white)),
                              onTap: () {
                                Navigator.pop(context);
                                _showCreateFolderFromOutsideDialog();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.upload_file_outlined, color: gold),
                              title: const Text('Upload to Gallery', style: TextStyle(color: Colors.white)),
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
          backgroundColor: const Color(0xFF161616),
          selectedItemColor: gold,
          unselectedItemColor: const Color(0xFF888888),
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.photo_library_outlined),
              activeIcon: Icon(Icons.photo_library_rounded),
              label: 'Gallery',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    ),);
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
            return AlertDialog(
              backgroundColor: const Color(0xFF161616),
              title: const Text('Create Folder', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Gallery:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  DropdownButton<String>(
                    value: selectedGalleryId,
                    dropdownColor: const Color(0xFF161616),
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white),
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
              return AlertDialog(
                backgroundColor: const Color(0xFF161616),
                title: const Text('Select Gallery to Upload', style: TextStyle(color: Colors.white)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Uploading $totalFiles selected files.', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    const Text('Select Target Gallery:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    DropdownButton<String>(
                      value: selectedGalleryId,
                      dropdownColor: const Color(0xFF161616),
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white),
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
                              return AlertDialog(
                                backgroundColor: const Color(0xFF161616),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.cloud_upload_outlined, color: Color(0xFFE8B86D), size: 40),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Uploading Media (${completedCount + 1}/$totalFiles)',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 16),
                                    LinearProgressIndicator(
                                      value: overallProgress,
                                      backgroundColor: Colors.white12,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE8B86D)),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '${(overallProgress * 100).toInt()}% completed',
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      statusText,
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
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
        return AlertDialog(
          backgroundColor: const Color(0xFF161616),
          title: const Text('Create Gallery', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Gallery Name',
              hintStyle: TextStyle(color: Colors.grey),
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

            return AlertDialog(
              backgroundColor: const Color(0xFF161616),
              title: const Text(
                'Edit Profile',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                              color: const Color(0xFF1E1E1E),
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
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.email_outlined),
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
