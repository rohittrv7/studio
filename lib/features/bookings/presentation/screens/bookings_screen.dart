import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/bookings_repository.dart';
import '../../data/models/booking_model.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _payBooking(BookingModel booking) {
    _showPaymentSheet(booking);
  }

  void _showPaymentSheet(BookingModel booking) {
    final upiId = booking.studioOwner?.upiId ?? '';
    final qr = booking.studioOwner?.upiQrCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFE8B86D);

    File? receiptFile;
    String? receiptBase64;
    final utrController = TextEditingController();
    String selectedMethod = 'UPI'; // 'CASH', 'UPI', 'QR_CODE'
    bool isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickReceipt() async {
              try {
                final picker = ImagePicker();
                final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
                if (image != null) {
                  final file = File(image.path);
                  final bytes = await file.readAsBytes();
                  final extension = image.path.split('.').last.toLowerCase();
                  final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
                  final base64 = base64Encode(bytes);
                  setSheetState(() {
                    receiptFile = file;
                    receiptBase64 = 'data:$mimeType;base64,$base64';
                  });
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to select image: $e')),
                );
              }
            }

            Future<void> submit() async {
              final utr = selectedMethod == 'CASH' ? 'CASH' : utrController.text.trim();
              
              if (selectedMethod != 'CASH') {
                if (utr.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter the Transaction ID / UTR')),
                  );
                  return;
                }
                if (receiptBase64 == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please upload a screenshot of the payment receipt')),
                  );
                  return;
                }
              }

              setSheetState(() {
                isSubmitting = true;
              });

              final success = await ref.read(bookingsListProvider.notifier).submitManualPayment(
                bookingId: booking.id,
                transactionRef: utr,
                paymentScreenshot: selectedMethod == 'CASH' ? null : receiptBase64,
                paymentMethod: selectedMethod,
              );

              if (mounted) {
                setSheetState(() {
                  isSubmitting = false;
                });
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment details submitted successfully! Owner will verify.')),
                  );
                  Navigator.pop(context); // Close sheet
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to submit payment details. Please try again.')),
                  );
                }
              }
            }

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[700] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Pay Studio Advance',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select your preferred payment method for the advance amount of ₹${booking.advancePaid.toStringAsFixed(0)}.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('UPI ID')),
                            selected: selectedMethod == 'UPI',
                            selectedColor: gold,
                            labelStyle: TextStyle(
                              color: selectedMethod == 'UPI' ? Colors.black : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (selected) {
                              if (selected) setSheetState(() => selectedMethod = 'UPI');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('QR Code')),
                            selected: selectedMethod == 'QR_CODE',
                            selectedColor: gold,
                            labelStyle: TextStyle(
                              color: selectedMethod == 'QR_CODE' ? Colors.black : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (selected) {
                              if (selected) setSheetState(() => selectedMethod = 'QR_CODE');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Cash')),
                            selected: selectedMethod == 'CASH',
                            selectedColor: gold,
                            labelStyle: TextStyle(
                              color: selectedMethod == 'CASH' ? Colors.black : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (selected) {
                              if (selected) setSheetState(() => selectedMethod = 'CASH');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (selectedMethod == 'CASH') ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE5E5E5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: gold),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'You can pay cash directly at the studio. Click submit to log your Cash payment request.',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else if (selectedMethod == 'UPI') ...[
                      if (upiId.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF7F7F7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE5E5E5)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'STUDIO UPI ID',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    upiId,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, color: gold),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: upiId));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('UPI ID copied to clipboard!'), duration: Duration(seconds: 1)),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ] else ...[
                        Center(
                          child: Text(
                            'UPI ID is not configured by the studio.',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ] else if (selectedMethod == 'QR_CODE') ...[
                      if (qr != null && qr.isNotEmpty) ...[
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300, width: 2),
                            ),
                            child: qr.startsWith('data:image/') && qr.contains('base64,')
                                ? Image.memory(
                                    base64Decode(qr.split('base64,').last),
                                    width: 180,
                                    height: 180,
                                    fit: BoxFit.contain,
                                  )
                                : Image.network(
                                    qr,
                                    width: 180,
                                    height: 180,
                                    fit: BoxFit.contain,
                                    errorBuilder: (c, e, s) => const Icon(Icons.qr_code_rounded, size: 100, color: Colors.black),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ] else ...[
                        Center(
                          child: Text(
                            'QR Code is not configured by the studio.',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],

                    if (selectedMethod != 'CASH') ...[
                      GestureDetector(
                        onTap: pickReceipt,
                        child: Container(
                          width: double.infinity,
                          height: 140,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF7F7F7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: receiptFile != null ? gold : (isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE5E5E5)),
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: receiptFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    receiptFile!,
                                    width: double.infinity,
                                    height: 140,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_photo_alternate_outlined, color: gold, size: 36),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Upload Payment Receipt Screenshot',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Select screenshot image from gallery',
                                      style: TextStyle(color: Colors.grey, fontSize: 11),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: utrController,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        decoration: const InputDecoration(
                          labelText: 'Transaction ID / UTR Number',
                          hintText: 'Enter 12-digit transaction ID or reference',
                          prefixIcon: Icon(Icons.receipt_long_outlined, color: gold),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSubmitting ? null : submit,
                        child: isSubmitting
                            ? const CircularProgressIndicator(color: Colors.black)
                            : Text(
                                selectedMethod == 'CASH' ? 'Log Cash Payment' : 'Submit Payment Reference',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
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

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE8B86D);
    final authState = ref.watch(authNotifierProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final isStudio = user?.isStudioOwner ?? false;
    final bookingsAsync = ref.watch(bookingsListProvider);

    return RefreshIndicator(
      onRefresh: () async {
        return ref.read(bookingsListProvider.notifier).loadBookings();
      },
      color: gold,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFF5F5F5),
      child: bookingsAsync.when(
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
        ),
        data: (bookings) {
          if (bookings.isEmpty) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                alignment: Alignment.center,
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
              ),
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return _buildBookingCard(context, booking, isStudio);
            },
          );
        },
      ),
    );
  }

  Widget _buildBookingCard(BuildContext context, BookingModel booking, bool isStudio) {
    const gold = Color(0xFFE8B86D);
    final statusColor = _getStatusColor(booking.status);
    final shootDateStr = '${booking.bookingDate.toLocal().toString().split(' ')[0]} at ${TimeOfDay.fromDateTime(booking.bookingDate.toLocal()).format(context)}';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showBookingDetails(context, booking, isStudio),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161616) : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E5E5),
          ),
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
                        ? 'Customer: ${booking.customer?.name ?? 'Anonymous'}'
                        : 'Studio: ${booking.studioOwner?.studioName ?? booking.studioOwner?.name ?? 'Photography Studio'}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
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
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            Divider(
              color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E5E5),
              height: 20,
            ),

            // ── Shoot Details ──────────────────────────────────────────────────
            _buildInfoRow(context, Icons.event_outlined, 'Shoot Date', shootDateStr),
            const SizedBox(height: 8),
            _buildInfoRow(context, Icons.location_on_outlined, 'Venue Address', booking.shootAddress),
            const SizedBox(height: 8),
            _buildInfoRow(context, Icons.camera_alt_outlined, 'Selected Package', booking.plan?.name ?? 'Custom Package'),

            Divider(
              color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E5E5),
              height: 20,
            ),

            // ── Pricing Breakdown ──────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Package Price',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${booking.totalPrice.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      booking.isPaid ? 'Advance Paid' : 'Advance Pending',
                      style: TextStyle(
                        color: booking.isPaid ? Colors.greenAccent : Colors.orangeAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('₹${booking.advancePaid.toStringAsFixed(0)}', style: const TextStyle(color: gold, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            Divider(
              color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E5E5),
              height: 20,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  booking.customer?.phone.startsWith('offline_') == true
                      ? 'Source: Direct (Studio)'
                      : 'Source: Online Booking',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (booking.paymentMethod != null)
                  Text(
                    'Method: ${booking.paymentMethod}',
                    style: const TextStyle(
                      color: gold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
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
                      onPressed: () => _updateStatus(context, booking.id, 'REJECTED'),
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
                      onPressed: () => _updateStatus(context, booking.id, 'CONFIRMED'),
                      child: const Text('Accept & Approve'),
                    ),
                  ),
                ],
              ),
            ],

            // ── Actions (for Customers on CONFIRMED unpaid bookings to pay advance) ────
            if (!isStudio && booking.status == 'CONFIRMED' && !booking.isPaid) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(double.infinity, 44),
                ),
                onPressed: () => _payBooking(booking),
                child: const Text('Pay Advance (25%)'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showBookingDetails(BuildContext context, BookingModel booking, bool isStudio) {
    const gold = Color(0xFFE8B86D);
    final statusColor = _getStatusColor(booking.status);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shootDateStr = '${booking.bookingDate.toLocal().toString().split(' ')[0]} at ${TimeOfDay.fromDateTime(booking.bookingDate.toLocal()).format(context)}';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Booking Details',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
              const SizedBox(height: 24),
              
              // Studio/Customer Info
              _buildDetailItem(
                context, 
                isStudio ? 'Customer Name' : 'Studio Name', 
                isStudio 
                    ? (booking.customer?.name ?? 'Anonymous') 
                    : (booking.studioOwner?.studioName ?? booking.studioOwner?.name ?? 'Photography Studio'),
                Icons.person_outline,
              ),
              const SizedBox(height: 16),
              
              _buildDetailItem(
                context, 
                isStudio ? 'Customer Phone' : 'Studio Phone', 
                isStudio 
                    ? (booking.customer?.phone.startsWith('offline_') == true ? 'N/A (Offline Client)' : booking.customer?.phone ?? 'N/A') 
                    : (booking.studioOwner?.phone ?? 'N/A'),
                Icons.phone_outlined,
              ),
              const SizedBox(height: 16),
              _buildDetailItem(
                context, 
                'Booking Type', 
                booking.customer?.phone.startsWith('offline_') == true
                    ? 'Direct Booking (Offline Client)'
                    : 'Online Booking',
                Icons.info_outline,
              ),
              const SizedBox(height: 16),
              if (booking.paymentMethod != null) ...[
                _buildDetailItem(
                  context, 
                  'Payment Method', 
                  booking.paymentMethod!,
                  Icons.payment_outlined,
                ),
                const SizedBox(height: 16),
              ],
              
              _buildDetailItem(
                context, 
                'Shoot Date & Time', 
                shootDateStr, 
                Icons.event_outlined,
              ),
              const SizedBox(height: 16),
              
              _buildDetailItem(
                context, 
                'Venue/Shoot Address', 
                booking.shootAddress, 
                Icons.location_on_outlined,
              ),
              const SizedBox(height: 16),
              
              _buildDetailItem(
                context, 
                'Selected Package', 
                '${booking.plan?.name ?? "Custom Package"}\n${booking.plan?.description ?? ""}', 
                Icons.camera_alt_outlined,
              ),
              const SizedBox(height: 20),
              
              Divider(color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E5E5)),
              const SizedBox(height: 12),
              
              // Pricing Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Price',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${booking.totalPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        booking.isPaid 
                            ? 'Advance Paid' 
                            : (booking.transactionRef != null && booking.transactionRef!.isNotEmpty
                                ? 'Payment Reviewing'
                                : 'Advance Pending'),
                        style: TextStyle(
                          color: booking.isPaid 
                              ? Colors.greenAccent 
                              : (booking.transactionRef != null && booking.transactionRef!.isNotEmpty
                                  ? gold
                                  : Colors.orangeAccent),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${booking.advancePaid.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: gold,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (booking.transactionRef != null && booking.transactionRef!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'UTR: ${booking.transactionRef}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Buttons
              if (isStudio && booking.status == 'PENDING') ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _updateStatus(context, booking.id, 'REJECTED');
                        },
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
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _updateStatus(context, booking.id, 'CONFIRMED');
                        },
                        child: const Text('Accept & Approve'),
                      ),
                    ),
                  ],
                ),
              ] else if (!isStudio && booking.status == 'CONFIRMED' && !booking.isPaid && (booking.transactionRef == null || booking.transactionRef!.isEmpty)) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _payBooking(booking);
                  },
                  child: const Text('Pay Advance (25%)'),
                ),
              ] else ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E5E5),
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(BuildContext context, String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFE8B86D), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFE8B86D), size: 16),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
            ),
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

  Future<void> _updateStatus(BuildContext context, String bookingId, String status) async {
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

class RazorpaySimulationSheet extends StatefulWidget {
  final double amount;
  final String title;
  final VoidCallback onSuccess;

  const RazorpaySimulationSheet({
    super.key,
    required this.amount,
    required this.title,
    required this.onSuccess,
  });

  @override
  State<RazorpaySimulationSheet> createState() => _RazorpaySimulationSheetState();
}

class _RazorpaySimulationSheetState extends State<RazorpaySimulationSheet> with TickerProviderStateMixin {
  int _step = 0; // 0: Select payment method, 1: Processing, 2: Success
  String _selectedMethod = '';

  late final AnimationController _successController;
  late final Animation<double> _checkAnim;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _checkAnim = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _successController.dispose();
    super.dispose();
  }

  void _startPayment(String method) async {
    setState(() {
      _selectedMethod = method;
      _step = 1;
    });

    // Simulate progress steps
    await Future<void>.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      setState(() {
        _step = 2;
      });
      _successController.forward();
    }

    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (mounted) {
      Navigator.of(context).pop();
      widget.onSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const razorpayColor = Color(0xFF1E35E8); // Razorpay Indigo/Blue
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag indicator
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          
          if (_step == 0) ...[
            // STEP 0: Select Method
            Container(
              color: razorpayColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Razorpay Secure Checkout',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '₹${widget.amount.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select Payment Method',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildMethodItem(
              context,
              icon: Icons.credit_card_rounded,
              title: 'Card',
              subtitle: 'Visa, MasterCard, RuPay, Maestro',
              onTap: () => _startPayment('Card'),
            ),
            _buildMethodItem(
              context,
              icon: Icons.account_balance_wallet_rounded,
              title: 'UPI',
              subtitle: 'Google Pay, PhonePe, Paytm, BHIM',
              onTap: () => _startPayment('UPI'),
            ),
            _buildMethodItem(
              context,
              icon: Icons.account_balance_rounded,
              title: 'Netbanking',
              subtitle: 'All Indian Banks available',
              onTap: () => _startPayment('Netbanking'),
            ),
            _buildMethodItem(
              context,
              icon: Icons.wallet_giftcard_rounded,
              title: 'Wallet',
              subtitle: 'Mobikwik, Freecharge, etc.',
              onTap: () => _startPayment('Wallet'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Secured by Razorpay. 100% Safe.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ] else if (_step == 1) ...[
            // STEP 1: Processing
            const SizedBox(height: 40),
            const SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: razorpayColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Processing payment via $_selectedMethod...',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Do not click back button or close the window.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 40),
          ] else ...[
            // STEP 2: Success Checkmark Animation
            const SizedBox(height: 30),
            AnimatedBuilder(
              animation: _checkAnim,
              builder: (context, child) {
                return Transform.scale(
                  scale: _checkAnim.value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Successful!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 8),
            Text(
              'Amount Paid: ₹${widget.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 40),
          ]
        ],
      ),
    );
  }

  Widget _buildMethodItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF1E35E8)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      onTap: onTap,
    );
  }
}
