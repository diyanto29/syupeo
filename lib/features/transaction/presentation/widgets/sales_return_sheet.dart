import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/features/menu_management/data/menu_repository.dart';
import 'package:dpos/features/transaction/data/transaction_repository.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';

final _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

class ReturnItemDraft {
  final TransactionItem item;
  int returnQuantity;
  String condition; // 'restockable' atau 'damaged_waste'
  bool isSelected;

  ReturnItemDraft({
    required this.item,
    this.returnQuantity = 1,
    this.condition = 'restockable',
    this.isSelected = true,
  });

  double get subtotal => item.unitPrice * returnQuantity;
}

class SalesReturnSheet extends ConsumerStatefulWidget {
  const SalesReturnSheet({
    super.key,
    required this.order,
    this.onReturnSuccess,
  });

  final TransactionOrder order;
  final VoidCallback? onReturnSuccess;

  static Future<bool?> show(
    BuildContext context, {
    required TransactionOrder order,
    VoidCallback? onReturnSuccess,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SalesReturnSheet(
        order: order,
        onReturnSuccess: onReturnSuccess,
      ),
    );
  }

  @override
  ConsumerState<SalesReturnSheet> createState() => _SalesReturnSheetState();
}

class _SalesReturnSheetState extends ConsumerState<SalesReturnSheet> {
  final _reasonNotesController = TextEditingController();
  late List<ReturnItemDraft> _drafts;
  String _refundMethod = 'cash'; // 'cash', 'transfer', 'exchange', 'store_credit'
  String _selectedReason = 'Salah Beli / Salah Ukuran';
  bool _isSubmitting = false;

  final List<String> _reasonPresets = [
    'Salah Beli / Salah Ukuran',
    'Barang Cacat / Rusak Fisik',
    'Makanan Basi / Komplain Rasa',
    'Kemasan Bocor / Terbuka',
    'Tukar dengan Produk Lain',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _drafts = widget.order.items
        .map((item) => ReturnItemDraft(item: item, returnQuantity: item.quantity))
        .toList();
  }

  @override
  void dispose() {
    _reasonNotesController.dispose();
    super.dispose();
  }

  double get _totalRefundAmount {
    return _drafts
        .where((d) => d.isSelected && d.returnQuantity > 0)
        .fold(0.0, (sum, d) => sum + d.subtotal);
  }

  int get _totalReturnedItemsCount {
    return _drafts
        .where((d) => d.isSelected)
        .fold(0, (sum, d) => sum + d.returnQuantity);
  }

  bool get _isFullOrderReturn {
    for (final d in _drafts) {
      if (!d.isSelected || d.returnQuantity < d.item.quantity) {
        return false;
      }
    }
    return true;
  }

  Future<void> _handleProcessReturn() async {
    final selectedItems =
        _drafts.where((d) => d.isSelected && d.returnQuantity > 0).toList();

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal 1 barang yang ingin diretur.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final client = SupabaseService.client;
      final currentUserId = SupabaseService.currentUser?.id;
      final returnNumber =
          'RET-${DateFormat('yyyyMMdd').format(DateTime.now())}-${const Uuid().v4().substring(0, 6).toUpperCase()}';

      final finalReason = _selectedReason == 'Lainnya' &&
              _reasonNotesController.text.trim().isNotEmpty
          ? _reasonNotesController.text.trim()
          : _selectedReason;

      // 1. Simpan Header Retur
      final returnResponse = await client.from('sales_returns').insert({
        'business_id': widget.order.businessId,
        'outlet_id': widget.order.outletId,
        'order_id': widget.order.id,
        'invoice_number': widget.order.invoiceNumber,
        'return_number': returnNumber,
        'total_refund_amount': _totalRefundAmount,
        'refund_method': _refundMethod,
        'reason': finalReason,
        'notes': _reasonNotesController.text.trim(),
        'processed_by_user_id': currentUserId,
      }).select('id').single();

      final salesReturnId = returnResponse['id'] as String;

      // 2. Simpan Detail Item yang Diretur & Update Stok
      for (final draft in selectedItems) {
        // Simpan baris detail retur
        await client.from('sales_return_items').insert({
          'sales_return_id': salesReturnId,
          'order_item_id': draft.item.id,
          'menu_item_id': draft.item.menuItemId,
          'item_name': draft.item.displayName,
          'quantity': draft.returnQuantity,
          'unit_price': draft.item.unitPrice,
          'subtotal': draft.subtotal,
          'condition': draft.condition,
        });

        // Jika kondisi = Layak Jual (restockable), kembalikan stok fisik produk
        if (draft.condition == 'restockable' && draft.item.menuItemId != null) {
          try {
            // Ambil stok saat ini
            final itemData = await client
                .from('menu_items')
                .select('stock_quantity')
                .eq('id', draft.item.menuItemId!)
                .maybeSingle();

            if (itemData != null && itemData['stock_quantity'] != null) {
              final currentStock = (itemData['stock_quantity'] as num).toInt();
              final newStock = currentStock + draft.returnQuantity;

              // Update stok menu_items
              await client
                  .from('menu_items')
                  .update({'stock_quantity': newStock})
                  .eq('id', draft.item.menuItemId!);

              // Catat mutasi di inventory_movements
              await client.from('inventory_movements').insert({
                'business_id': widget.order.businessId,
                'outlet_id': widget.order.outletId,
                'menu_item_id': draft.item.menuItemId!,
                'movement_type': 'refund',
                'quantity_before': currentStock,
                'quantity_delta': draft.returnQuantity,
                'quantity_after': newStock,
                'note':
                    'Retur Penjualan ($returnNumber): ${draft.item.displayName} layak jual kembali',
                'reference_type': 'order',
                'reference_id': widget.order.id,
                'performed_by_user_id': currentUserId,
              });
            }
          } catch (_) {
            // Abaikan jika tabel inventory_movements belum terisi penuh
          }
        } else if (draft.condition == 'damaged_waste' &&
            draft.item.menuItemId != null) {
          // Jika barang rusak, catat ke log mutasi bahwa barang rusak/terbuang
          try {
            final itemData = await client
                .from('menu_items')
                .select('stock_quantity')
                .eq('id', draft.item.menuItemId!)
                .maybeSingle();

            if (itemData != null && itemData['stock_quantity'] != null) {
              final currentStock = (itemData['stock_quantity'] as num).toInt();
              await client.from('inventory_movements').insert({
                'business_id': widget.order.businessId,
                'outlet_id': widget.order.outletId,
                'menu_item_id': draft.item.menuItemId!,
                'movement_type': 'refund',
                'quantity_before': currentStock,
                'quantity_delta': 0, // Tidak menambah stok display karena rusak
                'quantity_after': currentStock,
                'note':
                    'Barang Rusak/Basi dari Retur ($returnNumber): ${draft.item.displayName} tidak masuk rak',
                'reference_type': 'order',
                'reference_id': widget.order.id,
                'performed_by_user_id': currentUserId,
              });
            }
          } catch (_) {}
        }
      }

      // 3. Jika seluruh pesanan diretur secara total, tandai order sebagai refunded
      if (_isFullOrderReturn) {
        await ref.read(transactionRepositoryProvider).updateOrderStatus(
              widget.order.id,
              TransactionStatus.refunded,
              reason: 'Retur Penuh: $finalReason (No: $returnNumber)',
              voidedBy: currentUserId,
            );
      }

      // Invalidate data agar UI refresh
      ref.invalidate(orderHistoryProvider);
      ref.invalidate(menuItemsProvider);

      if (!mounted) return;

      widget.onReturnSuccess?.call();
      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Retur berhasil diproses! ($returnNumber) - Total: ${_currency.format(_totalRefundAmount)}',
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses retur: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.assignment_return_rounded,
                      color: Color(0xFFEA580C),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Proses Retur / Tukar Barang',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Invoice: ${widget.order.invoiceNumber}',
                          style: GoogleFonts.firaCode(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Petunjuk
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFFEA580C),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pilih item dan jumlah yang dikembalikan pelanggan. Tentukan apakah barang masih layak jual kembali atau rusak.',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF9A3412),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Daftar Item yang Bisa Diretur
              Text(
                'Pilih Barang yang Diretur:',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _drafts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final draft = _drafts[index];
                  final maxQty = draft.item.quantity;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: draft.isSelected
                          ? scheme.surface
                          : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      border: Border.all(
                        color: draft.isSelected
                            ? const Color(0xFFFF7A00).withValues(alpha: 0.6)
                            : scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: draft.isSelected,
                              activeColor: const Color(0xFFFF7A00),
                              onChanged: (val) {
                                setState(() => draft.isSelected = val ?? false);
                              },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    draft.item.displayName,
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    '${_currency.format(draft.item.unitPrice)} • Beli: $maxQty pcs',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _currency.format(draft.subtotal),
                              style: GoogleFonts.firaCode(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: draft.isSelected
                                    ? const Color(0xFFEA580C)
                                    : scheme.outline,
                              ),
                            ),
                          ],
                        ),

                        if (draft.isSelected) ...[
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Jumlah Diretur:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton.filledTonal(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: draft.returnQuantity > 1
                                        ? () => setState(
                                            () => draft.returnQuantity--)
                                        : null,
                                    icon: const Icon(Icons.remove, size: 16),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      '${draft.returnQuantity} pcs',
                                      style: GoogleFonts.manrope(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  IconButton.filledTonal(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: draft.returnQuantity < maxQty
                                        ? () => setState(
                                            () => draft.returnQuantity++)
                                        : null,
                                    icon: const Icon(Icons.add, size: 16),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Kondisi Fisik Barang
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_outline_rounded,
                                          size: 14, color: Color(0xFF16A34A)),
                                      SizedBox(width: 4),
                                      Text('Layak Jual (+Stok)',
                                          style: TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                  selected: draft.condition == 'restockable',
                                  selectedColor: const Color(0xFFDCFCE7),
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() =>
                                          draft.condition = 'restockable');
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.broken_image_outlined,
                                          size: 14, color: Color(0xFFDC2626)),
                                      SizedBox(width: 4),
                                      Text('Rusak / Waste',
                                          style: TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                  selected: draft.condition == 'damaged_waste',
                                  selectedColor: const Color(0xFFFEE2E2),
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() =>
                                          draft.condition = 'damaged_waste');
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Metode Penyelesaian Retur
              Text(
                'Metode Pengembalian Dana / Kompensasi:',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.money_rounded, size: 16),
                    label: const Text('Refund Tunai (Kas Laci)'),
                    selected: _refundMethod == 'cash',
                    selectedColor: const Color(0xFFFFEDD5),
                    onSelected: (val) {
                      if (val) setState(() => _refundMethod = 'cash');
                    },
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.account_balance_rounded, size: 16),
                    label: const Text('Transfer / E-Wallet'),
                    selected: _refundMethod == 'transfer',
                    selectedColor: const Color(0xFFFFEDD5),
                    onSelected: (val) {
                      if (val) setState(() => _refundMethod = 'transfer');
                    },
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.sync_alt_rounded, size: 16),
                    label: const Text('Tukar Barang Langsung'),
                    selected: _refundMethod == 'exchange',
                    selectedColor: const Color(0xFFFFEDD5),
                    onSelected: (val) {
                      if (val) setState(() => _refundMethod = 'exchange');
                    },
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.card_giftcard_rounded, size: 16),
                    label: const Text('Store Credit / Voucher'),
                    selected: _refundMethod == 'store_credit',
                    selectedColor: const Color(0xFFFFEDD5),
                    onSelected: (val) {
                      if (val) setState(() => _refundMethod = 'store_credit');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Alasan Retur
              Text(
                'Alasan Pengembalian:',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedReason,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.help_outline_rounded),
                ),
                items: _reasonPresets
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r, style: const TextStyle(fontSize: 13)),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedReason = val);
                },
              ),
              if (_selectedReason == 'Lainnya') ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _reasonNotesController,
                  decoration: const InputDecoration(
                    labelText: 'Tulis Alasan Retur *',
                    hintText: 'Jelaskan alasan pelanggan mengembalikan barang',
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Total & Tombol Proses
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Item Diretur:',
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '$_totalReturnedItemsCount pcs',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Nilai Pengembalian:',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          _currency.format(_totalRefundAmount),
                          style: GoogleFonts.firaCode(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFEA580C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed:
                          _isSubmitting ? null : _handleProcessReturn,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        _isSubmitting
                            ? 'Memproses Retur...'
                            : 'Konfirmasi & Proses Retur',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
