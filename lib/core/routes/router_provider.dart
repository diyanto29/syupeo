import 'package:dpos/core/routes/app_router.dart';
import 'package:dpos/core/routes/ina_routes_app.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return AppRouter.getRouter(
    rootKey: InaRoutesApp.key,
    ref: ref, // ✅ sekarang cocok
  );
});
