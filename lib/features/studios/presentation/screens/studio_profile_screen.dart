import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/studios_repository.dart';
import '../../data/models/studio_model.dart';
import '../../../bookings/data/repositories/bookings_repository.dart';

class StudioProfileScreen extends ConsumerWidget {
  const StudioProfileScreen({super.key, required this.studioId});
  final String studioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const gold = Color(0xFFE8B86D);
    final studioDetailsAsync = ref.watch(studioDetailsProvider(studioId));

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('Studio Profile'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: studioDetailsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: gold, strokeWidth: 2),
          ),
          error: (err, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.grey, size: 40),
                const SizedBox(height: 12),
                Text('Error loading profile: $err', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(studioDetailsProvider(studioId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (studio) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Profile ───────────────────────────────────────────
                Row(
                  children: [
                    _buildAvatar(studio, 80),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studio.studioName ?? 'Unnamed Studio',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, color: gold, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                studio.location ?? 'No location',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phone_rounded, color: Colors.grey, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                studio.phone ?? 'No phone',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Description
                if (studio.description != null && studio.description!.isNotEmpty) ...[
                  Text(
                    studio.description!,
                    style: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                ],

                // ── Demo Gallery Section ─────────────────────────────────────
                const Text(
                  'Demo Photos & Videos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (studio.demoMedia.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161616),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF222222)),
                    ),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(Icons.photo_library_outlined, color: Colors.grey, size: 36),
                          SizedBox(height: 8),
                          Text(
                            'No demo media uploaded by owner.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          Text(
                            '(Note: Upload folder name must match Studio Name)',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: studio.demoMedia.length,
                    itemBuilder: (context, idx) {
                      final media = studio.demoMedia[idx];
                      final isVideo = media.mediaType == 'VIDEO';
                      return GestureDetector(
                        onTap: () {
                          // Simple modal viewer for photo or video
                          _showMediaViewer(context, media);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(media.thumbnailUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: isVideo
                              ? const Center(
                                  child: CircleAvatar(
                                    backgroundColor: Colors.black54,
                                    radius: 18,
                                    child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 32),

                // ── Plans Section ────────────────────────────────────────────
                const Text(
                  'Pricing & Booking Plans',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (studio.plans.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161616),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF222222)),
                    ),
                    child: const Center(
                      child: Text(
                        'No pricing plans available.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: studio.plans.length,
                    itemBuilder: (context, idx) {
                      final plan = studio.plans[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161616),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF222222)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    plan.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  '₹${plan.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: gold,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              plan.description,
                              style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: gold,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  minimumSize: const Size(double.infinity, 44),
                                ),
                                onPressed: () => _openBookingSheet(context, ref, plan, studio),
                                child: const Text('Book Now'),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMediaViewer(BuildContext context, DemoMediaModel media) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Center(
              child: Hero(
                tag: media.id,
                child: media.mediaType == 'VIDEO'
                    ? const Center(
                        child: Text(
                          'Video playback is supported on booking confirmation.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : InteractiveViewer(
                        child: Image.network(media.secureUrl, fit: BoxFit.contain),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openBookingSheet(BuildContext context, WidgetRef ref, PlanModel plan, StudioModel studio) {
    final dateController = TextEditingController();
    final addressController = TextEditingController();
    DateTime? selectedDate;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    const gold = Color(0xFFE8B86D);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Book Shoot Session',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF222222)),
                    const SizedBox(height: 16),

                    // Shoot Date & Time
                    const Text('Select Date & Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: dateController,
                      readOnly: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Choose Date',
                        prefixIcon: Icon(Icons.calendar_today_rounded, color: gold, size: 20),
                      ),
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: now.add(const Duration(days: 1)),
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365)),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: gold,
                                  onPrimary: Colors.black,
                                  surface: Color(0xFF161616),
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.now(),
                            builder: (context, child) {
                              return Theme(
                                data: ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: gold,
                                    onPrimary: Colors.black,
                                    surface: Color(0xFF161616),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (time != null) {
                            selectedDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                            dateController.text = '${picked.toLocal().toString().split(' ')[0]} ${time.format(ctx)}';
                          }
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Shoot Address
                    const Text('Shoot Venue Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: addressController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Enter complete venue address...',
                        prefixIcon: Icon(Icons.location_on_outlined, color: gold, size: 20),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Pricing breakdown
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Plan Price', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              Text('₹${plan.price.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Advance Pay Needed (25%)', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              Text('₹${(plan.price * 0.25).toStringAsFixed(0)}', style: const TextStyle(color: gold, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(color: Color(0xFF333333), height: 20),
                          const Text(
                            '⚠️ 25% Advance payment is required to confirm booking. Payment collection details will be sent after studio approval.',
                            style: TextStyle(color: gold, fontSize: 11, height: 1.4),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black),
                        onPressed: () async {
                          final address = addressController.text.trim();
                          if (selectedDate == null || address.isEmpty) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(content: Text('Please select shoot date/time and fill venue address.')),
                            );
                            return;
                          }

                          Navigator.pop(ctx); // Close sheet
                          
                          // Show loading dialog
                          showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(child: CircularProgressIndicator(color: gold)),
                          );

                          final success = await ref.read(bookingsListProvider.notifier).createBooking(
                            plan.id,
                            selectedDate!.toIso8601String(),
                            address,
                          );

                          if (context.mounted) Navigator.pop(context); // Pop loader

                          if (success) {
                            showDialog<void>(
                              context: context,
                              builder: (c) {
                                return AlertDialog(
                                  backgroundColor: const Color(0xFF161616),
                                  title: const Text('Booking Placed!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  content: const Text(
                                    'Your shoot session booking has been requested. '
                                    'The studio has been notified and will verify the details. '
                                    'Instructions for the 25% advance payment will be sent once confirmed.',
                                    style: TextStyle(color: Colors.grey, height: 1.4),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(c);
                                      },
                                      child: const Text('OK', style: TextStyle(color: gold)),
                                    ),
                                  ],
                                );
                              },
                            );
                          } else {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(content: Text('Failed to place booking. Try again.')),
                            );
                          }
                        },
                        child: const Text('Confirm Booking Request', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAvatar(StudioModel studio, double size) {
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

  Widget _buildInitials(StudioModel studio, double size) {
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
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
