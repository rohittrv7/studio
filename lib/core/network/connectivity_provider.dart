import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Connectivity status enum
// ---------------------------------------------------------------------------

/// Represents the network connectivity state of the device.
enum ConnectivityStatus {
  /// At least one network interface (wifi, mobile, ethernet, etc.) is active.
  online,

  /// No network interface is available.
  offline,
}

// ---------------------------------------------------------------------------
// Raw stream provider — current ConnectivityStatus from the OS
// ---------------------------------------------------------------------------

/// A [StreamProvider] that emits [ConnectivityStatus] changes.
///
/// The stream is backed by [Connectivity.onConnectivityChanged].  Each emission
/// is a `List<ConnectivityResult>` (connectivity_plus ≥ 5.x); the device is
/// considered online if ANY result is NOT [ConnectivityResult.none].
///
/// Initial state is obtained synchronously by listening to the first event;
/// the stream is designed to never complete (it only completes when the widget
/// tree is torn down), so [AsyncValue.loading] lasts only until the first OS
/// callback arrives.
final connectivityProvider = StreamProvider<ConnectivityStatus>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none)
        ? ConnectivityStatus.online
        : ConnectivityStatus.offline,
  );
});

// ---------------------------------------------------------------------------
// Transition-aware notifier — tracks wasOffline to detect reconnect events
// ---------------------------------------------------------------------------

/// State that pairs the current [ConnectivityStatus] with a [wasOffline] flag.
///
/// [wasOffline] is set to `true` as soon as connectivity drops to
/// [ConnectivityStatus.offline] and stays `true` until the app successfully
/// transitions back to [ConnectivityStatus.online].  Consumers can use this
/// flag to trigger a background refresh exactly once per reconnection.
class ConnectivityState {
  const ConnectivityState({
    required this.status,
    this.wasOffline = false,
  });

  /// Current network reachability.
  final ConnectivityStatus status;

  /// Whether the device was offline at any point prior to the current state.
  ///
  /// Stays `true` from the moment connectivity is lost until the first
  /// successful transition back to [ConnectivityStatus.online].
  final bool wasOffline;

  bool get isOffline => status == ConnectivityStatus.offline;
  bool get isOnline => status == ConnectivityStatus.online;

  /// `true` when the device just came back online after being offline —
  /// the trigger condition for a background refresh.
  bool get justReconnected => wasOffline && isOnline;

  ConnectivityState copyWith({
    ConnectivityStatus? status,
    bool? wasOffline,
  }) {
    return ConnectivityState(
      status: status ?? this.status,
      wasOffline: wasOffline ?? this.wasOffline,
    );
  }

  @override
  String toString() =>
      'ConnectivityState(status: $status, wasOffline: $wasOffline)';
}

// ---------------------------------------------------------------------------
// ConnectivityNotifier
// ---------------------------------------------------------------------------

/// A [Notifier] that builds [ConnectivityState] on top of [connectivityProvider].
///
/// Tracks the offline→online transition so that widgets can call
/// [ref.listen] and react when [ConnectivityState.justReconnected] becomes
/// `true`.
class ConnectivityNotifier extends Notifier<ConnectivityState> {
  @override
  ConnectivityState build() {
    // Subscribe to the raw stream and update state on each emission.
    ref.listen<AsyncValue<ConnectivityStatus>>(
      connectivityProvider,
      (previous, next) {
        next.whenData(_handleStatusChange);
      },
    );

    // Initial state — assume online until the first OS event arrives.
    return const ConnectivityState(status: ConnectivityStatus.online);
  }

  void _handleStatusChange(ConnectivityStatus newStatus) {
    final current = state;

    if (newStatus == ConnectivityStatus.offline) {
      // Mark device as offline and remember that it was offline.
      state = const ConnectivityState(
        status: ConnectivityStatus.offline,
        wasOffline: true,
      );
    } else {
      // Coming back online — preserve wasOffline flag so consumers see
      // justReconnected == true on this transition.
      state = ConnectivityState(
        status: ConnectivityStatus.online,
        wasOffline: current.wasOffline,
      );
    }
  }

  /// Resets the [ConnectivityState.wasOffline] flag after a background refresh
  /// has been triggered, so the flag doesn't fire again until the next outage.
  void acknowledgeReconnect() {
    state = state.copyWith(wasOffline: false);
  }
}

/// Provider for [ConnectivityNotifier] / [ConnectivityState].
///
/// Usage:
/// ```dart
/// // Watch for offline banner
/// final connState = ref.watch(connectivityStatusProvider);
///
/// // Listen for reconnect and trigger background refresh
/// ref.listen<ConnectivityState>(connectivityStatusProvider, (prev, next) {
///   if (next.justReconnected) {
///     ref.invalidate(galleryListProvider);
///     ref.read(connectivityStatusProvider.notifier).acknowledgeReconnect();
///   }
/// });
/// ```
final connectivityStatusProvider =
    NotifierProvider<ConnectivityNotifier, ConnectivityState>(
  ConnectivityNotifier.new,
);
