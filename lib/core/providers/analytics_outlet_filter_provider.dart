import 'package:dpos/core/domain/app_enums.dart';
import 'package:dpos/core/domain/bootstrap_models.dart';
import 'package:dpos/core/domain/outlet_models.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider untuk filter outlet di Dashboard Analitik & Laporan Penjualan.
/// - `null`: Menampilkan "Semua Outlet (Konsolidasian)"
/// - `String`: ID outlet spesifik
final selectedAnalyticsOutletIdProvider = StateProvider<String?>((ref) => null);

/// Selector widget untuk memilih outlet atau "Semua Outlet".
class AnalyticsOutletFilterSelector extends ConsumerWidget {
  const AnalyticsOutletFilterSelector({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(homeBootstrapProvider).value;
    if (bootstrap == null) return const SizedBox.shrink();

    final isOwnerOrAdmin =
        bootstrap.effectiveRole == AppRole.owner ||
        bootstrap.effectiveRole == AppRole.admin;

    // Hanya Owner dan Admin yang memiliki akses selector outlet
    if (!isOwnerOrAdmin || bootstrap.outlets.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedId = ref.watch(selectedAnalyticsOutletIdProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final Outlet? selectedOutlet = selectedId == null
        ? null
        : bootstrap.outlets.cast<Outlet?>().firstWhere(
            (o) => o?.id == selectedId,
            orElse: () => null,
          );

    final isAllOutlets = selectedOutlet == null;
    final label = isAllOutlets
        ? 'Semua Outlet (${bootstrap.outlets.length})'
        : selectedOutlet.name;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            _showOutletPickerSheet(context, ref, bootstrap, selectedId),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: isAllOutlets
                ? scheme.primary.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAllOutlets
                  ? scheme.primary.withValues(alpha: 0.3)
                  : scheme.outlineVariant.withValues(alpha: 0.8),
              width: isAllOutlets ? 1.5 : 1,
            ),
            boxShadow: isAllOutlets
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAllOutlets
                    ? Icons.apartment_rounded
                    : Icons.storefront_rounded,
                size: compact ? 15 : 17,
                color: isAllOutlets ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 130 : 180),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: isAllOutlets
                        ? FontWeight.w800
                        : FontWeight.w700,
                    color: isAllOutlets ? scheme.primary : scheme.onSurface,
                    fontSize: compact ? 11.5 : 12.5,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: compact ? 16 : 18,
                color: isAllOutlets ? scheme.primary : scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOutletPickerSheet(
    BuildContext context,
    WidgetRef ref,
    OwnerBootstrap bootstrap,
    String? currentSelectedId,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.filter_alt_rounded,
                          color: scheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filter Lingkup Data Outlet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pilih cabang atau konsolidasi seluruh outlet',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Options list
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      // OPSI 1: SEMUA OUTLET (KONSOLIDASI)
                      _buildOutletTile(
                        context: sheetContext,
                        title: 'Semua Outlet (Konsolidasi)',
                        subtitle:
                            'Gabungan total data ${bootstrap.outlets.length} outlet Anda',
                        icon: Icons.apartment_rounded,
                        isSelected: currentSelectedId == null,
                        colorScheme: scheme,
                        onTap: () {
                          ref
                                  .read(
                                    selectedAnalyticsOutletIdProvider.notifier,
                                  )
                                  .state =
                              null;
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        child: Divider(height: 1),
                      ),
                      // OPSI PER OUTLET
                      ...bootstrap.outlets.map((outlet) {
                        final isSelected = currentSelectedId == outlet.id;
                        final address = outlet.address?.trim() ?? '';
                        final subtitle = address.isNotEmpty
                            ? address
                            : 'Cabang operasional';

                        return _buildOutletTile(
                          context: sheetContext,
                          title: outlet.name,
                          subtitle: subtitle,
                          icon: Icons.storefront_rounded,
                          isSelected: isSelected,
                          colorScheme: scheme,
                          onTap: () {
                            ref
                                .read(
                                  selectedAnalyticsOutletIdProvider.notifier,
                                )
                                .state = outlet
                                .id;
                            Navigator.of(sheetContext).pop();
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOutletTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.06)
            : Colors.transparent,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.12)
                    : colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: colorScheme.primary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
