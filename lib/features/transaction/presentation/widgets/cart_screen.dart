import 'package:dpos/features/transaction/presentation/widgets/cart_panel.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Full-page cart screen (used on mobile).
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: SafeArea(
        child: CartPanel(
          onClose: () => context.pop(),
        ),
      ),
    );
  }
}
