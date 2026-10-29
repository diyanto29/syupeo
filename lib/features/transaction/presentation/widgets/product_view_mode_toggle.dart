import 'package:dpos/features/transaction/state/product_view_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Widget toggle untuk berganti antara mode Grid dan List pada katalog produk kasir.
class ProductViewModeToggle extends ConsumerWidget {
  const ProductViewModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(productViewModeProvider);

    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeButton(
            icon: Icons.grid_view_rounded,
            tooltip: 'Tampilan Grid (Kotak)',
            isSelected: mode.isGrid,
            onTap: () {
              if (!mode.isGrid) {
                HapticFeedback.selectionClick();
                ref.read(productViewModeProvider.notifier).setMode(ProductViewMode.grid);
              }
            },
          ),
          const SizedBox(width: 3),
          _ModeButton(
            icon: Icons.view_list_rounded,
            tooltip: 'Tampilan List (Daftar)',
            isSelected: mode.isList,
            onTap: () {
              if (!mode.isList) {
                HapticFeedback.selectionClick();
                ref.read(productViewModeProvider.notifier).setMode(ProductViewMode.list);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            width: 34,
            height: 32,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}
