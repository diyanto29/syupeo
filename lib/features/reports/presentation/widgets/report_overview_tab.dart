import 'package:dpos/features/reports/domain/report_models.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

final _currency =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

/// Overview tab – hero revenue, KPI cards, hourly chart, and order source breakdown.
class ReportOverviewTab extends StatelessWidget {
  const ReportOverviewTab({super.key, required this.report, this.onRefresh});
  final FullReport report;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // ── Hero Revenue Card ────────────────────────────────
        _RevenueHeroCard(report: report, onRefresh: onRefresh),
        const SizedBox(height: 14),

        // ── Profit & Cash Expense KPIs ──────────────────────
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Laba Bersih',
                value: _formatCompact(report.netProfit),
                color: report.netProfit >= 0 ? const Color(0xFF00C853) : Colors.red,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                icon: Icons.outbox_rounded,
                label: 'Beban Kas',
                value: _formatCompact(report.totalExpenses),
                color: Colors.amber.shade800,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                icon: Icons.inventory_2_outlined,
                label: 'Modal (HPP)',
                value: _formatCompact(report.totalCogs),
                color: Colors.indigo.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── P&L Breakdown Card ──────────────────────────────
        _ProfitAndLossCard(report: report),
        const SizedBox(height: 20),

        // ── KPI Row ─────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: Icons.receipt_long_rounded,
                label: 'Total Order',
                value: report.totalOrders.toString(),
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                icon: Icons.shopping_bag_rounded,
                label: 'Total Item',
                value: report.totalItems.toString(),
                color: Colors.teal.shade700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                icon: Icons.trending_up_rounded,
                label: 'Rata-rata',
                value: _formatCompact(report.avgOrderValue),
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Secondary KPIs ──────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: Icons.cancel_outlined,
                label: 'Batal',
                value: '${report.cancelledOrders} (${_formatCompact(report.cancelledRevenue)})',
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                icon: Icons.replay_rounded,
                label: 'Refund',
                value: '${report.refundedOrders} (${_formatCompact(report.refundedRevenue)})',
                color: Colors.purple.shade600,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                icon: Icons.discount_rounded,
                label: 'Diskon',
                value: _formatCompact(report.totalDiscount),
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Outlet Highlights ────────────────────────────────
        if (report.outletPerformances.length > 1) ...[
          _SectionHeader(
            title: 'Performa Cabang / Outlet',
            icon: Icons.apartment_rounded,
          ),
          const SizedBox(height: 8),
          _OutletHighlightsCard(outlets: report.outletPerformances),
          const SizedBox(height: 20),
        ],

        // ── Hourly Sales ─────────────────────────────────────
        if (report.hourlySales.isNotEmpty) ...[
          _SectionHeader(
            title: 'Tren Penjualan Per Jam',
            icon: Icons.access_time_rounded,
          ),
          const SizedBox(height: 8),
          _HourlyBarChart(hourly: report.hourlySales),
          const SizedBox(height: 20),
        ],

        // ── Order Sources ────────────────────────────────────
        if (report.ordersBySource.isNotEmpty) ...[
          _SectionHeader(
            title: 'Sumber Pesanan',
            icon: Icons.source_rounded,
          ),
          const SizedBox(height: 8),
          _OrderSourcesCard(
              sources: report.ordersBySource, total: report.totalOrders),
          const SizedBox(height: 20),
        ],

        // ── Employee Highlights ──────────────────────────────
        if (report.cashierPerformances.isNotEmpty ||
            report.waiterPerformances.isNotEmpty) ...[
          _SectionHeader(
            title: 'Performa Karyawan',
            icon: Icons.groups_rounded,
          ),
          const SizedBox(height: 8),
          _EmployeeHighlightsCard(report: report),
          const SizedBox(height: 20),
        ],

        // ── Refund Details ──────────────────────────────────
        if (report.refundedOrdersList.isNotEmpty) ...[
          _SectionHeader(
            title: 'Rincian Refund',
            icon: Icons.replay_rounded,
          ),
          const SizedBox(height: 10),
          _RefundDetailsCard(orders: report.refundedOrdersList),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  static String _formatCompact(double value) {
    final absVal = value.abs();
    final sign = value < 0 ? '-' : '';
    if (absVal >= 1000000) {
      return '${sign}Rp ${(absVal / 1000000).toStringAsFixed(1)}jt';
    } else if (absVal >= 1000) {
      return '${sign}Rp ${(absVal / 1000).toStringAsFixed(0)}rb';
    }
    return _currency.format(value);
  }
}

// ── Revenue Hero Card ─────────────────────────────────────────────

class _RevenueHeroCard extends StatelessWidget {
  const _RevenueHeroCard({required this.report, this.onRefresh});
  final FullReport report;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final netProfit = report.netProfit;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2027).withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.trending_up_rounded,
                    color: Colors.greenAccent, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Total Pendapatan (Omzet)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (onRefresh != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: onRefresh,
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.refresh_rounded,
                          color: Color(0xFF5FE7DB),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${report.period.dayCount} hari',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currency.format(report.totalRevenue),
            style: GoogleFonts.manrope(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          // Divider
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 14),
          // Pemisah Laba Bersih
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (netProfit >= 0 ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (netProfit >= 0 ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: netProfit >= 0 ? Colors.greenAccent : Colors.redAccent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Estimasi Laba Bersih',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (netProfit >= 0 ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Margin ${report.netProfitMargin.toStringAsFixed(1)}%',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: netProfit >= 0 ? Colors.greenAccent : Colors.redAccent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currency.format(netProfit),
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: netProfit >= 0 ? Colors.white : Colors.redAccent.shade100,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (report.totalCogs > 0 || report.totalExpenses > 0 || report.totalDiscount > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (report.totalCogs > 0)
                  _HeroBadge(
                    icon: Icons.inventory_2_outlined,
                    label: 'Modal: ${ReportOverviewTab._formatCompact(report.totalCogs)}',
                    color: Colors.amberAccent,
                  ),
                if (report.totalExpenses > 0)
                  _HeroBadge(
                    icon: Icons.outbox_rounded,
                    label: 'Beban: ${ReportOverviewTab._formatCompact(report.totalExpenses)}',
                    color: Colors.orangeAccent,
                  ),
                if (report.totalDiscount > 0)
                  _HeroBadge(
                    icon: Icons.discount_outlined,
                    label: 'Diskon: ${ReportOverviewTab._formatCompact(report.totalDiscount)}',
                    color: Colors.greenAccent,
                  ),
                if (report.totalTax > 0)
                  _HeroBadge(
                    icon: Icons.percent_rounded,
                    label: 'Pajak: ${ReportOverviewTab._formatCompact(report.totalTax)}',
                    color: Colors.lightBlueAccent,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          // Mini stats row
          Row(
            children: [
              _HeroMiniStat(label: 'Order', value: '${report.totalOrders}'),
              const SizedBox(width: 16),
              _HeroMiniStat(label: 'Item', value: '${report.totalItems}'),
              const SizedBox(width: 16),
              _HeroMiniStat(
                label: 'Avg',
                value: ReportOverviewTab._formatCompact(report.avgOrderValue),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Profit & Loss Card ───────────────────────────────────────────

class _ProfitAndLossCard extends StatelessWidget {
  const _ProfitAndLossCard({required this.report});
  final FullReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  size: 20,
                  color: Color(0xFF00C853),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analisis Laba & Pendapatan',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Rincian pemisahan omzet, modal, dan laba bersih',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 1. Pendapatan Penjualan
          _PnLRow(
            icon: Icons.add_circle_outline_rounded,
            iconColor: Colors.blue.shade700,
            label: 'Pendapatan Penjualan (Net)',
            value: _currency.format(report.netRevenue),
            isPrimary: true,
          ),
          const SizedBox(height: 10),
          // 2. Modal HPP
          _PnLRow(
            icon: Icons.remove_circle_outline_rounded,
            iconColor: Colors.amber.shade800,
            label: 'Harga Pokok Penjualan (HPP / Modal)',
            value: '- ${_currency.format(report.totalCogs)}',
            subtitle: report.totalCogs == 0 ? 'Belum ada harga modal menu' : null,
          ),
          const SizedBox(height: 8),
          Divider(color: scheme.outlineVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          // 3. Laba Kotor
          _PnLRow(
            icon: Icons.equalizer_rounded,
            iconColor: Colors.teal.shade700,
            label: 'Laba Kotor (Gross Profit)',
            value: _currency.format(report.grossProfit),
            badge: 'Margin ${report.grossProfitMargin.toStringAsFixed(1)}%',
            badgeColor: Colors.teal,
            isBold: true,
          ),
          const SizedBox(height: 10),
          // 4. Beban Kas Keluar
          _PnLRow(
            icon: Icons.remove_circle_outline_rounded,
            iconColor: Colors.red.shade600,
            label: 'Pengeluaran Operasional (Kas Keluar)',
            value: '- ${_currency.format(report.totalExpenses)}',
          ),
          if (report.totalCashInExtra > 0) ...[
            const SizedBox(height: 10),
            _PnLRow(
              icon: Icons.add_circle_outline_rounded,
              iconColor: Colors.indigo.shade600,
              label: 'Pemasukan Kas Non-Sales',
              value: '+ ${_currency.format(report.totalCashInExtra)}',
            ),
          ],
          const SizedBox(height: 12),
          // 5. Final Laba Bersih Highlight Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: report.netProfit >= 0
                  ? const Color(0xFF00C853).withValues(alpha: 0.08)
                  : Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: report.netProfit >= 0
                    ? const Color(0xFF00C853).withValues(alpha: 0.3)
                    : Colors.red.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Laba Bersih (Net Profit)',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: report.netProfit >= 0 ? const Color(0xFF00C853) : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: report.netProfit >= 0
                                  ? const Color(0xFF00C853).withValues(alpha: 0.15)
                                  : Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Margin ${report.netProfitMargin.toStringAsFixed(1)}%',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: report.netProfit >= 0 ? const Color(0xFF00C853) : Colors.red,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currency.format(report.netProfit),
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: report.netProfit >= 0 ? const Color(0xFF00C853) : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PnLRow extends StatelessWidget {
  const _PnLRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.subtitle,
    this.badge,
    this.badgeColor,
    this.isPrimary = false,
    this.isBold = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? subtitle;
  final String? badge;
  final MaterialColor? badgeColor;
  final bool isPrimary;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? Colors.blue).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: badgeColor ?? Colors.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.outline,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold || isPrimary ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HeroMiniStat extends StatelessWidget {
  const _HeroMiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      ],
    );
  }
}

// ── KPI Card ────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style:
                  theme.textTheme.labelSmall?.copyWith(color: scheme.outline)),
        ],
      ),
    );
  }
}

// ── Section Header ──────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Text(title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// ── Hourly Bar Chart ────────────────────────────────────────────

class _HourlyBarChart extends StatelessWidget {
  const _HourlyBarChart({required this.hourly});
  final Map<int, double> hourly;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    if (hourly.isEmpty) return const SizedBox.shrink();

    final maxRevenue = hourly.values.reduce((a, b) => a > b ? a : b);
    final sortedHours = hourly.keys.toList()..sort();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: sortedHours.map((hour) {
            final revenue = hourly[hour] ?? 0;
            final height = maxRevenue > 0 ? (revenue / maxRevenue) * 110 : 0.0;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _formatShort(revenue),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(fontSize: 8, color: scheme.outline),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: height.clamp(4, 110),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary.withValues(alpha: 0.6),
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
                      hour.toString().padLeft(2, '0'),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(fontSize: 9, color: scheme.outline),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  static String _formatShort(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}jt';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}rb';
    return value.toStringAsFixed(0);
  }
}

// ── Order Sources Card ──────────────────────────────────────────

class _OrderSourcesCard extends StatelessWidget {
  const _OrderSourcesCard({required this.sources, required this.total});
  final Map<String, int> sources;
  final int total;

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
        children: sources.entries.map((e) {
          final pct = total > 0 ? (e.value / total * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(e.key,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    Text('${e.value} order',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: scheme.outline)),
                    const SizedBox(width: 8),
                    Text('${pct.toStringAsFixed(1)}%',
                        style: GoogleFonts.manrope(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 5,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(scheme.primary),
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

class _EmployeeHighlightsCard extends StatelessWidget {
  const _EmployeeHighlightsCard({required this.report});
  final FullReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final topCashier = report.cashierPerformances.isNotEmpty
        ? report.cashierPerformances.first
        : null;
    final topWaiter =
        report.waiterPerformances.isNotEmpty ? report.waiterPerformances.first : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          if (topCashier != null)
            _EmployeeHighlightTile(
              role: 'Kasir Terbaik',
              name: topCashier.cashierName,
              stats:
                  '${topCashier.orderCount} order • ${_currency.format(topCashier.totalRevenue)}',
              icon: Icons.badge_rounded,
              color: Colors.blue.shade700,
            ),
          if (topCashier != null && topWaiter != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                  height: 1),
            ),
          if (topWaiter != null)
            _EmployeeHighlightTile(
              role: 'Waiter Terbaik',
              name: topWaiter.waiterName,
              stats:
                  '${topWaiter.orderCount} order • ${_currency.format(topWaiter.totalRevenue)}',
              icon: Icons.person_pin_rounded,
              color: Colors.teal.shade700,
            ),
        ],
      ),
    );
  }
}

class _EmployeeHighlightTile extends StatelessWidget {
  const _EmployeeHighlightTile({
    required this.role,
    required this.name,
    required this.stats,
    required this.icon,
    required this.color,
  });

  final String role;
  final String name;
  final String stats;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                stats,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.outline,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.stars_rounded, color: Colors.amber.shade700, size: 20),
      ],
    );
  }
}

class _RefundDetailsCard extends StatelessWidget {
  const _RefundDetailsCard({required this.orders});
  final List<TransactionOrder> orders;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM, HH:mm', 'id_ID');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: orders.asMap().entries.map((entry) {
          final index = entry.key;
          final order = entry.value;

          return Padding(
            padding: EdgeInsets.only(bottom: index < orders.length - 1 ? 12 : 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.replay_rounded,
                      size: 18, color: Colors.purple.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.invoiceNumber,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${order.paidAt != null ? dateFormat.format(order.paidAt!) : '-'} • ${order.totalItemCount} item',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: scheme.outline),
                      ),
                    ],
                  ),
                ),
                Text(
                  _currency.format(order.grandTotal),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.purple.shade700,
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

class _OutletHighlightsCard extends StatelessWidget {
  const _OutletHighlightsCard({required this.outlets});
  final List<OutletPerformance> outlets;

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
        children: outlets.asMap().entries.map((entry) {
          final index = entry.key;
          final o = entry.value;
          final isLast = index == outlets.length - 1;

          return Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: index == 0
                          ? const Color(0xFFF59E0B)
                          : scheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: index == 0 ? Colors.white : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.outletName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${o.totalOrders} order • Rata-rata ${_currency.format(o.avgOrderValue)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.outline,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _currency.format(o.totalRevenue),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${o.percentage.toStringAsFixed(1)}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: (o.percentage / 100).clamp(0.02, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: index == 0 ? const Color(0xFFF59E0B) : scheme.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                    height: 1,
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
