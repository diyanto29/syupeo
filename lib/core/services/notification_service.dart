import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:flutter/foundation.dart';

enum NotificationEventType { newOrder, statusUpdate, lowStock }

class NotificationEvent {
  final NotificationEventType type;
  final Map<String, dynamic> data;
  NotificationEvent({required this.type, required this.data});
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  bool get _isFcmSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  FirebaseMessaging? get _fcm =>
      _isFcmSupported ? FirebaseMessaging.instance : null;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  final _eventController = StreamController<NotificationEvent>.broadcast();
  Stream<NotificationEvent> get onEvent => _eventController.stream;

  RealtimeChannel? _orderChannel;
  RealtimeChannel? _inventoryChannel;
  StreamSubscription? _fcmSubscription;

  Future<void> initialize() async {
    // 1. Request FCM Permissions & Listen (if supported on platform)
    if (_isFcmSupported) {
      try {
        await _fcm?.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        _fcmSubscription =
            FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          _showLocalNotification(message);
          _playNotificationSound();
          _eventController.add(
            NotificationEvent(
              type: NotificationEventType.newOrder,
              data: message.data,
            ),
          );
        });
      } catch (e) {
        debugPrint('FCM initialization warning (non-fatal): $e');
      }
    }

    // 2. Initialize Local Notifications (for foreground)
    try {
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(),
      );
      await _localNotifications.initialize(
        settings: initializationSettings,
      );
    } catch (e) {
      debugPrint('Local notifications initialization warning: $e');
    }
  }

  Future<void> subscribeToOutlet(String outletId, {String? businessId}) async {
    // Subscribe to FCM topic
    if (_isFcmSupported) {
      try {
        await _fcm?.subscribeToTopic('outlet_$outletId');
      } catch (e) {
        debugPrint('FCM subscribe warning: $e');
      }
    }

    // Subscribe to Supabase Realtime
    _setupSupabaseRealtime(outletId, businessId: businessId);
  }

  Future<void> subscribeToBusiness(String businessId) async {
    // Subscribe to FCM topic
    if (_isFcmSupported) {
      try {
        await _fcm?.subscribeToTopic('business_$businessId');
      } catch (e) {
        debugPrint('FCM subscribe warning: $e');
      }
    }

    // Subscribe to Inventory Realtime
    _setupInventoryRealtime(businessId);
  }

  Future<void> unsubscribeFromOutlet(String outletId) async {
    if (_isFcmSupported) {
      try {
        await _fcm?.unsubscribeFromTopic('outlet_$outletId');
      } catch (e) {
        debugPrint('FCM unsubscribe warning: $e');
      }
    }
    await _orderChannel?.unsubscribe();
  }

  Future<void> unsubscribeFromBusiness(String businessId) async {
    if (_isFcmSupported) {
      try {
        await _fcm?.unsubscribeFromTopic('business_$businessId');
      } catch (e) {
        debugPrint('FCM unsubscribe warning: $e');
      }
    }
    await _inventoryChannel?.unsubscribe();
  }

  void _setupSupabaseRealtime(String outletId, {String? businessId}) {
    _orderChannel?.unsubscribe();
    
    final channelName = businessId != null
        ? 'public:orders:business_id=eq.$businessId'
        : 'public:orders:outlet_id=eq.$outletId';

    _orderChannel = SupabaseService.client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            final newOrder = payload.newRecord;
            if (businessId != null && newOrder['business_id'] != null) {
              if (newOrder['business_id'] == businessId) {
                _handleNewOrderRealtime(newOrder);
              }
            } else if (newOrder['outlet_id'] == outletId) {
              _handleNewOrderRealtime(newOrder);
            }
          },
        )
        .subscribe();
  }

  void _handleNewOrderRealtime(Map<String, dynamic> record) {
    final invoice = record['invoice_number'] ?? 'Baru';
    final table = record['table_number'] != null ? 'Meja ${record['table_number']}' : 'Tanpa Meja';
    
    // Show local notification immediately
    _showInstantAlert(
      title: 'Pesanan Masuk! ($invoice)',
      body: 'Pesanan baru terdeteksi di $table',
    );
    _playNotificationSound();
    
    _eventController.add(NotificationEvent(
      type: NotificationEventType.newOrder,
      data: record,
    ));
  }

  void _setupInventoryRealtime(String businessId) {
    _inventoryChannel?.unsubscribe();

    _inventoryChannel = SupabaseService.client
        .channel('public:menu_items:business_id=eq.$businessId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'menu_items',
          callback: (payload) {
            final newItem = payload.newRecord;
            final oldItem = payload.oldRecord;
            _handleStockUpdateRealtime(oldItem, newItem);
          },
        )
        .subscribe();
  }

  void _handleStockUpdateRealtime(
    Map<String, dynamic> oldRecord,
    Map<String, dynamic> newRecord,
  ) {
    final bool trackStock = newRecord['track_stock_quantity'] ?? false;
    if (!trackStock) return;

    final int newStock = (newRecord['stock_quantity'] as num? ?? 0).toInt();
    final int oldStock = (oldRecord['stock_quantity'] as num? ?? 0).toInt();
    final String name = newRecord['name'] ?? 'Produk';

    // Threshold for low stock notification
    const threshold = 5;

    // Only notify if stock decreases and crosses the threshold or hits zero
    if (newStock < oldStock && newStock <= threshold) {
      String title;
      String body;

      if (newStock == 0) {
        title = 'Stok Habis!';
        body = 'Stok $name sudah habis.';
      } else {
        title = 'Stok Menipis!';
        body = 'Stok $name tersisa $newStock.';
      }

      _showInstantAlert(title: title, body: body);
      _playNotificationSound();

      _eventController.add(NotificationEvent(
        type: NotificationEventType.lowStock,
        data: newRecord,
      ));
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      const notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'orders_channel',
          'Pesanan Baru',
          channelDescription:
              'Notifikasi untuk pesanan masuk dari waiter/self-order',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          ticker: 'ticker',
        ),
        iOS: DarwinNotificationDetails(),
      );

      await _localNotifications.show(
        id: message.hashCode,
        title: message.notification?.title,
        body: message.notification?.body,
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint('Local notification display warning: $e');
    }
  }

  Future<void> _showInstantAlert(
      {required String title, required String body}) async {
    try {
      const notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'realtime_orders',
          'Realtime Orders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(),
      );

      await _localNotifications.show(
        id: DateTime.now().millisecond,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint('Instant alert display warning: $e');
    }
  }

  Future<void> _playNotificationSound() async {
    try {
      // If you have a custom sound, uncomment this:
      // await _audioPlayer.play(AssetSource('icons/notification_bell.mp3'));
      
      // For now, we rely on the default notification sound from local_notifications
      // which is already triggered by _showLocalNotification or _showInstantAlert
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  void dispose() {
    _eventController.close();
    _fcmSubscription?.cancel();
    _orderChannel?.unsubscribe();
    _inventoryChannel?.unsubscribe();
    _audioPlayer.dispose();
  }
}
