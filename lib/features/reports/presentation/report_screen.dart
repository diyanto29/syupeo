import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'report_mobile_view.dart';
import 'report_tablet_view.dart';

/// Entry-point for the Laporan (Reports) feature.
/// Responsive: switches between mobile & tablet layouts.
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key, this.padding = EdgeInsets.zero});
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return ReportMobileView(padding: padding);
        } else {
          return ReportTabletView(padding: padding);
        }
      },
    );
  }
}
