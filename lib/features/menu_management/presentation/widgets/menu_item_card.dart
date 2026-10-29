import 'package:flutter/material.dart';

import '../../domain/menu_models.dart';

class MenuItemCard extends StatelessWidget {
  const MenuItemCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onToggleStock,
    required this.canManage,
  });

  final MenuItem item;
  final VoidCallback onTap;
  final VoidCallback onToggleStock;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final categoryIcon = _categoryIconForVisualIndex(item.categoryVisualIndex);
    final statusColor = item.isSellable ? Colors.green : Colors.red;
    final statusBackground = statusColor.withValues(alpha: 0.1);

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(categoryIcon, color: scheme.primary, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rp ${item.price.toStringAsFixed(0)} / ${item.displayUnit}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusBackground,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.stockStatusLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: statusColor.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.categoryName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.54),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: canManage ? onToggleStock : null,
                icon: Icon(
                  item.isSellable
                      ? Icons.check_circle_rounded
                      : Icons.remove_circle_outline_rounded,
                  color: item.isSellable ? Colors.green : Colors.grey,
                ),
                tooltip: 'Toggle Ketersediaan Jual',
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  IconData _categoryIconForVisualIndex(int? visualIndex) {
    switch ((visualIndex ?? 0) % 4) {
      case 0:
        return Icons.restaurant_rounded;
      case 1:
        return Icons.local_drink_rounded;
      case 2:
        return Icons.fastfood_rounded;
      case 3:
        return Icons.cake_rounded;
    }
    return Icons.inventory_2_rounded;
  }
}
