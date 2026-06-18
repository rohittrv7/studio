import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/connectivity_provider.dart';

/// A slim, non-blocking banner that appears at the top of the screen when
/// the device loses internet connectivity.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  static const double _bannerHeight = 34.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connAsync = ref.watch(connectivityProvider);
    final isOffline = connAsync.maybeWhen(
      data: (status) => status == ConnectivityStatus.offline,
      orElse: () => false,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: isOffline ? _bannerHeight : 0.0,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: Color(0xFF2A2000),
      ),
      child: isOffline
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8B86D),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Offline — viewing cached data',
                  style: TextStyle(
                    color: Color(0xFFE8B86D),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}
