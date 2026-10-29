import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/inventory/data/stock_opname_repository.dart';
import 'package:dpos/features/inventory/domain/stock_opname_models.dart';

class StockOpnameHistoryScreen extends ConsumerStatefulWidget {
  const StockOpnameHistoryScreen({super.key});

  @override
  ConsumerState<StockOpnameHistoryScreen> createState() => _StockOpnameHistoryScreenState();
}

class _StockOpnameHistoryScreenState extends ConsumerState<StockOpnameHistoryScreen> {
  String _selectedFilter = 'all'; // 'all', 'daily_closing', 'weekly', 'full_monthly'

  String _formatRupiah(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount.abs());
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(homeBootstrapProvider).valueOrNull;
    final outletId = bootstrap?.currentOutlet?.id ?? '';
    final historyAsync = ref.watch(opnameHistoryProvider(outletId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Riwayat Stock Opname & Audit',
              style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              bootstrap?.currentOutlet?.name ?? 'Outlet',
              style: GoogleFonts.manrope(fontSize: 11, color: const Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat Ulang',
            onPressed: () => ref.refresh(opnameHistoryProvider(outletId)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF9800)),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  'Gagal memuat riwayat opname',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(color: const Color(0xFF64748B), fontSize: 12),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(opnameHistoryProvider(outletId)),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.history_toggle_off_rounded,
                          size: 40, color: Color(0xFF6366F1)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum Ada Riwayat Opname',
                      style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sesi opname closing harian atau mingguan yang telah diselesaikan akan tercatat rapi di sini.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(fontSize: 13, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => context.pushNamed(RouteNames.stockOpnameSheet),
                      icon: const Icon(Icons.add_task_rounded, size: 18),
                      label: Text('Mulai Opname Sekarang',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            );
          }

          // KPI Calculations
          final totalSessions = sessions.length;
          final totalNetLoss = sessions.fold<double>(
            0.0,
            (sum, s) => sum + s.totalDiscrepancyValue,
          );

          // Filtering
          final filteredSessions = sessions.where((s) {
            if (_selectedFilter == 'all') return true;
            return s.opnameType == _selectedFilter;
          }).toList();

          return Column(
            children: [
              // Summary KPI Header
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL SESI AUDIT',
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF94A3B8),
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalSessions Sesi Selesai',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: const Color(0xFF334155)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NET FOOD LOSS / GAIN',
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF94A3B8),
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${totalNetLoss < 0 ? '-' : totalNetLoss > 0 ? '+' : ''}${_formatRupiah(totalNetLoss)}',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: totalNetLoss < -0.0001
                                  ? const Color(0xFFF87171)
                                  : totalNetLoss > 0.0001
                                      ? const Color(0xFF4ADE80)
                                      : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildFilterChip('all', 'Semua'),
                    const SizedBox(width: 8),
                    _buildFilterChip('daily_closing', 'Closing Harian'),
                    const SizedBox(width: 8),
                    _buildFilterChip('weekly', 'Mingguan'),
                    const SizedBox(width: 8),
                    _buildFilterChip('full_monthly', 'Bulanan Penuh'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Session List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filteredSessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final session = filteredSessions[index];
                    return _buildSessionCard(context, session);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      labelStyle: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : const Color(0xFF475569),
      ),
      selectedColor: const Color(0xFF0F172A),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
        ),
      ),
      onSelected: (_) => setState(() => _selectedFilter = key),
    );
  }

  Widget _buildSessionCard(BuildContext context, StockOpnameSession session) {
    final dateStr = session.completedAt != null
        ? DateFormat('EEEE, dd MMM yyyy • HH:mm', 'id_ID').format(session.completedAt!)
        : session.startedAt != null
            ? DateFormat('EEEE, dd MMM yyyy • HH:mm', 'id_ID').format(session.startedAt!)
            : '-';

    final isLoss = session.totalDiscrepancyValue < -0.0001;
    final isSurplus = session.totalDiscrepancyValue > 0.0001;

    String typeLabel = 'Closing Harian';
    if (session.opnameType == 'weekly') typeLabel = 'Mingguan';
    if (session.opnameType == 'full_monthly') typeLabel = 'Bulanan Penuh';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showSessionDetailModal(context, session),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          typeLabel,
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '#${session.sessionNumber}',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: session.status == 'completed'
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      session.status == 'completed' ? 'Selesai' : 'Draft',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: session.status == 'completed'
                            ? const Color(0xFF059669)
                            : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                dateStr,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
              if (session.notes != null && session.notes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  session.notes!,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selisih Finansial:',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    '${isLoss ? '-' : isSurplus ? '+' : ''}${_formatRupiah(session.totalDiscrepancyValue)}',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isLoss
                          ? const Color(0xFFDC2626)
                          : isSurplus
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSessionDetailModal(BuildContext context, StockOpnameSession sessionSummary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SessionDetailBottomSheet(sessionId: sessionSummary.id);
      },
    );
  }
}

class _SessionDetailBottomSheet extends ConsumerWidget {
  const _SessionDetailBottomSheet({required this.sessionId});
  final String sessionId;

  String _formatRupiah(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount.abs());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(stockOpnameRepositoryProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: FutureBuilder<StockOpnameSession>(
        future: repo.getOpnameSessionDetails(sessionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF9800)),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Gagal memuat rincian: ${snapshot.error}'),
              ),
            );
          }

          final session = snapshot.data!;
          final isLoss = session.totalDiscrepancyValue < -0.0001;
          final isSurplus = session.totalDiscrepancyValue > 0.0001;

          return Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Berita Acara Opname',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '#${session.sessionNumber}',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Summary Banner
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isLoss
                      ? const Color(0xFFFEF2F2)
                      : isSurplus
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isLoss
                        ? const Color(0xFFFECACA)
                        : isSurplus
                            ? const Color(0xFFBBF7D0)
                            : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Selisih Finansial:',
                          style: GoogleFonts.manrope(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                        Text(
                          '${isLoss ? '-' : isSurplus ? '+' : ''}${_formatRupiah(session.totalDiscrepancyValue)}',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isLoss
                                ? const Color(0xFFDC2626)
                                : isSurplus
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${session.items.length} Bahan Dihitung',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),

              // Items List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: session.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final item = session.items[index];
                    final diff = item.discrepancyQuantity;
                    final hasDiff = diff.abs() > 0.0001;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.itemName,
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Sistem: ${item.systemStock} ${item.unit}  •  Fisik: ${item.physicalStock} ${item.unit}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                if (item.discrepancyReason != null &&
                                    item.discrepancyReason != 'none') ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Alasan: ${item.discrepancyReason}',
                                      style: GoogleFonts.manrope(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                hasDiff
                                    ? '${diff > 0 ? '+' : ''}$diff ${item.unit}'
                                    : 'Pas (0)',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: hasDiff
                                      ? (diff < 0
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF16A34A))
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatRupiah(item.discrepancyValue),
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
