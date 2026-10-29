import 'package:dpos/core/domain/app_enums.dart';
import 'package:dpos/core/domain/outlet_models.dart';
import 'package:dpos/core/providers/analytics_outlet_filter_provider.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/reports/data/report_pdf_service.dart';
import 'package:dpos/features/reports/domain/report_models.dart';
import 'package:dpos/features/reports/state/report_providers.dart';
import 'package:dpos/features/reports/presentation/widgets/report_period_selector.dart';
import 'package:dpos/features/reports/presentation/widgets/report_overview_tab.dart';
import 'package:dpos/features/reports/presentation/widgets/report_products_tab.dart';
import 'package:dpos/features/reports/presentation/widgets/report_cashiers_tab.dart';
import 'package:dpos/features/reports/presentation/widgets/report_payments_tab.dart';
import 'package:dpos/features/reports/presentation/widgets/report_daily_tab.dart';
import 'package:dpos/features/reports/presentation/widgets/report_waiters_tab.dart';
import 'package:dpos/features/reports/presentation/widgets/report_cash_flow_tab.dart';
import 'package:dpos/features/reports/presentation/widgets/report_outlets_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:dpos/core/widgets/pro_feature_dialog.dart';
import 'package:dpos/core/providers/feature_gate_provider.dart';
import 'package:dpos/core/services/excel_export_service.dart';
import 'package:dpos/core/widgets/app_tablet_nav.dart';
import 'package:dpos/features/reports/data/whatsapp_report_service.dart';

class ReportTabletView extends ConsumerWidget {
  const ReportTabletView({super.key, this.padding = EdgeInsets.zero});
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(reportDataProvider);
    final selectedTab = ref.watch(selectedReportTabProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppOwnerDrawer(),
      appBar: AppTabletHeader(
        title: const Text('Laporan & Analitik Bisnis'),
        subtitle: Text(
          'Analisis omzet, penjualan per produk, kasir, dan ringkasan keuangan',
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        badge: const AppTabletBadge(label: 'Mangga POS'),
        actions: [
          reportAsync.maybeWhen(
            data: (report) => _ExportExcelTabletButton(report: report),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          reportAsync.maybeWhen(
            data: (report) => _ExportPdfTabletButton(report: report),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          reportAsync.maybeWhen(
            data: (report) => _ShareWhatsAppTabletButton(report: report),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refresh Data',
            onPressed: () => ref.invalidate(reportDataProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Row(
        children: [
          // ── Left Sidebar (Period & Tabs) ────────────────────────
          Container(
            width: 250,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                vertical: 20,
                horizontal: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Outlet selector
                  Text(
                    'OUTLET',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.outline,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const AnalyticsOutletFilterSelector(compact: true),
                  const SizedBox(height: 20),

                  // Period selector
                  Text(
                    'PERIODE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.outline,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const ReportPeriodSelector(compact: true),
                  const SizedBox(height: 24),

                  // Navigation
                  Text(
                    'NAVIGASI',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.outline,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  ...ReportTab.values.map((tab) {
                    final isActive = tab == selectedTab;
                    final featureGate = ref.watch(featureGateProvider);
                    final isPlanPro = featureGate.isEnabled(
                      'reports',
                    );
                    final isLocked = tab.isPro && !isPlanPro;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: isActive
                            ? scheme.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            if (isLocked) {
                              showDialog(
                                context: context,
                                builder: (context) => ProFeatureDialog(
                                  featureName: 'Laporan ${tab.label}',
                                  description:
                                      'Dapatkan analitik mendalam untuk ${tab.label.toLowerCase()} bisnis Anda dengan paket Pro.',
                                ),
                              );
                              return;
                            }
                            ref
                                    .read(
                                      selectedReportTabProvider.notifier,
                                    )
                                    .state =
                                tab;
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _tabIcon(tab),
                                  size: 20,
                                  color: isActive
                                      ? scheme.primary
                                      : scheme.outline,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    tab.label,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                          fontWeight: isActive
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isActive
                                              ? scheme.primary
                                              : scheme.onSurface,
                                        ),
                                  ),
                                ),
                                if (isLocked)
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    size: 16,
                                    color: scheme.outline.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

        // ── Main Content ────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: reportAsync.when(
              data: (report) => _buildTabContent(
                selectedTab,
                report,
                () => ref.invalidate(reportDataProvider),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: scheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Gagal memuat laporan',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$e',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () => ref.invalidate(reportDataProvider),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildTabContent(
    ReportTab tab,
    FullReport report,
    VoidCallback onRefresh,
  ) {
    return switch (tab) {
      ReportTab.overview => ReportOverviewTab(
        report: report,
        onRefresh: onRefresh,
      ),
      ReportTab.outlets => ReportOutletsTab(report: report),
      ReportTab.cashFlow => const ReportCashFlowTab(),
      ReportTab.products => ReportProductsTab(report: report),
      ReportTab.cashiers => ReportCashiersTab(report: report),
      ReportTab.waiters => ReportWaitersTab(report: report),
      ReportTab.payments => ReportPaymentsTab(report: report),
      ReportTab.daily => ReportDailyTab(report: report),
    };
  }

  IconData _tabIcon(ReportTab tab) {
    return switch (tab) {
      ReportTab.overview => Icons.dashboard_rounded,
      ReportTab.outlets => Icons.apartment_rounded,
      ReportTab.cashFlow => Icons.account_balance_wallet_rounded,
      ReportTab.products => Icons.inventory_2_rounded,
      ReportTab.cashiers => Icons.badge_rounded,
      ReportTab.waiters => Icons.person_pin_rounded,
      ReportTab.payments => Icons.payment_rounded,
      ReportTab.daily => Icons.calendar_today_rounded,
    };
  }
}

/// Export PDF button for tablet view with loading state.
class _ExportPdfTabletButton extends ConsumerStatefulWidget {
  const _ExportPdfTabletButton({required this.report});
  final FullReport report;

  @override
  ConsumerState<_ExportPdfTabletButton> createState() =>
      _ExportPdfTabletButtonState();
}

class _ExportPdfTabletButtonState
    extends ConsumerState<_ExportPdfTabletButton> {
  bool _loading = false;

  Future<void> _exportPdf() async {
    final featureGate = ref.read(featureGateProvider);
    final isPro = featureGate.isEnabled('reports');

    if (!isPro) {
      showDialog(
        context: context,
        builder: (context) => const ProFeatureDialog(
          featureName: 'Ekspor Laporan PDF',
          description:
              'Dapatkan laporan profesional dalam format PDF untuk memudahkan pengarsipan dan pembagian data bisnis Anda.',
        ),
      );
      return;
    }

    if (_loading) return;
    setState(() => _loading = true);

    try {
      final bootstrap = ref.read(homeBootstrapProvider).value;
      final businessName = bootstrap?.business?.name ?? 'Bisnis';
      final isOwnerOrAdmin = bootstrap?.effectiveRole == AppRole.owner ||
          bootstrap?.effectiveRole == AppRole.admin;
      final selectedOutletId = ref.read(selectedAnalyticsOutletIdProvider);
      final targetOutletId = isOwnerOrAdmin ? selectedOutletId : bootstrap?.currentOutlet?.id;

      final outletName = targetOutletId == null
          ? 'Semua Outlet (${bootstrap?.outlets.length ?? 0} Cabang)'
          : (bootstrap?.outlets.cast<Outlet?>().firstWhere(
                    (o) => o?.id == targetOutletId,
                    orElse: () => null,
                  )?.name ??
              bootstrap?.currentOutlet?.name ??
              'Outlet');
      final period = ref.read(selectedReportPeriodProvider);

      final pdfBytes = await ReportPdfService.generateFullReport(
        report: widget.report,
        businessName: businessName,
        outletName: outletName,
        periodLabel: period.label,
      );

      if (!mounted) return;

      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'Laporan_${businessName.replaceAll(' ', '_')}_${period.label}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal export PDF: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.icon(
      onPressed: _loading ? null : _exportPdf,
      icon: _loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.onPrimary,
              ),
            )
          : const Icon(Icons.picture_as_pdf_rounded, size: 18),
      label: const Text('Export PDF'),
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
    );
  }
}

class _ExportExcelTabletButton extends ConsumerStatefulWidget {
  const _ExportExcelTabletButton({required this.report});
  final FullReport report;

  @override
  ConsumerState<_ExportExcelTabletButton> createState() =>
      _ExportExcelTabletButtonState();
}

class _ExportExcelTabletButtonState
    extends ConsumerState<_ExportExcelTabletButton> {
  bool _loading = false;

  Future<void> _exportExcel() async {
    final featureGate = ref.read(featureGateProvider);
    final isPro = featureGate.isEnabled('reports');

    if (!isPro) {
      showDialog(
        context: context,
        builder: (context) => const ProFeatureDialog(
          featureName: 'Ekspor Laporan Excel',
          description:
              'Dapatkan laporan penjualan profesional dalam format Excel untuk analisis data yang lebih mendalam.',
        ),
      );
      return;
    }

    if (_loading) return;
    setState(() => _loading = true);

    try {
      final bootstrap = ref.read(homeBootstrapProvider).value;
      final businessName = bootstrap?.business?.name ?? 'Bisnis';
      final period = ref.read(selectedReportPeriodProvider);

      await ExcelExportService.exportSalesReport(
        context,
        report: widget.report,
        businessName: businessName,
        periodLabel: period.label,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal export Excel: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.icon(
      onPressed: _loading ? null : _exportExcel,
      icon: _loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.onPrimary,
              ),
            )
          : const Icon(Icons.grid_on_rounded, size: 18),
      label: const Text('Export Excel'),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _ShareWhatsAppTabletButton extends ConsumerStatefulWidget {
  const _ShareWhatsAppTabletButton({required this.report});
  final FullReport report;

  @override
  ConsumerState<_ShareWhatsAppTabletButton> createState() => _ShareWhatsAppTabletButtonState();
}

class _ShareWhatsAppTabletButtonState extends ConsumerState<_ShareWhatsAppTabletButton> {
  bool _loading = false;

  Future<void> _shareWhatsApp() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final bootstrap = ref.read(homeBootstrapProvider).value;
      final businessName = bootstrap?.business?.name ?? 'Toko';
      final outletName = bootstrap?.currentOutlet?.name;
      final ownerPhone = bootstrap?.business?.phone;
      final period = ref.read(selectedReportPeriodProvider);

      final message = WhatsAppReportService.generateReportText(
        report: widget.report,
        businessName: businessName,
        outletName: outletName,
        periodLabel: period.label,
      );

      final ok = await WhatsAppReportService.shareToWhatsApp(
        message: message,
        targetPhone: ownerPhone,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Membuka WhatsApp... Teks laporan telah disalin ke clipboard.'
                  : 'Teks laporan telah disalin ke clipboard.',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membagikan ke WhatsApp: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _loading ? null : _shareWhatsApp,
      icon: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.chat_bubble_rounded, size: 18),
      label: const Text('Kirim ke WhatsApp'),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

