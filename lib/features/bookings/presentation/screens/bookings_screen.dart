import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/bookings_repository.dart';
import '../../data/models/booking_model.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const gold = Color(0xFFE8B86D);
    final authState = ref.watch(authNotifierProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final isStudio = user?.isStudioOwner ?? false;
    final bookingsAsync = ref.watch(bookingsListProvider);

    return bookingsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: gold, strokeWidth: 2),
          ),
          error: (err, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.grey, size: 40),
                const SizedBox(height: 12),
                Text('Failed to load bookings: $err', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => ref.read(bookingsListProvider.notifier).loadBookings(),
                  child: const Text('Retry', style: TextStyle(color: gold)),
                ),
              ],
            ),
          ),
          data: (bookings) {
            if (bookings.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_note_outlined, color: Colors.grey, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      isStudio ? 'No booking requests received.' : 'No sessions booked yet.',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                final booking = bookings[index];
                return _buildBookingCard(context, ref, booking, isStudio);
              },
            );
          },
        );
  }

  Widget _buildBookingCard(BuildContext context, WidgetRef ref, BookingModel booking, bool isStudio) {
    const gold = Color(0xFFE8B86D);
    final statusColor = _getStatusColor(booking.status);
    final shootDateStr = '${booking.bookingDate.toLocal().toString().split(' ')[0]} at ${TimeOfDay.fromDateTime(booking.bookingDate.toLocal()).format(context)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Title & Status ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isStudio
                      ? 'Client: ${booking.customer?.name ?? 'Anonymous'}'
                      : 'Studio: ${booking.studioOwner?.studioName ?? booking.studioOwner?.name ?? 'Photography Studio'}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  booking.status,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (isStudio)
            Text(
              '📞 Contact: ${booking.customer?.phone ?? 'N/A'}',
              style: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 12),
            ),
          const Divider(color: Color(0xFF2A2A2A), height: 20),

          // ── Shoot Details ──────────────────────────────────────────────────
          _buildInfoRow(Icons.event_outlined, 'Shoot Date', shootDateStr),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.location_on_outlined, 'Venue Address', booking.shootAddress),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.camera_alt_outlined, 'Selected Package', booking.plan?.name ?? 'Custom Package'),

          const Divider(color: Color(0xFF2A2A2A), height: 20),

          // ── Pricing Breakdown ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Package Price', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text('₹${booking.totalPrice.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('25% Advance Paid', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text('₹${booking.advancePaid.toStringAsFixed(0)}', style: const TextStyle(color: gold, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),

          // ── Actions (for Studio Owners on PENDING bookings) ─────────────────
          if (isStudio && booking.status == 'PENDING') ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    onPressed: () => _updateStatus(context, ref, booking.id, 'REJECTED'),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    onPressed: () => _updateStatus(context, ref, booking.id, 'CONFIRMED'),
                    child: const Text('Accept & Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFE8B86D), size: 16),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return const Color(0xFFE8B86D); // Gold
      case 'CONFIRMED':
        return Colors.greenAccent;
      case 'REJECTED':
        return Colors.redAccent;
      case 'COMPLETED':
        return Colors.blueAccent;
      default:
        return Colors.grey;
    }
  }

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, String bookingId, String status) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Show loading indicator
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFE8B86D))),
    );

    final success = await ref.read(bookingsListProvider.notifier).updateBookingStatus(bookingId, status);
    
    if (context.mounted) Navigator.pop(context); // Close loader

    if (success) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Booking request status updated to ${status.toLowerCase()}!')),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Failed to update booking status. Please try again.')),
      );
    }
  }
}
