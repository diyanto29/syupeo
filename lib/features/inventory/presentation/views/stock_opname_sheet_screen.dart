import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/inventory/data/stock_opname_repository.dart';
import 'package:dpos/features/inventory/domain/stock_opname_models.dart';

class StockOpnameSheetScreen extends ConsumerStatefulWidget {
  const StockOpnameSheetScreen({super.key, this.existingSessionId});

  final String? existingSessionId;

  @override
  ConsumerState<StockOpnameSheetScreen> createState() => _StockOpnameSheetScreenState();
}

class _StockOpnameSheetScreenState extends ConsumerState<StockOpnameSheetScreen> {
  StockOpnameSession? _session;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isBlindMode = false;
  String _selectedStorageFilter = 'Semua';
  String _searchQuery = '';

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _reasons = {};

  static final _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final List<String> _discrepancyReasons = [
    'Tumpah / Salah Racik',
    'Basi / Kedaluwarsa',
    'Rusak Fisik',
    'Jatah Karyawan (Staff Meal)',
    'Salah Catat Resep',
    'Salah Hitung Fisik',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    setState(() => _isLoading = true);
    final repo = ref.read(stockOpnameRepositoryProvider);
    final bootstrap = ref.read(homeBootstrapProvider).valueOrNull;

    try {
      if (widget.existingSessionId != null && widget.existingSessionId!.isNotEmpty) {
        final session = await repo.getOpnameSessionDetails(widget.existingSessionId!);
        _session = session;
      } else {
        final businessId = bootstrap?.business?.id;
        final outletId = bootstrap?.currentOutlet?.id;
        if (businessId == null || outletId == null) {
          throw Exception('Outlet atau Bisnis belum dipilih.');
        }

        final newSession = await repo.createOpnameSession(
          businessId: businessId,
          outletId: outletId,
          opnameType: 'daily_closing',
          blindCount: _isBlindMode,
        );
        _session = newSession;
      }

      // Initialize text controllers for each item
      if (_session != null) {
        for (final item in _session!.items) {
          final text = item.physicalStock == 0 ? '0' : _formatNumber(item.physicalStock);
          _controllers[item.id] = TextEditingController(text: text);
          _reasons[item.id] = item.discrepancyReason;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat sesi opname: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatNumber(double num) {
    if (num % 1 == 0) return num.toInt().toString();
    return num.toStringAsFixed(2);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onPhysicalStockChanged(StockOpnameItem item, String val) {
    final parsed = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
    final updatedItems = _session!.items.map((it) {
      if (it.id == item.id) {
        return it.copyWith(physicalStock: parsed);
      }
      return it;
    }).toList();

    setState(() {
      _session = _session!.copyWith(items: updatedItems);
    });
  }

  void _adjustQty(StockOpnameItem item, double delta) {
    final current = item.physicalStock;
    final next = (current + delta).clamp(0.0, 999999.0);
    _controllers[item.id]?.text = _formatNumber(next);
    _onPhysicalStockChanged(item, next.toString());
  }

  // Summary calculations
  int get _totalCountedItems => _session?.items.length ?? 0;

  int get _itemsWithDiscrepancy =>
      _session?.items.where((it) => it.hasDiscrepancy).length ?? 0;

  double get _totalDiscrepancyValue {
    if (_session == null) return 0.0;
    return _session!.items.fold(0.0, (sum, it) => sum + it.calculatedLossOrGain);
  }

  Future<void> _handleReconcile() async {
    if (_session == null) return;

    final discCount = _itemsWithDiscrepancy;
    final lossVal = _totalDiscrepancyValue;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 28),
            const SizedBox(width: 10),
            Text(
              'Rekonsiliasi Opname',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin menyelesaikan sesi opname ini? Stok sistem akan langsung disesuaikan dengan hasil hitungan fisik.',
              style: GoogleFonts.manrope(fontSize: 14, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Item dengan Selisih:', style: GoogleFonts.manrope(fontSize: 13)),
                      Text('$discCount bahan',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Nilai Selisih Kas/Modal:', style: GoogleFonts.manrope(fontSize: 13)),
                      Text(
                        _currencyFormatter.format(lossVal),
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          color: lossVal < 0
                              ? const Color(0xFFDC2626)
                              : (lossVal > 0 ? const Color(0xFF16A34A) : const Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Periksa Lagi', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Ya, Rekonsiliasi Stok', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(stockOpnameRepositoryProvider);

      // 1. Batch save item counts
      await repo.batchSaveItemCounts(_session!.items);

      // 2. Reconcile
      await repo.completeAndReconcileOpname(sessionId: _session!.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Stok opname berhasil direkonsiliasi dan saldo bahan diperbarui!'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyelesaikan opname: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lembar Stock Opname')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lembar Stock Opname')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Tidak ada bahan baku yang terdaftar untuk di-opname.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      );
    }

    // Filter by storage & search
    final storageLocations = {'Semua', ..._session!.items.map((it) => it.storageLocation)};
    final filteredItems = _session!.items.where((it) {
      if (_selectedStorageFilter != 'Semua' && it.storageLocation != _selectedStorageFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty &&
          !it.itemName.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lembar Stock Opname F&B',
              style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              '${_session!.sessionNumber} • ${DateFormat('dd MMM yyyy, HH:mm').format(_session!.startedAt ?? DateTime.now())}',
              style: GoogleFonts.manrope(fontSize: 11, color: const Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Riwayat Opname',
            onPressed: () => context.pushNamed(RouteNames.stockOpnameHistory),
          ),
          // Blind Mode Toggle
          Row(
            children: [
              Text(
                'Blind',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _isBlindMode ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                ),
              ),
              Switch(
                value: _isBlindMode,
                activeColor: const Color(0xFFFF9800),
                onChanged: (val) {
                  setState(() => _isBlindMode = val);
                },
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // KPI Metric Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                _buildMetricCard(
                  title: 'Total Bahan',
                  value: '$_totalCountedItems item',
                  color: const Color(0xFF0F172A),
                  icon: Icons.checklist_rounded,
                ),
                const SizedBox(width: 10),
                _buildMetricCard(
                  title: 'Ada Selisih',
                  value: '$_itemsWithDiscrepancy bahan',
                  color: _itemsWithDiscrepancy > 0 ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                  icon: Icons.difference_rounded,
                ),
                const SizedBox(width: 10),
                _buildMetricCard(
                  title: 'Nilai Selisih',
                  value: _currencyFormatter.format(_totalDiscrepancyValue),
                  color: _totalDiscrepancyValue < 0
                      ? const Color(0xFFDC2626)
                      : (_totalDiscrepancyValue > 0 ? const Color(0xFF16A34A) : const Color(0xFF0F172A)),
                  icon: Icons.payments_outlined,
                  isBold: true,
                ),
              ],
            ),
          ),

          // Search & Filter Storage Chips
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari nama bahan baku...',
                    hintStyle: GoogleFonts.manrope(fontSize: 13, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: storageLocations.map((loc) {
                      final isSelected = _selectedStorageFilter == loc;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(loc),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedStorageFilter = loc),
                          selectedColor: const Color(0xFF0F172A),
                          backgroundColor: const Color(0xFFF1F5F9),
                          labelStyle: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : const Color(0xFF475569),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Items Table List
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada bahan yang cocok dengan pencarian.',
                      style: GoogleFonts.manrope(color: const Color(0xFF94A3B8)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: filteredItems.length,
                    itemBuilder: (ctx, index) {
                      final item = filteredItems[index];
                      return _buildOpnameItemCard(item);
                    },
                  ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: Text(
                        'Simpan Draf & Keluar',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      onPressed: _isSaving ? null : _handleReconcile,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Selesaikan & Rekonsiliasi',
                                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 14),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    bool isBold = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: const Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: isBold ? FontWeight.w900 : FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpnameItemCard(StockOpnameItem item) {
    final diff = item.calculatedDiff;
    final lossGain = item.calculatedLossOrGain;
    final hasDiff = item.hasDiscrepancy;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasDiff ? const Color(0xFFFED7AA) : const Color(0xFFE2E8F0),
          width: hasDiff ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Item Name & Storage Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.itemName,
                  style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.storageLocation,
                  style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Comparison Grid: System vs Physical Input
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // System Stock (hidden if blind mode)
              if (!_isBlindMode) ...[
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stok Sistem', style: GoogleFonts.manrope(fontSize: 11, color: const Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatNumber(item.systemStock)} ${item.unit}',
                        style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
              ],

              // Physical Stock Input
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fisik Terhitung (${item.unit})',
                        style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildQtyButton(icon: Icons.remove, onTap: () => _adjustQty(item, -1)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _controllers[item.id],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800),
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                              ),
                              onChanged: (val) => _onPhysicalStockChanged(item, val),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _buildQtyButton(icon: Icons.add, onTap: () => _adjustQty(item, 1)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Discrepancy & Reason Section (if discrepancy exists and not in blind mode)
          if (!_isBlindMode && hasDiff) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      diff < 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      size: 14,
                      color: diff < 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Selisih: ${diff > 0 ? '+' : ''}${_formatNumber(diff)} ${item.unit}',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: diff < 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
                Text(
                  _currencyFormatter.format(lossGain),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: lossGain < 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Reason dropdown
            DropdownButtonFormField<String>(
              value: _reasons[item.id] ?? _discrepancyReasons.first,
              decoration: InputDecoration(
                labelText: 'Alasan Selisih',
                labelStyle: GoogleFonts.manrope(fontSize: 11, color: const Color(0xFF64748B)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              items: _discrepancyReasons.map((r) {
                return DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.manrope(fontSize: 12)));
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _reasons[item.id] = val;
                  final idx = _session!.items.indexWhere((it) => it.id == item.id);
                  if (idx != -1) {
                    _session!.items[idx] = _session!.items[idx].copyWith(discrepancyReason: val);
                  }
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQtyButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 38,
        width: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF334155)),
      ),
    );
  }
}
