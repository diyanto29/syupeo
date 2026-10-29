import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_mobile_view.dart';
import 'settings_tablet_view.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return SettingsMobileView(padding: padding);
        } else {
          return SettingsTabletView(padding: padding);
        }
      },
    );
  }
}
