import 'dart:async';
import 'package:dpos/core/routes/router_provider.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/pos_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dpos/core/services/ad_interstitial_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:dpos/core/services/notification_service.dart';
import 'package:dpos/core/services/in_app_update_service.dart';
import 'package:dpos/core/services/local_database_service.dart';
import 'package:dpos/core/services/offline_sync_service.dart';
import 'package:dpos/features/notifications/presentation/providers/notification_provider.dart';

import 'package:flutter/foundation.dart';
import 'dart:io' show Platform, Process;

void _registerWindowsDeepLinkProtocol() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    try {
      final exePath = Platform.resolvedExecutable;
      const scheme = 'online.mudahkan.dpos';
      Process.runSync('reg', [
        'add',
        'HKCU\\Software\\Classes\\$scheme',
        '/ve',
        '/d',
        'URL:$scheme Protocol',
        '/f',
      ]);
      Process.runSync('reg', [
        'add',
        'HKCU\\Software\\Classes\\$scheme',
        '/v',
        'URL Protocol',
        '/d',
        '',
        '/f',
      ]);
      Process.runSync('reg', [
        'add',
        'HKCU\\Software\\Classes\\$scheme\\shell\\open\\command',
        '/ve',
        '/d',
        '"$exePath" "%1"',
        '/f',
      ]);
      debugPrint('Registered Windows deep link protocol: $scheme');
    } catch (e) {
      debugPrint('Warning: Failed to register Windows protocol: $e');
    }
  }
}

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();    
    debugPrint('Starting App Initialization...');
    _registerWindowsDeepLinkProtocol();

    try {
      debugPrint('Initializing Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Firebase initialization warning: $e');
    }
    
    // Initialize Notifications
    await NotificationService.instance.initialize();
    
    debugPrint('Initializing Local Database...');
    await LocalDatabaseService.instance.initialize();

    debugPrint('Initializing Supabase...');
    await SupabaseService.initialize();
    OfflineSyncService.instance.initialize(null);
    
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (isMobile) {
      unawaited(
        MobileAds.instance.initialize().then((_) {
          MobileAds.instance.updateRequestConfiguration(
            RequestConfiguration(
              testDeviceIds: [
                'A594C7FE6D077EAF071717E96F673800',
              ],
            ),
          );
          AdInterstitialService.loadAd();
        }).catchError((e) {
          debugPrint('MobileAds initialization error (non-fatal): $e');
        }),
      );
    }
    
    debugPrint('Initializing Date Formatting...');
    await initializeDateFormatting('id');

    debugPrint('App Initialized Successfully');
    runApp(const ProviderScope(child: MyRootApp()));
  } catch (e, stack) {
    debugPrint('ERROR DURING INIT: $e');
    debugPrint(stack.toString());
    // Fallback app to show error on screen
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SelectableText('Error during initialization: $e\n\n$stack'),
        ),
      ),
    ));
  }
}

class MyRootApp extends ConsumerStatefulWidget {
  const MyRootApp({super.key});

  @override
  ConsumerState<MyRootApp> createState() => _MyRootAppState();
}

class _MyRootAppState extends ConsumerState<MyRootApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      InAppUpdateService.checkForImmediateUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Activate Notification Manager
    ref.watch(notificationManagerProvider);

    final router = ref.watch(appRouterProvider);

    return App(router: router);
  }
}
