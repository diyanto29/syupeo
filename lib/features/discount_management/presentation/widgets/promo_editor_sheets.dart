import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/utils/rupiah_input_helper.dart';
import 'package:dpos/core/widgets/app_form_field.dart';
import 'package:dpos/core/widgets/app_tablet_nav.dart';
import 'package:dpos/features/discount_management/data/promo_repository.dart';
import 'package:dpos/features/discount_management/domain/promo_models.dart';
import 'package:dpos/features/menu_management/data/menu_repository.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// ── BUY X GET Y EDITOR SHEET ──────────────────────────────────────────────────

class BuyXGetYEditorSheet extends ConsumerStatefulWidget {
  const BuyXGetYEditorSheet({super.key, this.initialPromo, this.isPage = false});

  final BuyXGetYPromo? initialPromo;
  final bool isPage;

  @override
  ConsumerState<BuyXGetYEditorSheet> createState() =>
      _BuyXGetYEditorSheetState();
}

class _BuyXGetYEditorSheetState extends ConsumerState<BuyXGetYEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _minBuyQtyController = TextEditingController(text: '2');
  final _rewardQtyController = TextEditingController(text: '1');
  final _maxRewardController = TextEditingController(text: '1');

  BuyXGetYMode _mode = BuyXGetYMode.sameProduct;
  String? _selectedTriggerItemId;
  String? _selectedRewardItemId;
  bool _isMultipleAllowed = true;
  bool _isActive = true;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initialPromo;
    if (p != null) {
      _nameController.text = p.name;
      _mode = p.mode;
      _selectedTriggerItemId = p.triggerMenuItemId;
      _selectedRewardItemId = p.rewardMenuItemId;
      _minBuyQtyController.text = '${p.minBuyQty}';
      _rewardQtyController.text = '${p.rewardQty}';
      _isMultipleAllowed = p.isMultipleAllowed;
      _maxRewardController.text = '${p.maxRewardPerTransaction}';
      _startDate = p.startDate;
      _endDate = p.endDate;
      _isActive = p.isActive;
    } else {
      final now = DateTime.now();
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = _startDate.add(const Duration(days: 30, hours: 23, minutes: 59, seconds: 59));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _minBuyQtyController.dispose();
    _rewardQtyController.dispose();
    _maxRewardController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTriggerItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih produk pemicu (Trigger) terlebih dahulu.')),
      );
      return;
    }
    if (_mode == BuyXGetYMode.crossProduct && _selectedRewardItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih produk hadiah untuk mode Beda Produk.')),
      );
      return;
    }

    final businessId = ref.read(homeBootstrapProvider).value?.business?.id;
    if (businessId == null) return;

    setState(() => _isSaving = true);
    try {
      final promo = BuyXGetYPromo(
        id: widget.initialPromo?.id ?? _uuid.v4(),
        businessId: businessId,
        name: _nameController.text.trim(),
        mode: _mode,
        triggerMenuItemId: _selectedTriggerItemId!,
        minBuyQty: int.tryParse(_minBuyQtyController.text.trim()) ?? 1,
        rewardMenuItemId: _mode == BuyXGetYMode.sameProduct ? null : _selectedRewardItemId,
        rewardQty: int.tryParse(_rewardQtyController.text.trim()) ?? 1,
        isMultipleAllowed: _isMultipleAllowed,
        maxRewardPerTransaction: int.tryParse(_maxRewardController.text.trim()) ?? 1,
        startDate: _startDate,
        endDate: _endDate,
        isActive: _isActive,
      );

      await ref.read(buyXGetYPromosProvider.notifier).upsertPromo(promo);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan promo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final menuItems = ref.watch(menuItemsProvider).value ?? [];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isPage) ...[
                Text(
                  widget.initialPromo == null
                      ? 'Buat Promo Beli X Gratis Y'
                      : 'Edit Promo Beli X Gratis Y',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
              ],
              AppTextInput(
                label: 'Nama Promo',
                isRequired: true,
                controller: _nameController,
                hintText: 'Misal: Beli 2 Kopi Susu Gratis 1',
                validator: (val) => val == null || val.trim().isEmpty ? 'Nama promo wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              Text(
                'Mode Promo',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              SegmentedButton<BuyXGetYMode>(
                segments: const [
                  ButtonSegment(value: BuyXGetYMode.sameProduct, label: Text('Produk Sama')),
                  ButtonSegment(value: BuyXGetYMode.crossProduct, label: Text('Beda Produk')),
                ],
                selected: {_mode},
                onSelectionChanged: (val) => setState(() => _mode = val.first),
              ),
              const SizedBox(height: 14),
              AppDropdownField<String>(
                label: 'Produk Pemicu (Trigger)',
                isRequired: true,
                value: _selectedTriggerItemId,
                hintText: 'Pilih produk pemicu',
                items: menuItems.map((item) {
                  return DropdownMenuItem(
                    value: item.id,
                    child: Text(item.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedTriggerItemId = val),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AppTextInput(
                      label: 'Min. Beli (X)',
                      isRequired: true,
                      controller: _minBuyQtyController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextInput(
                      label: 'Jml Gratis (Y)',
                      isRequired: true,
                      controller: _rewardQtyController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              if (_mode == BuyXGetYMode.crossProduct) ...[
                const SizedBox(height: 14),
                AppDropdownField<String>(
                  label: 'Produk Hadiah (Gratis)',
                  isRequired: true,
                  value: _selectedRewardItemId,
                  hintText: 'Pilih produk hadiah',
                  items: menuItems.map((item) {
                    return DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedRewardItemId = val),
                ),
              ],
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Berlaku Kelipatan'),
                subtitle: const Text('Beli 2 gratis 1, beli 4 gratis 2, dst.'),
                value: _isMultipleAllowed,
                onChanged: (val) => setState(() => _isMultipleAllowed = val),
              ),
              AppTextInput(
                label: 'Maks. Gratis per Transaksi',
                controller: _maxRewardController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Status Promo Aktif'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Simpan Promo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── TEBUS MURAH EDITOR SHEET ──────────────────────────────────────────────────

class TebusMurahEditorSheet extends ConsumerStatefulWidget {
  const TebusMurahEditorSheet({super.key, this.initialPromo, this.isPage = false});

  final TebusMurahPromo? initialPromo;
  final bool isPage;

  @override
  ConsumerState<TebusMurahEditorSheet> createState() =>
      _TebusMurahEditorSheetState();
}

class _TebusMurahEditorSheetState extends ConsumerState<TebusMurahEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _minSpendController = TextEditingController(text: RupiahInputHelper.format(50000));
  final _specialPriceController = TextEditingController(text: RupiahInputHelper.format(10000));
  final _maxQtyController = TextEditingController(text: '1');
  final _quotaController = TextEditingController();

  TebusMurahMode _mode = TebusMurahMode.minSpend;
  String? _selectedTriggerItemId;
  Set<String> _selectedRewardItemIds = {};
  bool _isActive = true;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initialPromo;
    if (p != null) {
      _nameController.text = p.name;
      _mode = p.mode;
      _minSpendController.text = RupiahInputHelper.format(p.minSpendAmount ?? 0);
      _selectedTriggerItemId = p.triggerMenuItemId;
      _selectedRewardItemIds = {p.rewardMenuItemId};
      _specialPriceController.text = RupiahInputHelper.format(p.specialPrice);
      _maxQtyController.text = '${p.maxQtyPerTransaction}';
      if (p.quotaLimit != null) _quotaController.text = '${p.quotaLimit}';
      _startDate = p.startDate;
      _endDate = p.endDate;
      _isActive = p.isActive;
    } else {
      final now = DateTime.now();
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = _startDate.add(const Duration(days: 30, hours: 23, minutes: 59, seconds: 59));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _minSpendController.dispose();
    _specialPriceController.dispose();
    _maxQtyController.dispose();
    _quotaController.dispose();
    super.dispose();
  }

  Future<void> _openRewardItemPicker(List<MenuItem> menuItems) async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _MultiProductPickerSheet(
        menuItems: menuItems,
        initialSelectedIds: _selectedRewardItemIds,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedRewardItemIds = result;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRewardItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 produk yang dapat ditebus murah.')),
      );
      return;
    }
    if (_mode == TebusMurahMode.productCombo && _selectedTriggerItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih menu syarat untuk mode Beli Menu Tertentu.')),
      );
      return;
    }

    final businessId = ref.read(homeBootstrapProvider).value?.business?.id;
    if (businessId == null) return;

    setState(() => _isSaving = true);
    try {
      final baseSpecialPrice = RupiahInputHelper.parseToDouble(_specialPriceController.text);
      final promos = _selectedRewardItemIds.map((itemId) {
        final isInitial = widget.initialPromo != null && widget.initialPromo!.rewardMenuItemId == itemId;
        return TebusMurahPromo(
          id: isInitial ? widget.initialPromo!.id : _uuid.v4(),
          businessId: businessId,
          name: _nameController.text.trim(),
          mode: _mode,
          minSpendAmount: _mode == TebusMurahMode.minSpend
              ? RupiahInputHelper.parseToDouble(_minSpendController.text)
              : null,
          triggerMenuItemId: _mode == TebusMurahMode.productCombo ? _selectedTriggerItemId : null,
          rewardMenuItemId: itemId,
          specialPrice: baseSpecialPrice,
          maxQtyPerTransaction: int.tryParse(_maxQtyController.text.trim()) ?? 1,
          quotaLimit: int.tryParse(_quotaController.text.trim()),
          startDate: _startDate,
          endDate: _endDate,
          isActive: _isActive,
        );
      }).toList();

      await ref.read(tebusMurahPromosProvider.notifier).upsertPromos(promos);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan promo tebus murah: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final menuItems = ref.watch(menuItemsProvider).value ?? [];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isPage) ...[
                Text(
                  widget.initialPromo == null
                      ? 'Buat Promo Tebus Murah (PWP)'
                      : 'Edit Promo Tebus Murah',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
              ],
              AppTextInput(
                label: 'Nama Promo',
                isRequired: true,
                controller: _nameController,
                hintText: 'Misal: Tebus Murah Belanja 50rb',
                validator: (val) => val == null || val.trim().isEmpty ? 'Nama promo wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              Text(
                'Syarat Pemicu Promo',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              SegmentedButton<TebusMurahMode>(
                segments: const [
                  ButtonSegment(value: TebusMurahMode.minSpend, label: Text('Min. Belanja')),
                  ButtonSegment(value: TebusMurahMode.productCombo, label: Text('Menu Tertentu')),
                ],
                selected: {_mode},
                onSelectionChanged: (val) => setState(() => _mode = val.first),
              ),
              const SizedBox(height: 14),
              if (_mode == TebusMurahMode.minSpend)
                AppCurrencyInput(
                  label: 'Minimal Belanja Nota',
                  isRequired: true,
                  controller: _minSpendController,
                  prefixBadge: 'IDR',
                  hintText: '0',
                )
              else
                AppDropdownField<String>(
                  label: 'Menu Syarat Pemicu',
                  isRequired: true,
                  value: _selectedTriggerItemId,
                  hintText: 'Pilih menu syarat',
                  items: menuItems.map((item) {
                    return DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedTriggerItemId = val),
                ),
              const SizedBox(height: 16),

              // Multi-product Reward Selector
              Text('Pilihan Produk Tebus Murah *', style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _openRewardItemPicker(menuItems),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedRewardItemIds.isEmpty ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedRewardItemIds.isEmpty ? const Color(0xFFFCA5A5) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.redeem_rounded,
                        color: _selectedRewardItemIds.isEmpty ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedRewardItemIds.isEmpty
                                  ? 'Ketuk untuk Pilih Produk Tebus Murah'
                                  : '${_selectedRewardItemIds.length} Produk Pilihan Terpilih',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: _selectedRewardItemIds.isEmpty ? const Color(0xFF991B1B) : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              _selectedRewardItemIds.isEmpty
                                  ? 'Bisa pilih lebih dari 1 produk sekaligus'
                                  : 'Pelanggan bisa memilih salah satu saat transaksi',
                              style: TextStyle(
                                fontSize: 11,
                                color: _selectedRewardItemIds.isEmpty ? const Color(0xFFDC2626) : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _openRewardItemPicker(menuItems),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(_selectedRewardItemIds.isEmpty ? 'Pilih' : 'Ubah'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_selectedRewardItemIds.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedRewardItemIds.map((itemId) {
                    final item = menuItems.cast<MenuItem?>().firstWhere(
                          (m) => m?.id == itemId,
                          orElse: () => null,
                        );
                    if (item == null) return const SizedBox.shrink();
                    return Chip(
                      backgroundColor: const Color(0xFFEEF2FF),
                      side: const BorderSide(color: Color(0xFFC7D2FE)),
                      avatar: const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 16),
                      label: Text(
                        '${item.name} (${RupiahInputHelper.format(item.price)})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF6B7280)),
                      onDeleted: () {
                        setState(() {
                          _selectedRewardItemIds.remove(itemId);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: AppCurrencyInput(
                      label: 'Harga Tebus Murah',
                      isRequired: true,
                      controller: _specialPriceController,
                      prefixBadge: 'IDR',
                      hintText: '0',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AppTextInput(
                      label: 'Maks. Qty / Nota',
                      controller: _maxQtyController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppTextInput(
                label: 'Batas Total Kuota Toko (Opsional)',
                controller: _quotaController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                hintText: 'Kosongkan jika tanpa batas',
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Status Promo Aktif'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Simpan Promo Tebus Murah'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── FULL PAGE WRAPPERS ────────────────────────────────────────────────────────

class BuyXGetYEditorPage extends StatelessWidget {
  const BuyXGetYEditorPage({super.key, this.initialPromo});

  final BuyXGetYPromo? initialPromo;

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    final isEdit = initialPromo != null;
    final pageTitle = isEdit
        ? 'Edit Promo Beli X Gratis Y'
        : 'Buat Promo Beli X Gratis Y (BXGY)';
    final pageSubtitle = isEdit
        ? 'Perbarui aturan reward dan kuantitas produk promo'
        : 'Konfigurasi beli produk X dapat gratis atau diskon produk Y';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppOwnerDrawer(),
      appBar: isTablet
          ? AppTabletHeader(
              title: Text(pageTitle),
              subtitle: Text(
                pageSubtitle,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              badge: const AppTabletBadge(label: 'Syupeo'),
            )
          : AppBar(
              title: Text(pageTitle),
              centerTitle: false,
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: BuyXGetYEditorSheet(initialPromo: initialPromo, isPage: true),
          ),
        ),
      ),
    );
  }
}

class TebusMurahEditorPage extends StatelessWidget {
  const TebusMurahEditorPage({super.key, this.initialPromo});

  final TebusMurahPromo? initialPromo;

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    final isEdit = initialPromo != null;
    final pageTitle =
        isEdit ? 'Edit Promo Tebus Murah' : 'Buat Promo Tebus Murah (PWP)';
    final pageSubtitle = isEdit
        ? 'Perbarui harga tebus murah dan syarat pemicu promo'
        : 'Konfigurasi tebus produk harga khusus jika syarat belanja terpenuhi';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppOwnerDrawer(),
      appBar: isTablet
          ? AppTabletHeader(
              title: Text(pageTitle),
              subtitle: Text(
                pageSubtitle,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              badge: const AppTabletBadge(label: 'Syupeo'),
            )
          : AppBar(
              title: Text(pageTitle),
              centerTitle: false,
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: TebusMurahEditorSheet(initialPromo: initialPromo, isPage: true),
          ),
        ),
      ),
    );
  }
}

// ── MULTI-PRODUCT PICKER SHEET ────────────────────────────────────────────────

class _MultiProductPickerSheet extends StatefulWidget {
  const _MultiProductPickerSheet({
    required this.menuItems,
    required this.initialSelectedIds,
  });

  final List<MenuItem> menuItems;
  final Set<String> initialSelectedIds;

  @override
  State<_MultiProductPickerSheet> createState() => _MultiProductPickerSheetState();
}

class _MultiProductPickerSheetState extends State<_MultiProductPickerSheet> {
  late Set<String> _selectedIds;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initialSelectedIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.menuItems.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pilih Produk Tebus Murah',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bisa pilih lebih dari satu produk (${_selectedIds.length} dipilih)',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context, _selectedIds),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari menu / produk...',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Tidak ada produk yang cocok.'))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isSelected = _selectedIds.contains(item.id);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedIds.add(item.id);
                            } else {
                              _selectedIds.remove(item.id);
                            }
                          });
                        },
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          RupiahInputHelper.format(item.price),
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                        activeColor: const Color(0xFF2563EB),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, _selectedIds),
              child: Text(
                'Selesai (${_selectedIds.length} Produk Dipilih)',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
