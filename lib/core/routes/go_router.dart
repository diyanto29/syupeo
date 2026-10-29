import 'dart:developer';

import 'package:dpos/core/routes/ina_routes_app.dart';
import 'package:go_router/go_router.dart';

extension GoRouterEx on GoRouter {
  void popUntil(String path) {
    final router = InaRoutesApp.maybeRouter;
    if (router == null) {
      return;
    }

    log(router.routerDelegate.currentConfiguration.matches.toString());
    log(canPop().toString());

    for (final element in router.routerDelegate.currentConfiguration.matches) {
      if (element.matchedLocation == path) {
        pop();
      }
    }
  }

  Future<T?> popUntilAndReplaceNamed<T extends Object>({
    required String targetRoute,
    required String prevTargetRoute,
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) {
    if (canPop()) {
      popUntil(prevTargetRoute);
    }

    return replaceNamed(
      targetRoute,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      extra: extra,
    );
  }
}
