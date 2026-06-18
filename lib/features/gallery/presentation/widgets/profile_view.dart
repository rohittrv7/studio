import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({
    super.key,
    required this.onEditProfile,
  });

  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    if (authState is! AuthAuthenticated) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(
          child: Text('Not logged in', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final user = authState.user;
    const gold = Color(0xFFE8B86D);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Avatar
              Center(
                child: _buildAvatar(user, 90, fontSize: 32),
              ),
              const SizedBox(height: 20),
              // User info
              Text(
                user.name,
                style: const TextStyle(
                  color: Color(0xFFEEEEEE),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              if (user.email != null && user.email!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  user.email!,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: gold.withValues(alpha: 0.2)),
                ),
                child: Text(
                  user.isStudioOwner ? 'Studio Owner' : 'Customer',
                  style: const TextStyle(
                    color: gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Action Tiles
              _buildListTile(
                icon: Icons.edit_outlined,
                title: 'Edit Profile',
                subtitle: 'Update your display name and email',
                onTap: onEditProfile,
              ),
              const SizedBox(height: 12),
              _buildListTile(
                icon: Icons.security_rounded,
                title: 'Security & Protections',
                subtitle: 'Learn about screenshot and download guards',
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF161616),
                      title: const Text('Security Features', style: TextStyle(color: Colors.white)),
                      content: const Text(
                        'This application automatically prevents taking screenshots, video recording, and unauthorized sharing/download of media in galleries you do not own.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Got it', style: TextStyle(color: gold)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildListTile(
                icon: Icons.help_outline_rounded,
                title: 'Help & Support',
                subtitle: 'Contact us for help with your galleries',
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF161616),
                      title: const Text('Support', style: TextStyle(color: Colors.white)),
                      content: const Text(
                        'If you have any questions or experience issues, please contact your photography studio administrator.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close', style: TextStyle(color: gold)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () async {
                    await ref.read(authNotifierProvider.notifier).logoutCurrentUser();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935).withValues(alpha: 0.1),
                    foregroundColor: const Color(0xFFEF5350),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'Logout',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    const gold = Color(0xFFE8B86D);
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
            Icon(icon, color: gold, size: 22),
            const SizedBox(width: 16),
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
        border: Border.all(color: gold.withValues(alpha: 0.3), width: 2),
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
}
