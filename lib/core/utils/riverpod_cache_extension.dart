import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Extension to allow AutoDispose Riverpod providers to keep their state
/// in memory for a specified duration after they are unmounted.
///
/// This prevents redundant network re-fetching when users switch back and forth
/// between dashboard, reports, cash flow, and POS tabs.
extension RiverpodCacheExtension on AutoDisposeRef<Object?> {
  void cacheFor(Duration duration) {
    final link = keepAlive();
    final timer = Timer(duration, () => link.close());
    onDispose(() => timer.cancel());
  }
}
