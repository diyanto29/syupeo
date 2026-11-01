import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/core/providers/feature_gate_provider.dart';
import 'package:dpos/core/widgets/pro_feature_dialog.dart';
import 'cash_flow_mobile_view.dart';
import 'cash_flow_tablet_view.dart';

import 'package:dpos/core/widgets/app_tablet_nav.dart';

class CashFlowScreen extends ConsumerWidget {
  final EdgeInsets padding;
  const CashFlowScreen({super.key, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureGate = ref.watch(featureGateProvider);
    final isAllowed = featureGate.isEnabled('cash_flow');

    if (!isAllowed) {
      final width = MediaQuery.sizeOf(context).width;
      final isTablet = width >= 760;
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        drawer: const AppOwnerDrawer(),
        appBar: isTablet
            ? const AppTabletHeader(
                title: Text('Arus Kas & Shift Kasir'),
                badge: AppTabletBadge(label: 'Syupeo'),
              )
            : null,
        body: Center(
          child: ProFeatureDialog(
            featureName: 'Arus Kas & Shift Kasir',
            description:
                'Fitur Manajemen Arus Kas & Shift Kasir membantu Anda mengontrol kas laci kasir, mencegah kecurangan, dan merekonsiliasi uang fisik toko secara otomatis.',
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return CashFlowMobileView(padding: padding);
        } else {
          return CashFlowTabletView(padding: padding);
        }
      },
    );
  }
}
