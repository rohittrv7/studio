import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/studios_repository.dart';
import 'studio_profile_screen.dart';

class StudiosTab extends ConsumerStatefulWidget {
  const StudiosTab({super.key});

  @override
  ConsumerState<StudiosTab> createState() => _StudiosTabState();
}

class _StudiosTabState extends ConsumerState<StudiosTab> {
  final _searchController = TextEditingController();
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authNotifierProvider);
      if (authState is AuthAuthenticated) {
        final loc = authState.user.location;
        if (loc != null && loc.isNotEmpty) {
          setState(() {
            _searchController.text = loc;
            _searchQuery = loc;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE8B86D);
    final studiosAsync = ref.watch(studiosListProvider(_searchQuery));

    return Column(
          children: [
            // ── Search Bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextFormField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search studios by location...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search_rounded, color: gold, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = null;
                            });
                          },
                        )
                      : null,
                ),
                onFieldSubmitted: (val) {
                  setState(() {
                    _searchQuery = val.trim().isEmpty ? null : val.trim();
                  });
                },
              ),
            ),

            // ── Studios List ─────────────────────────────────────────────────
            Expanded(
              child: studiosAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: gold, strokeWidth: 2),
                ),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_rounded, color: Colors.grey, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'Error: $err',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => ref.invalidate(studiosListProvider(_searchQuery)),
                        child: const Text('Retry', style: TextStyle(color: gold)),
                      ),
                    ],
                  ),
                ),
                data: (studios) {
                  if (studios.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.storefront_outlined, color: Colors.grey, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery == null
                                ? 'No studios registered yet.'
                                : 'No studios found in "$_searchQuery".',
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: studios.length,
                    itemBuilder: (context, index) {
                      final studio = studios[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF161616)
                              : const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF2E2E2E)
                                : const Color(0xFFE5E5E5),
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => StudioProfileScreen(studioId: studio.id),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Studio Avatar / Photo
                                _buildAvatar(studio, 64),
                                const SizedBox(width: 16),

                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        studio.studioName ?? 'Unnamed Studio',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_rounded, color: gold, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            studio.location ?? 'No location info',
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        studio.description ?? 'No description provided.',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
  }

  Widget _buildAvatar(dynamic studio, double size) {
    final photo = studio.profilePhoto;

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
            errorBuilder: (context, _, __) => _buildInitials(studio, size),
          ),
        );
      }
    }
    return _buildInitials(studio, size);
  }

  Widget _buildInitials(dynamic studio, double size) {
    const gold = Color(0xFFE8B86D);
    final displayName = studio.studioName ?? studio.name;
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
          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S',
          style: const TextStyle(
            color: gold,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
