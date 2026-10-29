import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class InaRoutesApp {
  InaRoutesApp._();

  static final GlobalKey rootAppKey = GlobalKey(debugLabel: 'root-app');

  static GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>(
    debugLabel: 'root',
  );

  static GlobalKey<NavigatorState> shellKey = GlobalKey<NavigatorState>(
    debugLabel: 'shell',
  );

  static BuildContext? get context =>
      rootAppKey.currentContext ?? key.currentContext;

  static BuildContext get requireContext {
    final currentContext = context;
    if (currentContext == null) {
      throw StateError(
        'InaRoutesApp.context belum tersedia. Pastikan app sudah selesai build '
        'sebelum mengakses routing context.',
      );
    }
    return currentContext;
  }

  static GoRouter? get maybeRouter {
    final currentContext = context;
    if (currentContext == null) {
      return null;
    }
    return GoRouter.of(currentContext);
  }

  static GoRouter get requireRouter {
    final router = maybeRouter;
    if (router == null) {
      throw StateError(
        'GoRouter belum tersedia dari InaRoutesApp.context. '
        'Coba panggil setelah frame pertama selesai.',
      );
    }
    return router;
  }

  static String get pathUrl =>
      maybeRouter?.routeInformationProvider.value.uri.path ?? '';

  static List<String> get pathSegments =>
      maybeRouter?.routeInformationProvider.value.uri.pathSegments ?? const [];

  static Map<String, String> get queryParameters =>
      maybeRouter?.routeInformationProvider.value.uri.queryParameters ??
      const {};
}
