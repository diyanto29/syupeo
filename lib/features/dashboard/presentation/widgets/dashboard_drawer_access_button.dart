import 'package:flutter/material.dart';

class DashboardDrawerAccessButton extends StatelessWidget {
  const DashboardDrawerAccessButton({super.key, this.tooltip = 'Buka menu'});

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Scaffold.maybeOf(context)?.openDrawer(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.menu_rounded,
              color: scheme.onSurface.withValues(alpha: 0.84),
            ),
          ),
        ),
      ),
    );
  }
}
