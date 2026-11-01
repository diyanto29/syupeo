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
import 'package:dpos/core/theme/app_theme.dart';
import 'package:dpos/core/widgets/pro_feature_dialog.dart';
import 'package:dpos/core/providers/feature_gate_provider.dart';
import 'package:dpos/core/services/excel_export_service.dart';
import 'package:dpos/features/reports/data/whatsapp_report_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

class ReportMobileView extends ConsumerWidget {
  const ReportMobileView({super.key, this.padding = EdgeInsets.zero});
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(reportDataProvider);
    final selectedTab = ref.watch(selectedReportTabProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Laporan & Analitik',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Analisis performa bisnis Anda',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Refresh button
              IconButton(
                onPressed: () => ref.invalidate(reportDataProvider),
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh Data',
              ),
              // Export Excel button
              reportAsync.maybeWhen(
                data: (report) => _ExportExcelButton(report: report),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(width: 8),
              // Export PDF button
              reportAsync.maybeWhen(
                data: (report) => _ExportPdfButton(report: report),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(width: 8),
              // Share WhatsApp button
              reportAsync.maybeWhen(
                data: (report) => _ShareWhatsAppButton(report: report),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Period & Outlet Filter ────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PERIODE & OUTLET',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: scheme.outline,
                ),
              ),
              const AnalyticsOutletFilterSelector(compact: true),
            ],
          ),
          const SizedBox(height: 8),
          const ReportPeriodSelector(),
          const SizedBox(height: 14),

          // ── Tab Chips ─────────────────────────────────────
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ReportTab.values.map((tab) {
                final isActive = tab == selectedTab;
                final featureGate = ref.watch(featureGateProvider);
                final isPlanPro = featureGate.isEnabled('reports');
                final isLocked = tab.isPro && !isPlanPro;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isActive,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tab.label),
                        if (isLocked) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 14,
                            color: scheme.outline.withValues(alpha: 0.7),
                          ),
                        ],
                      ],
                    ),
                    onSelected: (_) {
                      if (isLocked) {
                        showDialog(
                          context: context,
                          builder: (context) => ProFeatureDialog(
                            featureName: 'Laporan ${tab.label}',
                            description: 'Dapatkan analitik mendalam untuk ${tab.label.toLowerCase()} bisnis Anda dengan paket Pro.',
                          ),
                        );
                        return;
                      }
                      ref.read(selectedReportTabProvider.notifier).state = tab;
                    },
                    selectedColor: scheme.primary.withValues(alpha: 0.15),
                    checkmarkColor: scheme.primary,
                    labelStyle: theme.textTheme.labelMedium?.copyWith(
                      color: isActive ? scheme.primary : scheme.onSurface,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // ── Content ───────────────────────────────────────
          Expanded(
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
}

/// Export PDF button with loading state.
class _ExportPdfButton extends ConsumerStatefulWidget {
  const _ExportPdfButton({required this.report});
  final FullReport report;

  @override
  ConsumerState<_ExportPdfButton> createState() => _ExportPdfButtonState();
}

class _ExportPdfButtonState extends ConsumerState<_ExportPdfButton> {
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
    return IconButton.filledTonal(
      onPressed: _loading ? null : _exportPdf,
      icon: _loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            )
          : const Icon(Icons.picture_as_pdf_rounded, size: 20),
      tooltip: 'Export PDF',
      style: IconButton.styleFrom(
        backgroundColor: scheme.primary.withValues(alpha: 0.1),
      ),
    );
  }
}

class _ExportExcelButton extends ConsumerStatefulWidget {
  const _ExportExcelButton({required this.report});
  final FullReport report;

  @override
  ConsumerState<_ExportExcelButton> createState() => _ExportExcelButtonState();
}

class _ExportExcelButtonState extends ConsumerState<_ExportExcelButton> {
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
    return IconButton.filledTonal(
      onPressed: _loading ? null : _exportExcel,
      icon: _loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            )
          : const Icon(Icons.grid_on_rounded, size: 20),
      tooltip: 'Export Excel',
      style: IconButton.styleFrom(
        backgroundColor: scheme.primary.withValues(alpha: 0.1),
      ),
    );
  }
}

class _ShareWhatsAppButton extends ConsumerStatefulWidget {
  const _ShareWhatsAppButton({required this.report});
  final FullReport report;

  @override
  ConsumerState<_ShareWhatsAppButton> createState() => _ShareWhatsAppButtonState();
}

class _ShareWhatsAppButtonState extends ConsumerState<_ShareWhatsAppButton> {
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
    return IconButton.filledTonal(
      onPressed: _loading ? null : _shareWhatsApp,
      icon: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF10B981),
              ),
            )
          : const Icon(Icons.chat_bubble_rounded, size: 20, color: Color(0xFF059669)),
      tooltip: 'Kirim Rekap ke WhatsApp',
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
      ),
    );
  }
}

