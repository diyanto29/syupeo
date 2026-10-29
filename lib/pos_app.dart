import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/routes/ina_routes_app.dart';
import 'core/theme/app_theme.dart';

class App extends StatelessWidget {
  final dynamic router;
  const App({super.key, this.router});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,

      builder: (context, child) {
        return MaterialApp.router(
          key: InaRoutesApp.rootAppKey,
          title: 'Mangga POS',
          showSemanticsDebugger: false,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routeInformationProvider: router.routeInformationProvider,
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
        );
      },
    );
  }
}
