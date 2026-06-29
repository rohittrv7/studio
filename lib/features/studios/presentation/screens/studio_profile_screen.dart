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
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
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
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
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
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                ],


                // ── Showcase Projects Section ────────────────────────────────
                if (studio.showcaseGalleries.isNotEmpty) ...[
                  Text(
                    'Featured Showcase Projects',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: studio.showcaseGalleries.length,
                      itemBuilder: (context, idx) {
                        final gallery = studio.showcaseGalleries[idx];
                        return GestureDetector(
                          onTap: () {
                            _showShowcaseGalleryDialog(context, gallery);
                          },
                          child: Container(
                            width: 140,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF161616)
                                  : const Color(0xFFF7F7F7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF2D2D2D)
                                    : const Color(0xFFE2E2E2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                    child: gallery.coverUrl.isNotEmpty
                                        ? Image.network(
                                            gallery.coverUrl,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            color: Colors.grey[800],
                                            width: double.infinity,
                                            child: const Icon(Icons.photo_library_outlined, color: Colors.grey),
                                          ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        gallery.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${gallery.mediaCount} items',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 9),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // ── Plans Section ────────────────────────────────────────────
                Text(
                  'Pricing & Booking Plans',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
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
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF161616)
                          : const Color(0xFFF7F7F7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF2E2E2E)
                            : const Color(0xFFE5E5E5),
                      ),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    plan.name,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
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
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            if (plan.duration != null && plan.duration!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.timer_outlined, color: gold, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Duration: ${plan.duration}',
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                            if (plan.deliverables != null && plan.deliverables!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.auto_awesome_outlined, color: gold, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Deliverables: ${plan.deliverables}',
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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

  void _openBookingSheet(BuildContext context, WidgetRef ref, PlanModel plan, StudioModel studio) {
    final dateController = TextEditingController();
    final addressController = TextEditingController();
    DateTime? selectedDate;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    const gold = Color(0xFFE8B86D);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF161616)
          : const Color(0xFFF7F7F7),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
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
                        Text(
                          'Book Shoot Session',
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    Divider(
                      color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E5E5),
                    ),
                    const SizedBox(height: 16),

                    // Shoot Date & Time
                    Text(
                      'Select Date & Time',
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: dateController,
                      readOnly: true,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
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
                              data: isDark ? ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: gold,
                                  onPrimary: Colors.black,
                                  surface: Color(0xFF161616),
                                  onSurface: Colors.white,
                                ),
                              ) : ThemeData.light().copyWith(
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
                        if (picked != null) {
                          if (!ctx.mounted) return;
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.now(),
                            builder: (context, child) {
                              return Theme(
                                data: isDark ? ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: gold,
                                    onPrimary: Colors.black,
                                    surface: Color(0xFF161616),
                                  ),
                                ) : ThemeData.light().copyWith(
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
                          if (time != null) {
                            if (!ctx.mounted) return;
                            selectedDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                            dateController.text = '${picked.toLocal().toString().split(' ')[0]} ${time.format(ctx)}';
                          }
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Shoot Venue Address
                    Text(
                      'Shoot Venue Address',
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: addressController,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
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
                        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEEEEEE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E5E5),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Plan Price',
                                style: TextStyle(
                                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '₹${plan.price.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: Theme.of(ctx).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Advance Pay Needed (25%)',
                                style: TextStyle(
                                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '₹${(plan.price * 0.25).toStringAsFixed(0)}',
                                style: const TextStyle(color: gold, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Divider(
                            color: isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD),
                            height: 20,
                          ),
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

                          if (!context.mounted) return;
                          Navigator.pop(context); // Pop loader

                          if (success) {
                            showDialog<void>(
                              context: context,
                              builder: (c) {
                                return AlertDialog(
                                  backgroundColor: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF161616)
                                      : const Color(0xFFF7F7F7),
                                  title: Text(
                                    'Booking Placed!',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  content: Text(
                                    'Your shoot session booking has been requested. '
                                    'The studio has been notified and will verify the details. '
                                    'Instructions for the 25% advance payment will be sent once confirmed.',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
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

  void _showShowcaseGalleryDialog(BuildContext context, ShowcaseGalleryModel gallery) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  gallery.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 380,
            child: gallery.mediaFiles.isEmpty
                ? const Center(child: Text('No showcase photos in this gallery.', style: TextStyle(color: Colors.grey)))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: gallery.mediaFiles.length,
                    itemBuilder: (context, idx) {
                      final media = gallery.mediaFiles[idx];
                      return GestureDetector(
                        onTap: () {
                          showDialog<void>(
                            context: context,
                            builder: (c) {
                              return _ShowcasePhotoViewer(
                                imageUrl: media.secureUrl,
                              );
                            },
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            media.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, _, __) => Container(
                              color: Colors.grey[800],
                              child: const Icon(Icons.image, color: Colors.grey),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

class _ShowcasePhotoViewer extends StatefulWidget {
  const _ShowcasePhotoViewer({required this.imageUrl});
  final String imageUrl;

  @override
  State<_ShowcasePhotoViewer> createState() => _ShowcasePhotoViewerState();
}

class _ShowcasePhotoViewerState extends State<_ShowcasePhotoViewer> {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails!.localPosition;
      _transformationController.value = Matrix4.identity()
        ..translate(-position.dx * 2, -position.dy * 2)
        ..scale(3.0);
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            Center(
              child: GestureDetector(
                onDoubleTapDown: (details) => _doubleTapDetails = details,
                onDoubleTap: _handleDoubleTap,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  maxScale: 4.0,
                  child: Image.network(widget.imageUrl, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
