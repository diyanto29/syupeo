import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/services/notification_service.dart';
import 'package:dpos/features/table_session/presentation/table_session_screen.dart';
import 'package:dpos/features/transaction/data/transaction_repository.dart';
import 'package:dpos/features/menu_management/data/menu_repository.dart';
import 'package:dpos/features/subscription/presentation/providers/fulfillment_orders_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:dpos/core/providers/feature_gate_provider.dart';

final notificationEventProvider = StreamProvider.autoDispose<NotificationEvent>((ref) {
  return NotificationService.instance.onEvent;
});

final notificationManagerProvider = Provider.autoDispose<void>((ref) {
  final bootstrapAsync = ref.watch(homeBootstrapProvider);
  final featureGate = ref.watch(featureGateProvider);
  
  // Listen to events and refresh data
  ref.listen(notificationEventProvider, (previous, next) {
    if (next.hasValue) {
      final event = next.value!;
      if (event.type == NotificationEventType.newOrder) {
        debugPrint('🔄 Refreshing orders due to new order event');
        ref.invalidate(tableSessionOrdersProvider);
        ref.invalidate(confirmedOrdersProvider);
        ref.invalidate(draftOrdersProvider);
      } else if (event.type == NotificationEventType.lowStock) {
        debugPrint('🔄 Refreshing menu due to low stock event');
        ref.invalidate(menuItemsProvider);
      } else if (event.type == NotificationEventType.statusUpdate) {
        debugPrint('🔄 Refreshing fulfillment orders due to status update event');
        ref.invalidate(fulfillmentOrdersProvider);
        ref.invalidate(menuItemsProvider);
      }
    }
  });

  bootstrapAsync.whenData((bootstrap) {
    final outletId = bootstrap.currentOutlet?.id;
    final businessId = bootstrap.business?.id;

    // Gate Realtime Notifications
    if (!featureGate.isEnabled('realtime_notifications')) {
      debugPrint('🚫 Realtime notifications locked for this plan. Skipping subscription.');
      return;
    }

    if (outletId != null) {
      debugPrint('🔔 Subscribing to notifications for outlet: $outletId, business: $businessId');
      NotificationService.instance.subscribeToOutlet(outletId, businessId: businessId);
    }
    
    if (businessId != null) {
      debugPrint('🔔 Subscribing to notifications for business: $businessId');
      final targetPhones = [
        if (bootstrap.business?.phone != null &&
            bootstrap.business!.phone!.trim().isNotEmpty)
          bootstrap.business!.phone!.trim(),
        if (bootstrap.profile?.phone != null &&
            bootstrap.profile!.phone!.trim().isNotEmpty)
          bootstrap.profile!.phone!.trim(),
      ];
      NotificationService.instance.subscribeToBusiness(
        businessId,
        phones: targetPhones,
      );
    }
  });

  ref.onDispose(() {
    final bootstrap = bootstrapAsync.valueOrNull;
    final outletId = bootstrap?.currentOutlet?.id;
    final businessId = bootstrap?.business?.id;

    if (outletId != null) {
      debugPrint('🔕 Unsubscribing from notifications for outlet: $outletId');
      NotificationService.instance.unsubscribeFromOutlet(outletId);
    }

    if (businessId != null) {
      debugPrint('🔕 Unsubscribing from notifications for business: $businessId');
      NotificationService.instance.unsubscribeFromBusiness(businessId);
    }
  });
});
