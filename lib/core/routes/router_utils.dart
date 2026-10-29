import 'package:dpos/core/routes/ina_routes_app.dart';
import 'package:go_router/go_router.dart';

void navigateIfNotCurrent(
  String route, {
  Map<String, String> pathParameters = const <String, String>{},
  Map<String, dynamic> queryParameters = const <String, dynamic>{},
  Object? extra,
}) {
  final GoRouter? router = InaRoutesApp.maybeRouter;
  if (router == null) {
    return;
  }

  final String? path = router.state.name;
  if (path != route) {
    router.pushNamed(
      route,
      extra: extra,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );
  }
}
