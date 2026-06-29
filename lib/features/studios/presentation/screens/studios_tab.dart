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
  final _dateTimeController = TextEditingController();
  String? _searchQuery;
  DateTime? _selectedDateTime;

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
    _dateTimeController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        const gold = Color(0xFFE8B86D);
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: gold,
                    onPrimary: Colors.black,
                    surface: Color(0xFF161616),
                    onSurface: Colors.white,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: gold,
                    onPrimary: Colors.white,
                    surface: Color(0xFFF7F7F7),
                    onSurface: Colors.black,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          const gold = Color(0xFFE8B86D);
          return Theme(
            data: isDark
                ? ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: gold,
                      onPrimary: Colors.black,
                      surface: Color(0xFF161616),
                    ),
                  )
                : ThemeData.light().copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: gold,
                      onPrimary: Colors.white,
                      surface: Color(0xFFF7F7F7),
                    ),
                  ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _dateTimeController.text =
              '${pickedDate.toLocal().toString().split(' ')[0]} ${pickedTime.format(context)}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE8B86D);
    final searchQueryObj = StudioSearchQuery(
      location: _searchQuery,
      bookingDate: _selectedDateTime?.toIso8601String(),
    );
    final studiosAsync = ref.watch(studiosListProvider(searchQueryObj));

    return Column(
          children: [
            // ── Search & Availability Bar ────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search Available Studios',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Location field
                  TextFormField(
                    controller: _searchController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter shoot location / address...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: gold, size: 20),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().isEmpty ? null : val.trim();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // Date & Time field
                  TextFormField(
                    controller: _dateTimeController,
                    readOnly: true,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Choose Shoot Date & Time...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                      prefixIcon: const Icon(Icons.calendar_today_rounded, color: gold, size: 20),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      suffixIcon: _dateTimeController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 18),
                              onPressed: () {
                                setState(() {
                                  _dateTimeController.clear();
                                  _selectedDateTime = null;
                                });
                              },
                            )
                          : null,
                    ),
                    onTap: () => _selectDateTime(context),
                  ),
                ],
              ),
            ),

            // ── Studios List ─────────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  return ref.refresh(studiosListProvider(searchQueryObj).future);
                },
                color: gold,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFFF5F5F5),
                child: studiosAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: gold, strokeWidth: 2),
                  ),
                  error: (err, _) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.6,
                      alignment: Alignment.center,
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
                            onPressed: () => ref.invalidate(studiosListProvider(searchQueryObj)),
                            child: const Text('Retry', style: TextStyle(color: gold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (studios) {
                    if (studios.isEmpty) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.6,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.storefront_outlined, color: Colors.grey, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery == null && _selectedDateTime == null
                                    ? 'No studios registered yet.'
                                    : 'No studios found matching your search.',
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      );
                    }


                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
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
