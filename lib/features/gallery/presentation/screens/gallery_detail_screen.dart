import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../../../../features/analytics/data/datasources/analytics_remote_data_source.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../qr_scanner/presentation/widgets/qr_display_dialog.dart';
import '../../domain/entities/gallery.dart';
import '../providers/gallery_provider.dart';
import '../widgets/folder_tile.dart';
import '../../../../core/utils/security_util.dart';
import '../../../media/presentation/widgets/media_grid.dart';
import '../../../../core/widgets/error_display.dart';

/// Gallery detail screen — dark theme with folder tree.
class GalleryDetailScreen extends ConsumerStatefulWidget {
  const GalleryDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<GalleryDetailScreen> createState() =>
      _GalleryDetailScreenState();
}

class _GalleryDetailScreenState extends ConsumerState<GalleryDetailScreen> {
  int _refreshCount = 0;

  @override
  void initState() {
    super.initState();
    // Secure by default when entering the gallery detail screen
    SecurityUtil.setSecure(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authNotifierProvider);
      if (authState is AuthAuthenticated && authState.user.isCustomer) {
        ref.read(analyticsRemoteDataSourceProvider).recordView(widget.id);
      }
    });
  }

  @override
  void dispose() {
    // Clear secure flag when leaving the screen
    SecurityUtil.setSecure(false);
    super.dispose();
  }

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161616) : const Color(0xFFF7F7F7),
          title: Text('Create Folder', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Folder Name',
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
                  );
                  ref.invalidate(folderTreeProvider(widget.id));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Folder created successfully!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
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
            return StatefulBuilder(
              builder: (statefulCtx, setDialogState) {
                dialogStateSetter = setDialogState;
                final double overallProgress = totalFiles > 0
                    ? (completedCount + currentFileProgress) / totalFiles
                    : 0.0;
                final isDark = Theme.of(context).brightness == Brightness.dark;
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
          ref.invalidate(folderTreeProvider(widget.id));
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

  void _showAssignCustomerDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => _AssignCustomerDialog(galleryId: widget.id),
    );
  }

  Future<void> _toggleShowcase(bool val) async {
    try {
      await ref.read(galleryRepositoryProvider).updateGallery(widget.id, showcase: val);
      ref.invalidate(galleryDetailProvider(widget.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(val ? 'Added to showcase portfolio!' : 'Removed from showcase portfolio.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update showcase: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ConnectivityState>(connectivityStatusProvider, (prev, next) {
      if (next.justReconnected) {
        ref.invalidate(galleryDetailProvider(widget.id));
        ref.invalidate(folderTreeProvider(widget.id));
        ref.read(connectivityStatusProvider.notifier).acknowledgeReconnect();
      }
    });

    final galleryAsync = ref.watch(galleryDetailProvider(widget.id));
    final folderTreeAsync = ref.watch(folderTreeProvider(widget.id));
    final authState = ref.watch(authNotifierProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final isStudioOwner = user?.isStudioOwner ?? false;
    const gold = Color(0xFFE8B86D);
    final analyticsAsync = isStudioOwner
        ? ref.watch(galleryAnalyticsProvider(widget.id))
        : null;

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
        context.go('/galleries');
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // ── Custom top bar ────────────────────────────────────────────
                galleryAsync.maybeWhen(
                  data: (gallery) => _TopBar(
                    title: gallery.name,
                    onBack: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/galleries');
                      }
                    },
                    customer: gallery.customer,
                    isStudioOwner: isStudioOwner,
                    showcase: gallery.showcase,
                    onShowcaseChanged: (val) => _toggleShowcase(val),
                  ),
                  orElse: () => _TopBar(
                    title: 'Gallery',
                    onBack: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/galleries');
                      }
                    },
                    isStudioOwner: isStudioOwner,
                  ),
                ),

                const OfflineBanner(),

                // ── Body ──────────────────────────────────────────────────────
                Expanded(
                  child: galleryAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: gold, strokeWidth: 2),
                    ),
                    error: (e, _) => ErrorDisplay(
                      title: 'Failed to Load Gallery',
                      message: e.toString(),
                      onRetry: () => ref.invalidate(galleryDetailProvider(widget.id)),
                    ),
                    data: (gallery) {
                      return folderTreeAsync.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                              color: gold, strokeWidth: 2),
                        ),
                        error: (e, _) => ErrorDisplay(
                          title: 'Failed to Load Folders',
                          message: e.toString(),
                          onRetry: () => ref.invalidate(folderTreeProvider(widget.id)),
                        ),
                        data: (folders) {
                          final folderSlivers = [
                            if (isStudioOwner && analyticsAsync != null)
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                                sliver: SliverToBoxAdapter(
                                  child: analyticsAsync.maybeWhen(
                                    data: (stats) {
                                      final views = stats['totalViewCount'] ?? 0;
                                      final downloads = stats['totalDownloadCount'] ?? 0;
                                      final isDark = Theme.of(context).brightness == Brightness.dark;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF161616) : const Color(0xFFF7F7F7),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E5E5),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                                          children: [
                                            _buildStatItem(context, Icons.remove_red_eye_outlined, 'Total Views', '$views'),
                                            Container(
                                              width: 1,
                                              height: 30,
                                              color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E5E5),
                                            ),
                                            _buildStatItem(context, Icons.download_outlined, 'Downloads', '$downloads'),
                                          ],
                                        ),
                                      );
                                    },
                                    orElse: () => const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                              sliver: SliverToBoxAdapter(
                                child: _FavoritesFolderTile(
                                  onTap: () => context.push('/favorites'),
                                ),
                              ),
                            ),
                            if (folders.isNotEmpty)
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, i) {
                                      final folder = folders[i];
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: FolderTile(
                                          folder: folder,
                                          onTap: () => context.push(
                                            '/galleries/${widget.id}/folders/${folder.id}',
                                          ),
                                        ),
                                      );
                                    },
                                    childCount: folders.length,
                                  ),
                                ),
                              ),
                          ];

                          return RefreshIndicator(
                            onRefresh: () async {
                              ref.invalidate(galleryDetailProvider(widget.id));
                              ref.invalidate(folderTreeProvider(widget.id));
                              if (isStudioOwner) {
                                ref.invalidate(galleryAnalyticsProvider(widget.id));
                              }
                              setState(() {
                                _refreshCount++;
                              });
                            },
                            color: gold,
                            backgroundColor: const Color(0xFF1A1A1A),
                            child: MediaGrid(
                              key: ValueKey('media_grid_${widget.id}_$_refreshCount'),
                              galleryId: widget.id,
                              folderId: null,
                              prependSlivers: folderSlivers,
                              emptyPlaceholder: const _EmptyGallery(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
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
                                title: Text('Create Folder', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                onTap: () {
                                  Navigator.pop(context);
                                  _showCreateFolderDialog();
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.upload_file_outlined, color: gold),
                                title: Text('Upload Photo / Video', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                onTap: () {
                                  Navigator.pop(context);
                                  _uploadMedia();
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.person_add_alt_1_outlined, color: gold),
                                title: const Text('Assign Customer', style: TextStyle(color: Colors.white)),
                                onTap: () {
                                  Navigator.pop(context);
                                  _showAssignCustomerDialog();
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.qr_code_rounded, color: gold),
                                title: const Text('Get Gallery QR Code', style: TextStyle(color: Colors.white)),
                                onTap: () {
                                  Navigator.pop(context);
                                  QrDisplayDialog.show(
                                    context,
                                    galleryId: widget.id,
                                    title: 'Gallery QR Code',
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
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, IconData icon, String label, String value) {
    const gold = Color(0xFFE8B86D);
    return Row(
      children: [
        Icon(icon, color: gold, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onBack,
    this.customer,
    required this.isStudioOwner,
    this.showcase = false,
    this.onShowcaseChanged,
  });

  final String title;
  final VoidCallback onBack;
  final Customer? customer;
  final bool isStudioOwner;
  final bool showcase;
  final ValueChanged<bool>? onShowcaseChanged;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE8B86D);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: Color(0xFFAAAAAA), size: 22),
            onPressed: onBack,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFF2F2F2),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isStudioOwner) ...[
                  if (customer != null)
                    Text(
                      'Assigned to: ${customer!.name} (${customer!.phone})',
                      style: const TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    const Text(
                      'Not assigned to any customer',
                      style: TextStyle(
                        color: Color(0xFFE88A8A),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                ]
              ],
            ),
          ),
          if (isStudioOwner && onShowcaseChanged != null) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_border_rounded, color: gold, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Showcase',
                  style: TextStyle(
                    color: showcase ? gold : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  height: 30,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: Switch(
                      value: showcase,
                      activeColor: gold,
                      onChanged: onShowcaseChanged,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyGallery extends StatelessWidget {
  const _EmptyGallery();

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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: gold.withValues(alpha: 0.15)),
              ),
              child: const Icon(Icons.photo_library_outlined,
                  color: gold, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'No items yet',
              style: TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'This gallery has no folders or media.',
              style: TextStyle(color: Color(0xFF666666), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignCustomerDialog extends ConsumerStatefulWidget {
  const _AssignCustomerDialog({required this.galleryId});
  final String galleryId;

  @override
  ConsumerState<_AssignCustomerDialog> createState() => _AssignCustomerDialogState();
}

class _AssignCustomerDialogState extends ConsumerState<_AssignCustomerDialog> {
  String _searchQuery = '';
  bool _isCreatingNew = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool? _downloadEnabled;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE8B86D);
    final customersAsync = ref.watch(customersListProvider);
    final detailAsync = ref.watch(galleryDetailProvider(widget.galleryId));
    final currentDownloadEnabled = detailAsync.maybeWhen(
      data: (g) => g.downloadEnabled,
      orElse: () => true,
    );
    _downloadEnabled ??= currentDownloadEnabled;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF161616) : const Color(0xFFF7F7F7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        _isCreatingNew ? 'Create & Assign Customer' : 'Assign Customer',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: gold)),
              )
            : _isCreatingNew
                ? _buildCreateForm()
                : _buildSelectionList(customersAsync),
      ),
      actions: [
        if (!_isLoading) ...[
          TextButton(
            onPressed: () {
              if (_isCreatingNew) {
                setState(() => _isCreatingNew = false);
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          if (_isCreatingNew)
            TextButton(
              onPressed: _handleCreateAndAssign,
              child: const Text('Create & Assign', style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
            )
          else
            TextButton(
              onPressed: () => setState(() => _isCreatingNew = true),
              child: const Text('New Customer', style: TextStyle(color: gold)),
            ),
        ]
      ],
    );
  }

  Widget _buildCreateForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Name',
              labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.outline)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8B86D))),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone',
              labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.outline)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8B86D))),
            ),
            validator: (v) {
              final val = v?.trim() ?? '';
              if (val.isEmpty) return 'Phone is required';
              if (!RegExp(r'^\d{10}$').hasMatch(val)) {
                return 'Enter a valid 10-digit number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: Text('Allow Client to Download Photos', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13)),
            value: _downloadEnabled ?? true,
            onChanged: (val) => setState(() => _downloadEnabled = val),
            activeColor: const Color(0xFFE8B86D),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionList(AsyncValue<List<Customer>> customersAsync) {
    const gold = Color(0xFFE8B86D);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Search by name or phone...',
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.outline)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: gold)),
          ),
          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          title: Text('Allow Client to Download Photos', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13)),
          value: _downloadEnabled ?? true,
          onChanged: (val) => setState(() => _downloadEnabled = val),
          activeColor: gold,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 12),
        Flexible(
          child: customersAsync.when(
            loading: () => const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator(color: gold)),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
            ),
            data: (list) {
              final filtered = list.where((c) {
                return c.name.toLowerCase().contains(_searchQuery) ||
                    c.phone.toLowerCase().contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return SizedBox(
                  height: 100,
                  child: Center(
                    child: Text('No customers found', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                );
              }

              return SizedBox(
                height: 250,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final customer = filtered[idx];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(customer.name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                      subtitle: Text(customer.phone, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: gold),
                      onTap: () => _handleAssign(customer.id),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _handleAssign(String customerId) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(galleryRepositoryProvider).assignGallery(
        widget.galleryId,
        customerId: customerId,
        downloadEnabled: _downloadEnabled ?? true,
      );
      ref.invalidate(galleryDetailProvider(widget.galleryId));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer assigned successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign customer: $e')),
        );
      }
    }
  }

  Future<void> _handleCreateAndAssign() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      final phone = _phoneController.text.trim();
      final newCustomer = await ref.read(galleryRepositoryProvider).createCustomer(
        name: _nameController.text.trim(),
        phone: phone,
      );
      // Invalidate customer list cache
      ref.invalidate(customersListProvider);
      
      // Assign the newly created customer
      await ref.read(galleryRepositoryProvider).assignGallery(
        widget.galleryId,
        customerId: newCustomer.id,
        downloadEnabled: _downloadEnabled ?? true,
      );
      ref.invalidate(galleryDetailProvider(widget.galleryId));
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Customer ${newCustomer.name} created and assigned successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create & assign customer: $e')),
        );
      }
    }
  }
}

class _FavoritesFolderTile extends StatelessWidget {
  const _FavoritesFolderTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const red = Colors.redAccent;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161616) : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E5E5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: red.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: red,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Favorites',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF444444),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
