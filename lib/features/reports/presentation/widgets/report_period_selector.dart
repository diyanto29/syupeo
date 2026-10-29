import 'package:dpos/features/reports/domain/report_models.dart';
import 'package:dpos/features/reports/state/report_providers.dart';
import 'package:flutter/material.dart' hide DateTimeRange;
import 'package:flutter/material.dart' as material show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Period selection widget – works in both full and compact modes.
class ReportPeriodSelector extends ConsumerWidget {
  const ReportPeriodSelector({super.key, this.compact = false});
  final bool compact;

  Future<void> _handlePeriodSelect(
    BuildContext context,
    WidgetRef ref,
    ReportPeriod period,
  ) async {
    if (period == ReportPeriod.custom) {
      final now = DateTime.now();
      final currentCustom = ref.read(customDateRangeProvider);
      
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: now,
        initialDateRange: currentCustom != null
            ? material.DateTimeRange(
                start: currentCustom.start,
                // subtract 1 day since our model's end is exclusive, but date picker uses inclusive dates
                end: currentCustom.end.subtract(const Duration(days: 1)),
              )
            : material.DateTimeRange(
                start: now.subtract(const Duration(days: 7)),
                end: now,
              ),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: Theme.of(context).colorScheme.primary,
                  ),
            ),
            child: child!,
          );
        },
      );

      if (picked != null) {
        // Adjust end date to be inclusive of the selected end day (end of day)
        ref.read(customDateRangeProvider.notifier).state = DateTimeRange(
          start: picked.start,
          end: picked.end.add(const Duration(days: 1)),
        );
        ref.read(selectedReportPeriodProvider.notifier).state = period;
      }
    } else {
      ref.read(selectedReportPeriodProvider.notifier).state = period;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedReportPeriodProvider);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    if (compact) {
      return _buildCompact(context, ref, selected, scheme, theme);
    }
    return _buildFull(context, ref, selected, scheme, theme);
  }

  Widget _buildFull(
    BuildContext context,
    WidgetRef ref,
    ReportPeriod selected,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ReportPeriod.values.map((period) {
            final isActive = period == selected;
            final isCustom = period == ReportPeriod.custom;
            
            String label = period.label;
            if (isActive && isCustom) {
              final customRange = ref.watch(customDateRangeProvider);
              if (customRange != null) {
                final fmt = DateFormat('dd MMM');
                final startStr = fmt.format(customRange.start);
                final endStr = fmt.format(customRange.end.subtract(const Duration(days: 1)));
                label = '$startStr - $endStr';
              }
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: Material(
                  color: isActive
                      ? scheme.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _handlePeriodSelect(context, ref, period),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color:
                              isActive ? scheme.primary : scheme.onSurface,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCompact(
    BuildContext context,
    WidgetRef ref,
    ReportPeriod selected,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: ReportPeriod.values.map((period) {
        final isActive = period == selected;
        final isCustom = period == ReportPeriod.custom;
        
        String label = period.label;
        if (isActive && isCustom) {
          final customRange = ref.watch(customDateRangeProvider);
          if (customRange != null) {
            final fmt = DateFormat('dd MMM yyyy');
            final startStr = fmt.format(customRange.start);
            final endStr = fmt.format(customRange.end.subtract(const Duration(days: 1)));
            label = 'Kustom: $startStr - $endStr';
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: isActive
                ? scheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _handlePeriodSelect(context, ref, period),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? scheme.primary : Colors.transparent,
                        border: Border.all(
                          color: isActive
                              ? scheme.primary
                              : scheme.outline.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          color:
                              isActive ? scheme.primary : scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
