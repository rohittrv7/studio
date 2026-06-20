import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/folder.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../qr_scanner/presentation/widgets/qr_display_dialog.dart';
import '../../../media/presentation/widgets/media_grid.dart';
import '../providers/gallery_provider.dart';
import '../widgets/folder_tile.dart';
import '../../../../core/utils/security_util.dart';
import '../../../../core/widgets/error_display.dart';

/// Folder view screen — shows contents of a specific folder inside a gallery.
class FolderViewScreen extends ConsumerStatefulWidget {
  const FolderViewScreen({
    super.key,
    required this.id,
    required this.folderId,
  });

  /// The gallery ID.
  final String id;

  /// The folder ID to display.
  final String folderId;

  @override
  ConsumerState<FolderViewScreen> createState() => _FolderViewScreenState();
}

class _FolderViewScreenState extends ConsumerState<FolderViewScreen> {
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    // Secure by default when entering the folder view
    SecurityUtil.setSecure(true);
  }

  @override
  void dispose() {
    // Clear secure flag when leaving the screen
    SecurityUtil.setSecure(false);
    super.dispose();
  }

  Future<void> _showCreateSubfolderDialog() async {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161616) : const Color(0xFFF7F7F7),
          title: Text(
            'Create Subfolder',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          content: TextField(
            controller: controller,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Subfolder Name',
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
                  await ref.read(galleryRepositoryProvider).createFolder(
                    widget.id,
                    name: name,
                    parentFolderId: widget.folderId,
                  );
                  ref.invalidate(folderTreeProvider(widget.id));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Subfolder created successfully!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create subfolder: $e')),
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

  Future<void> _uploadMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'avi'],
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final totalFiles = result.files.length;
        final validFiles = result.files.where((f) => f.path != null).toList();
        if (validFiles.isEmpty) return;

        int completedCount = 0;
        double currentFileProgress = 0.0;
        String statusText = 'Starting upload...';
        void Function(void Function())? dialogStateSetter;

        if (!mounted) return;

        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return StatefulBuilder(
              builder: (statefulCtx, setDialogState) {
                dialogStateSetter = setDialogState;
                final double overallProgress = totalFiles > 0
                    ? (completedCount + currentFileProgress) / totalFiles
                    : 0.0;
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
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: overallProgress,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE8B86D)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${(overallProgress * 100).toInt()}% completed',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              widget.id,
              file: file,
              mediaType: mediaType,
              folderId: widget.folderId,
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
            Navigator.pop(context);
          }
        }

        if (mounted) {
          setState(() {
            _refreshKey++;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully uploaded $totalFiles files!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload media: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final folderTreeAsync = ref.watch(folderTreeProvider(widget.id));
    final authState = ref.watch(authNotifierProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final isStudioOwner = user?.isStudioOwner ?? false;
    const gold = Color(0xFFE8B86D);

    final galleryAsync = ref.watch(galleryDetailProvider(widget.id));
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

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/galleries/${widget.id}');
      },
      child: folderTreeAsync.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Scaffold(
          appBar: AppBar(
            title: const Text('Folder'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/galleries/${widget.id}');
                }
              },
            ),
          ),
          body: ErrorDisplay(
            title: 'Failed to load folder',
            message: error.toString(),
            onRetry: () => ref.invalidate(folderTreeProvider(widget.id)),
          ),
        ),
        data: (folders) {
          final folder = _findFolder(folders, widget.folderId);
          if (folder == null) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Folder'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/galleries/${widget.id}');
                    }
                  },
                ),
              ),
              body: const ErrorDisplay(
                title: 'Folder Not Found',
                message: 'The requested folder could not be found in this gallery.',
              ),
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(folder.name),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/galleries/${widget.id}');
                  }
                },
              ),
            ),
            body: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(folderTreeProvider(widget.id));
                setState(() {
                  _refreshKey++;
                });
              },
              color: gold,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFF5F5F5),
              child: Builder(
                builder: (context) {
                  final folderSlivers = [
                    // Breadcrumb
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Gallery › ${folder.name}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                    ),
                    // Child folders
                    if (folder.children.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final child = folder.children[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: FolderTile(
                                  folder: child,
                                  onTap: () => context.push(
                                    '/galleries/${widget.id}/folders/${child.id}',
                                  ),
                                ),
                              );
                            },
                            childCount: folder.children.length,
                          ),
                        ),
                      ),
                  ];

                  return MediaGrid(
                    key: ValueKey('${widget.folderId}_$_refreshKey'),
                    galleryId: widget.id,
                    folderId: widget.folderId,
                    prependSlivers: folderSlivers,
                  );
                },
              ),
            ),
            floatingActionButton: isStudioOwner
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
                                  leading: const Icon(Icons.create_new_folder_outlined, color: gold),
                                  title: Text(
                                    'Create Subfolder',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showCreateSubfolderDialog();
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.upload_file_outlined, color: gold),
                                  title: Text(
                                    'Upload Photo / Video',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _uploadMedia();
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.qr_code_rounded, color: gold),
                                  title: Text(
                                    'Get Folder QR Code',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    QrDisplayDialog.show(
                                      context,
                                      galleryId: widget.id,
                                      folderId: widget.folderId,
                                      title: 'Folder QR Code',
                                    );
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
          );
        },
      ),
    );
  }

  /// Recursively finds a [Folder] by [id] in the flat/tree structure.
  Folder? _findFolder(List<Folder> folders, String id) {
    for (final folder in folders) {
      if (folder.id == id) return folder;
      final found = _findFolder(folder.children, id);
      if (found != null) return found;
    }
    return null;
  }
}
