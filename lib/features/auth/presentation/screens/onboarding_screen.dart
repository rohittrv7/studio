import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

/// Onboarding screen for new users to fill in their name, email, and profile photo.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _studioNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _imageFile;
  String? _imageBase64;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _studioNameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
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

        setState(() {
          _imageFile = file;
          _imageBase64 = 'data:$mimeType;base64,$base64String';
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authNotifierProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final isStudio = user?.isStudioOwner ?? false;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final studioName = isStudio ? _studioNameController.text.trim() : null;
    final location = _locationController.text.trim();
    final description = isStudio ? _descriptionController.text.trim() : null;

    final success = await ref.read(authNotifierProvider.notifier).updateProfile(
          name: name,
          email: email.isNotEmpty ? email : null,
          profilePhoto: _imageBase64,
          studioName: studioName,
          location: location.isNotEmpty ? location : null,
          description: (description != null && description.isNotEmpty) ? description : null,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile created successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authNotifierProvider, (_, next) {
      if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message)),
        );
      }
    });

    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final isStudio = user?.isStudioOwner ?? false;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            // ── Background gradient blobs ────────────────────────────────────
            Positioned(
              top: -80,
              right: -80,
              child: _GradientBlob(
                color: cs.primary.withValues(alpha: 0.12),
                size: 280,
              ),
            ),
            Positioned(
              bottom: 80,
              left: -60,
              child: _GradientBlob(
                color: cs.secondary.withValues(alpha: 0.08),
                size: 220,
              ),
            ),

            // ── Main content ─────────────────────────────────────────────────
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 24),
                          
                          // ── Title ──────────────────────────────────────────
                          Text(
                            'Complete Profile',
                            style: Theme.of(context)
                                .textTheme
                                .displayLarge
                                ?.copyWith(fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Set up your details to get started',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontSize: 15, color: const Color(0xFF888888)),
                          ),
                          const SizedBox(height: 36),

                          // ── Avatar Picker ──────────────────────────────────
                          GestureDetector(
                            onTap: isLoading ? null : _pickImage,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E1E),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: cs.primary.withValues(alpha: 0.5),
                                      width: 2,
                                    ),
                                    image: _imageFile != null
                                        ? DecorationImage(
                                            image: FileImage(_imageFile!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _imageFile == null
                                      ? Icon(
                                          Icons.person_rounded,
                                          size: 60,
                                          color: cs.primary.withValues(alpha: 0.8),
                                        )
                                      : null,
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 18,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 36),

                          // ── Name Field ─────────────────────────────────────
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Full Name',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF999999),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _nameController,
                                enabled: !isLoading,
                                style: const TextStyle(color: Color(0xFFF2F2F2), fontSize: 16),
                                decoration: const InputDecoration(
                                  hintText: 'Enter your name',
                                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Name is required';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // ── Studio Owner Specific Fields ───────────────────
                          if (isStudio) ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Studio Name',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: const Color(0xFF999999),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _studioNameController,
                                  enabled: !isLoading,
                                  style: const TextStyle(color: Color(0xFFF2F2F2), fontSize: 16),
                                  decoration: const InputDecoration(
                                    hintText: 'Enter studio name',
                                    prefixIcon: Icon(Icons.camera_alt_outlined, size: 20),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Studio Name is required';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],

                          // ── Location Field ─────────────────────────────────
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Location / City',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF999999),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _locationController,
                                enabled: !isLoading,
                                style: const TextStyle(color: Color(0xFFF2F2F2), fontSize: 16),
                                decoration: const InputDecoration(
                                  hintText: 'e.g. Mumbai, Delhi, Bangalore',
                                  prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Location is required';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // ── Studio Owner Description Field ─────────────────
                          if (isStudio) ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Studio Description (Optional)',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: const Color(0xFF999999),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _descriptionController,
                                  enabled: !isLoading,
                                  maxLines: 3,
                                  style: const TextStyle(color: Color(0xFFF2F2F2), fontSize: 16),
                                  decoration: const InputDecoration(
                                    hintText: 'Describe your studio, specialities, etc...',
                                    prefixIcon: Padding(
                                      padding: EdgeInsets.only(bottom: 40),
                                      child: Icon(Icons.info_outline_rounded, size: 20),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],

                          // ── Email Field ────────────────────────────────────
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email Address (Optional)',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF999999),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailController,
                                enabled: !isLoading,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: Color(0xFFF2F2F2), fontSize: 16),
                                decoration: const InputDecoration(
                                  hintText: 'email@example.com',
                                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                                ),
                                validator: (value) {
                                  final v = value?.trim() ?? '';
                                  if (v.isNotEmpty &&
                                      !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                                    return 'Enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),

                          // ── Submit Button ──────────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton(
                              onPressed: isLoading ? null : _submit,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('Complete Setup'),
                                        SizedBox(width: 8),
                                        Icon(Icons.check_rounded, size: 18),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientBlob extends StatelessWidget {
  const _GradientBlob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}
