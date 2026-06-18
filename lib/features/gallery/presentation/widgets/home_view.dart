import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/gallery_provider.dart';

class HomeView extends ConsumerWidget {
  const HomeView({
    super.key,
    required this.onCreateGallery,
    required this.onCreateFolder,
    required this.onUploadMedia,
    required this.onShowGalleries,
  });

  final VoidCallback onCreateGallery;
  final VoidCallback onCreateFolder;
  final VoidCallback onUploadMedia;
  final VoidCallback onShowGalleries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final galleryState = ref.watch(galleryListProvider);
    final galleries = galleryState.value?.galleries ?? [];
    final isStudioOwner = user?.isStudioOwner ?? false;
    const gold = Color(0xFFE8B86D);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header / Welcome ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user != null ? 'Hello, ${user.name} 👋' : 'Welcome!',
                          style: const TextStyle(
                            color: Color(0xFFF2F2F2),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isStudioOwner
                              ? 'Manage your photography studio galleries'
                              : 'Access your premium memory albums',
                          style: const TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Stat Cards ─────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onShowGalleries,
                      child: _buildStatCard(
                        context,
                        title: 'Total Galleries',
                        value: '${galleries.length}',
                        icon: Icons.photo_library_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Role',
                      value: isStudioOwner ? 'Studio' : 'Client',
                      icon: isStudioOwner ? Icons.camera_alt_outlined : Icons.person_outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Quick Actions ──────────────────────────────────────────────
              const Text(
                'Quick Actions',
                style: TextStyle(
                  color: Color(0xFFF2F2F2),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 16),
              // Scan QR card (always available)
              _buildActionCard(
                context,
                title: 'Scan QR Code',
                subtitle: 'Scan a QR code to view a gallery or folder',
                icon: Icons.qr_code_scanner_rounded,
                color: gold,
                onTap: () => context.push('/qr'),
              ),
              const SizedBox(height: 12),

              // Favorites Folder card (always available)
              _buildActionCard(
                context,
                title: 'Favorites Folder',
                subtitle: 'View all your favorited photos & videos',
                icon: Icons.favorite_rounded,
                color: Colors.redAccent,
                onTap: () => context.push('/favorites'),
              ),
              const SizedBox(height: 12),

              if (isStudioOwner) ...[
                _buildActionCard(
                  context,
                  title: 'Create Gallery',
                  subtitle: 'Create a new client photo collection',
                  icon: Icons.add_to_photos_outlined,
                  color: gold,
                  onTap: onCreateGallery,
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  title: 'Create Folder',
                  subtitle: 'Add a new directory inside a gallery',
                  icon: Icons.create_new_folder_outlined,
                  color: gold,
                  onTap: onCreateFolder,
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  title: 'Upload Media',
                  subtitle: 'Upload photos/videos directly to a gallery',
                  icon: Icons.cloud_upload_outlined,
                  color: gold,
                  onTap: onUploadMedia,
                ),
                const SizedBox(height: 28),
              ],

              // ── Aesthetic Banner ───────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1E1E1E),
                      gold.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: gold.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, color: gold, size: 24),
                    const SizedBox(height: 12),
                    const Text(
                      'Capture & Share Memories',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This app protects your photography content. Download and screenshot protections are automatically active where configured.',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
  }) {
    const gold = Color(0xFFE8B86D);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: gold, size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF222222)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
