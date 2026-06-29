import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../plans/presentation/screens/plans_manager_screen.dart';
import '../../../bookings/data/repositories/bookings_repository.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({
    super.key,
    required this.onEditProfile,
  });

  final VoidCallback onEditProfile;

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    if (authState is! AuthAuthenticated) {
      return Center(
        child: Text('Not logged in', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      );
    }

    final user = authState.user;
    const gold = Color(0xFFE8B86D);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bookingsAsync = ref.watch(bookingsListProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // Premium Profile Header (Avatar & Centered Details)
          Center(
            child: _buildAvatar(user, 100, fontSize: 36),
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          if (user.email != null && user.email!.isNotEmpty) ...[
            Text(
              user.email!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
          ],
          if (user.phone != null && user.phone!.isNotEmpty) ...[
            Text(
              '📞 +91 ${user.phone}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: gold.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 28),

          // Stats Cards Grid
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Galleries',
                  '${user.galleryIds.length}',
                  Icons.photo_library_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Bookings',
                  bookingsAsync.when(
                    data: (list) => '${list.length}',
                    loading: () => '...',
                    error: (_, __) => '0',
                  ),
                  Icons.event_note_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Role',
                  user.isStudioOwner ? 'Owner' : 'Client',
                  Icons.badge_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Recent Activities / Bookings Feed
          bookingsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: gold, strokeWidth: 2),
              ),
            ),
            error: (err, _) => const SizedBox.shrink(),
            data: (bookings) {
              if (bookings.isEmpty) return const SizedBox.shrink();
              final recent = bookings.take(3).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Recent Bookings Activity',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: -0.3),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...recent.map((booking) {
                    final statusColor = booking.status == 'PENDING'
                        ? gold
                        : (booking.status == 'CONFIRMED' ? Colors.greenAccent : Colors.grey);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161616) : const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE2E2E2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: gold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.event_available, color: gold, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking.plan?.name ?? 'Shoot Session',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  booking.bookingDate.toLocal().toString().split(' ')[0],
                                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              booking.status,
                              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          )
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),

          // Action Tiles Row
          _buildListTile(
            context,
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            subtitle: 'Update name, email, phone & location',
            onTap: () => _openEditProfileSheet(context, user),
          ),
          if (user.isStudioOwner) ...[
            const SizedBox(height: 12),
            _buildListTile(
              context,
              icon: Icons.payments_outlined,
              title: 'My Pricing Plans',
              subtitle: 'Manage shoot package rates & details',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const PlansManagerScreen(),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          _buildListTile(
            context,
            icon: Icons.security_rounded,
            title: 'Security & Protections',
            subtitle: 'Learn about screenshot and download guards',
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: isDark ? const Color(0xFF161616) : const Color(0xFFF7F7F7),
                  title: Text('Security Features', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  content: Text(
                    'This application automatically prevents taking screenshots, video recording, and unauthorized sharing/download of media in galleries you do not own.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
            context,
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            subtitle: 'Contact us for help with your galleries',
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: isDark ? const Color(0xFF161616) : const Color(0xFFF7F7F7),
                  title: Text('Support', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  content: Text(
                    'If you have any questions or experience issues, please contact your photography studio administrator.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFE8B86D);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E5E5),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: gold, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
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
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF161616)
              : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2E2E2E)
                : const Color(0xFFE5E5E5),
          ),
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  void _openEditProfileSheet(BuildContext context, AuthUser user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _EditProfileSheet(user: user, ref: ref);
      },
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final AuthUser user;
  final WidgetRef ref;

  const _EditProfileSheet({required this.user, required this.ref});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _locationController;
  late final TextEditingController _studioNameController;
  late final TextEditingController _descriptionController;

  String? _newImageBase64;
  File? _localImageFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email ?? '');
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _locationController = TextEditingController(text: widget.user.location ?? '');
    _studioNameController = TextEditingController(text: widget.user.studioName ?? '');
    _descriptionController = TextEditingController(text: widget.user.description ?? '');
    _newImageBase64 = widget.user.profilePhoto;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _studioNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
      if (image != null) {
        final path = image.path;
        final file = File(path);
        final bytes = await file.readAsBytes();
        final extension = path.split('.').last.toLowerCase();
        final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
        final base64String = base64Encode(bytes);

        setState(() {
          _localImageFile = file;
          _newImageBase64 = 'data:$mimeType;base64,$base64String';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _save() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final location = _locationController.text.trim();
    final studioName = _studioNameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    if (phone.isNotEmpty && phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number must be exactly 10 digits')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final success = await widget.ref.read(authNotifierProvider.notifier).updateProfile(
      name: name,
      email: email.isNotEmpty ? email : null,
      phone: phone.isNotEmpty ? phone : null,
      profilePhoto: _newImageBase64,
      studioName: widget.user.isStudioOwner && studioName.isNotEmpty ? studioName : null,
      location: location.isNotEmpty ? location : null,
      description: widget.user.isStudioOwner && description.isNotEmpty ? description : null,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated!')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFE8B86D);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Edit Profile Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            
            // Image Picker Avatar
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: gold.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: _localImageFile != null
                        ? ClipOval(
                            child: Image.file(
                              _localImageFile!,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                            ),
                          )
                        : _buildAvatarHelper(widget.user, 90, fontSize: 24),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: gold,
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
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number (10 digits)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Address / Location',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            if (widget.user.isStudioOwner) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _studioNameController,
                decoration: const InputDecoration(
                  labelText: 'Studio Name',
                  prefixIcon: Icon(Icons.storefront),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Studio Description',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
            ],
            const SizedBox(height: 28),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarHelper(AuthUser user, double size, {double fontSize = 24}) {
    final photo = _newImageBase64;
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
            errorBuilder: (context, _, __) => _buildInitialsHelper(user, size, fontSize),
          ),
        );
      }
    }
    return _buildInitialsHelper(user, size, fontSize);
  }

  Widget _buildInitialsHelper(AuthUser user, double size, double fontSize) {
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
