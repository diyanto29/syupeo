import 'package:dpos/features/reports/domain/report_models.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

final _currency =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

/// Payment methods breakdown tab.
class ReportPaymentsTab extends StatelessWidget {
  const ReportPaymentsTab({super.key, required this.report});
  final FullReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (report.revenueByMethod.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payment_outlined,
                size: 56, color: scheme.outline.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('Belum ada data pembayaran',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.outline)),
          ],
        ),
      );
    }

    final total = report.revenueByMethod.values.fold(0.0, (a, b) => a + b);
    final sorted = report.revenueByMethod.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      const Color(0xFF2196F3),
      const Color(0xFF00BFA5),
      const Color(0xFFFF8C00),
      const Color(0xFF9C27B0),
      const Color(0xFF3F51B5),
      const Color(0xFFE91E63),
      const Color(0xFF607D8B),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // ── Donut-style visualization ────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              // Stacked bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: sorted.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final e = entry.value;
                      final fraction = total > 0 ? e.value / total : 0.0;
                      return Expanded(
                        flex: (fraction * 1000).round().clamp(1, 1000),
                        child: Container(
                          color: colors[idx % colors.length],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Total ',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.outline),
                  ),
                  Text(
                    _currency.format(total),
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Method Cards ─────────────────────────────────────
        ...sorted.asMap().entries.map((entry) {
          final idx = entry.key;
          final method = entry.value;
          final pct = total > 0 ? (method.value / total * 100) : 0.0;
          final color = colors[idx % colors.length];

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  // Color indicator
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _methodIcon(method.key),
                      size: 20,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Method info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          method.key,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Progress
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            minHeight: 5,
                            backgroundColor: scheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Amount & percentage
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _currency.format(method.value),
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  IconData _methodIcon(String method) {
    final lower = method.toLowerCase();
    if (lower.contains('cash') || lower.contains('tunai')) {
      return Icons.payments_rounded;
    }
    if (lower.contains('qris')) {
      return Icons.qr_code_rounded;
    }
    if (lower.contains('debit') || lower.contains('credit') || lower.contains('kartu')) {
      return Icons.credit_card_rounded;
    }
    if (lower.contains('transfer') || lower.contains('bank')) {
      return Icons.account_balance_rounded;
    }
    if (lower.contains('ewallet') ||
        lower.contains('gopay') ||
        lower.contains('ovo') ||
        lower.contains('dana')) {
      return Icons.account_balance_wallet_rounded;
    }
    return Icons.payment_rounded;
  }
}
