import 'package:dpos/features/reports/domain/report_models.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

final _currency =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _dateFmt = DateFormat('dd MMM', 'id_ID');
final _dayNameFmt = DateFormat('EEE', 'id_ID');

/// Daily breakdown tab – shows revenue per day with mini bar chart.
class ReportDailyTab extends StatelessWidget {
  const ReportDailyTab({super.key, required this.report});
  final FullReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (report.dailyBreakdown.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 56, color: scheme.outline.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('Belum ada data harian',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.outline)),
          ],
        ),
      );
    }

    final maxRevenue = report.dailyBreakdown
        .map((d) => d.totalRevenue)
        .reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // ── Mini Trend Chart ─────────────────────────────────
        if (report.dailyBreakdown.length > 1) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.show_chart_rounded,
                        size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Tren Revenue Harian',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 120,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: report.dailyBreakdown.map((day) {
                      final height = maxRevenue > 0
                          ? (day.totalRevenue / maxRevenue) * 90
                          : 0.0;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                _formatShort(day.totalRevenue),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 8,
                                  color: scheme.outline,
                                ),
                              ),
                              const SizedBox(height: 3),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                height: height.clamp(4, 90),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      scheme.primary.withValues(alpha: 0.5),
                                      scheme.primary,
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _dateFmt.format(day.date),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 8,
                                  color: scheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Daily Cards ──────────────────────────────────────
        ...report.dailyBreakdown.reversed.map((day) {
          final pct = maxRevenue > 0
              ? (day.totalRevenue / maxRevenue * 100)
              : 0.0;
          final isToday = _isToday(day.date);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isToday
                    ? scheme.primary.withValues(alpha: 0.06)
                    : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: isToday
                    ? Border.all(
                        color: scheme.primary.withValues(alpha: 0.2))
                    : null,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Date badge
                      Container(
                        width: 48,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isToday
                              ? scheme.primary.withValues(alpha: 0.12)
                              : scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              day.date.day.toString(),
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isToday
                                    ? scheme.primary
                                    : scheme.onSurface,
                              ),
                            ),
                            Text(
                              _dayNameFmt.format(day.date),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                color: isToday
                                    ? scheme.primary
                                    : scheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Revenue & stats
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currency.format(day.totalRevenue),
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _MiniChip(
                                  icon: Icons.receipt_long_rounded,
                                  label: '${day.totalOrders} order',
                                ),
                                const SizedBox(width: 8),
                                _MiniChip(
                                  icon: Icons.shopping_bag_rounded,
                                  label: '${day.totalItems} item',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Avg
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Avg',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.outline,
                              fontSize: 9,
                            ),
                          ),
                          Text(
                            _formatCompact(day.avgOrderValue),
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Revenue bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 5,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        isToday ? scheme.primary : scheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static String _formatShort(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}jt';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}rb';
    return value.toStringAsFixed(0);
  }

  static String _formatCompact(double value) {
    if (value >= 1000000) {
      return 'Rp ${(value / 1000000).toStringAsFixed(1)}jt';
    } else if (value >= 1000) {
      return 'Rp ${(value / 1000).toStringAsFixed(0)}rb';
    }
    return _currency.format(value);
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: scheme.outline),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.outline,
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}
