import 'package:dpos/features/reports/domain/report_models.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

final _currency =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

/// Products performance tab – top sellers and lowest sellers.
class ReportProductsTab extends StatelessWidget {
  const ReportProductsTab({super.key, required this.report});
  final FullReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (report.topProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 56, color: scheme.outline.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('Belum ada data produk',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.outline)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // ── Top Sellers ──────────────────────────────────────
        _SectionHeader(
          title: 'Produk Terlaris',
          icon: Icons.emoji_events_rounded,
          color: Colors.amber.shade700,
        ),
        const SizedBox(height: 10),
        _ProductRankingCard(
          products: report.topProducts,
          isBest: true,
        ),
        const SizedBox(height: 24),

        // ── Summary Stats ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primary.withValues(alpha: 0.08),
                scheme.primary.withValues(alpha: 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              _MiniStat(
                label: 'Total Produk',
                value: '${report.topProducts.length + report.bottomProducts.length}',
                icon: Icons.inventory_2_rounded,
                color: Colors.blue.shade700,
              ),
              const Spacer(),
              _MiniStat(
                label: 'Total Item',
                value: '${report.totalItems}',
                icon: Icons.shopping_bag_rounded,
                color: Colors.teal.shade700,
              ),
              const Spacer(),
              _MiniStat(
                label: 'Revenue',
                value: _formatCompact(report.totalRevenue),
                icon: Icons.monetization_on_rounded,
                color: Colors.orange.shade700,
              ),
            ],
          ),
        ),

        // ── Low Sellers ──────────────────────────────────────
        if (report.bottomProducts.isNotEmpty &&
            report.bottomProducts.length > 1) ...[
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Perlu Perhatian',
            icon: Icons.warning_amber_rounded,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 4),
          Text(
            'Produk dengan penjualan terendah di periode ini',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.outline),
          ),
          const SizedBox(height: 10),
          _ProductRankingCard(
            products: report.bottomProducts,
            isBest: false,
          ),
        ],
      ],
    );
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

// ── Product Ranking Card ────────────────────────────────────────

class _ProductRankingCard extends StatelessWidget {
  const _ProductRankingCard({
    required this.products,
    required this.isBest,
  });
  final List<ProductPerformance> products;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: products.asMap().entries.map((entry) {
          final index = entry.key;
          final product = entry.value;
          final isTopThree = isBest && index < 3;

          final medalColor = isBest
              ? (index == 0
                  ? Colors.amber.shade700
                  : index == 1
                      ? Colors.blueGrey.shade400
                      : index == 2
                          ? Colors.brown.shade400
                          : scheme.outline)
              : Colors.red.shade300;

          return Padding(
            padding:
                EdgeInsets.only(bottom: index < products.length - 1 ? 12 : 0),
            child: Row(
              children: [
                // Rank badge
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: medalColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isTopThree
                      ? Icon(Icons.emoji_events_rounded,
                          size: 16, color: medalColor)
                      : Text(
                          '${index + 1}',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: medalColor,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                // Product info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${product.qtySold} terjual',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.outline,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Avg ${_currency.format(product.avgPrice)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Revenue
                Text(
                  _currency.format(product.revenue),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Mini Stat ───────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        Text(value,
            style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface)),
        const SizedBox(height: 2),
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: scheme.outline, fontSize: 10)),
      ],
    );
  }
}

// ── Section Header ──────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });
  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
