import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/features/cash_flow/data/cash_flow_repository.dart';
import 'package:dpos/features/cash_flow/domain/cash_flow_models.dart';
import 'package:dpos/features/cash_flow/state/cash_flow_provider.dart';
import 'package:dpos/features/transaction/data/transaction_repository.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';

class VoidOrderDialog extends ConsumerStatefulWidget {
  const VoidOrderDialog({
    super.key,
    required this.order,
    this.onSuccess,
  });

  final TransactionOrder order;
  final VoidCallback? onSuccess;

  @override
  ConsumerState<VoidOrderDialog> createState() => _VoidOrderDialogState();
}

class _VoidOrderDialogState extends ConsumerState<VoidOrderDialog> {
  final _reasonController = TextEditingController();
  String? _selectedPreset;
  bool _isSubmitting = false;
  bool _recordCashDrawerRefund = true;
  late TransactionStatus _targetStatus;

  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  double get _orderCashAmount {
    if (widget.order.payments.isNotEmpty) {
      double total = 0;
      for (final p in widget.order.payments) {
        final isCash = p.methodType.toLowerCase() == 'cash' ||
            p.methodName.toLowerCase().contains('tunai') ||
            p.methodName.toLowerCase().contains('cash');
        if (isCash) {
          total += (p.amount - widget.order.changeAmount).clamp(0.0, double.infinity);
        }
      }
      return total > 0 ? total : widget.order.grandTotal;
    }
    return widget.order.grandTotal;
  }

  final List<String> _presets = [
    'Salah Input Pesanan',
    'Pelanggan Membatalkan Pesanan',
    'Menu Tidak Tersedia (Sold Out)',
    'Kesalahan Harga/Diskon',
    'Pesanan Duplikat',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    // Default to void_, but if it's already paid, we can offer refund
    _targetStatus = widget.order.status == TransactionStatus.paid
        ? TransactionStatus.refunded
        : TransactionStatus.void_;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleVoid() async {
    final reason = _selectedPreset == 'Lainnya' || _selectedPreset == null
        ? _reasonController.text.trim()
        : _selectedPreset!;

    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Silakan pilih atau isi alasan pembatalan.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUserId = SupabaseService.currentUser?.id;
      await ref.read(transactionRepositoryProvider).updateOrderStatus(
            widget.order.id,
            _targetStatus,
            reason: reason,
            voidedBy: currentUserId,
          );

      // Jika refund tunai dan opsi catat kas keluar aktif, masukkan otomatis ke Mutasi Kas Keluar
      if (_targetStatus == TransactionStatus.refunded && _recordCashDrawerRefund) {
        try {
          final bootstrap = ref.read(homeBootstrapProvider).valueOrNull;
          final activeShift = ref.read(activeShiftProvider).valueOrNull;
          final cashierName = bootstrap?.profile?.fullName ?? widget.order.cashierName ?? 'Kasir';

          final cashFlowRepo = ref.read(cashFlowRepositoryProvider);
          await cashFlowRepo.addCashEntry(
            businessId: widget.order.businessId,
            outletId: widget.order.outletId,
            shiftId: activeShift?.id,
            type: CashFlowType.cashOut,
            category: 'Pengembalian Dana / Refund',
            amount: _orderCashAmount,
            paymentSource: 'cash',
            notes: 'Refund Tunai #${widget.order.invoiceNumber} ($reason)',
            cashierName: cashierName,
          );
        } catch (err) {
          debugPrint('[VoidOrderDialog] Failed to add cash flow entry for refund: $err');
        }
      }

      if (!mounted) return;
      
      // Invalidate providers
      ref.invalidate(orderHistoryProvider);
      ref.invalidate(draftOrdersProvider);
      ref.invalidate(confirmedOrdersProvider);
      ref.invalidate(shiftLiveTotalsProvider);
      ref.invalidate(activeShiftProvider);
      ref.invalidate(todayCashEntriesProvider);

      widget.onSuccess?.call();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal membatalkan pesanan: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPaid = widget.order.status == TransactionStatus.paid;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _targetStatus == TransactionStatus.refunded ? Icons.replay_rounded : Icons.warning_amber_rounded,
            color: Colors.red,
          ),
          const SizedBox(width: 12),
          Text(_targetStatus == TransactionStatus.refunded ? 'Refund Pesanan' : 'Batalkan Pesanan'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPaid) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pesanan ini sudah LUNAS. Pilih jenis pembatalan di bawah.',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const Text('Tipe Pembatalan:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<TransactionStatus>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionStatus.void_,
                      label: Text('Void (Salah Input)'),
                      icon: Icon(Icons.close_rounded),
                    ),
                    ButtonSegment(
                      value: TransactionStatus.refunded,
                      label: Text('Refund (Balik Dana)'),
                      icon: Icon(Icons.replay_rounded),
                    ),
                  ],
                  selected: {_targetStatus},
                  onSelectionChanged: (set) {
                    setState(() => _targetStatus = set.first);
                  },
                ),
              ),
              if (_targetStatus == TransactionStatus.refunded) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.point_of_sale_rounded, color: Color(0xFFEA580C), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pengeluaran Kas Laci: ${_currency.format(_orderCashAmount)}',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF9A3412),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Uang fisik dikembalikan ke pelanggan dari laci kasir.',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: const Color(0xFFC2410C),
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => setState(() => _recordCashDrawerRefund = !_recordCashDrawerRefund),
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _recordCashDrawerRefund,
                              onChanged: (val) => setState(() => _recordCashDrawerRefund = val ?? true),
                              activeColor: const Color(0xFFEA580C),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Catat otomatis di Mutasi Kas Keluar Hari Ini',
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF9A3412),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
            Text('Pilih Alasan:', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _presets.map((p) {
                final isSelected = _selectedPreset == p;
                return ChoiceChip(
                  label: Text(p),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() {
                      _selectedPreset = val ? p : null;
                      if (p != 'Lainnya') _reasonController.clear();
                    });
                  },
                );
              }).toList(),
            ),
            if (_selectedPreset == 'Lainnya') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Tulis Alasan Lainnya',
                  border: OutlineInputBorder(),
                  hintText: 'Misal: Kebakaran di dapur...',
                ),
                maxLines: 2,
                autofocus: true,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _handleVoid,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Konfirmasi Batal'),
        ),
      ],
    );
  }
}

/// Utility function to show the void dialog
Future<bool?> showVoidOrderDialog(BuildContext context, TransactionOrder order, {VoidCallback? onSuccess}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => VoidOrderDialog(order: order, onSuccess: onSuccess),
  );
}
