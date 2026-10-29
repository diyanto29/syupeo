import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/settings/data/order_type_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderTypeSettingsScreen extends ConsumerStatefulWidget {
  const OrderTypeSettingsScreen({super.key});

  @override
  ConsumerState<OrderTypeSettingsScreen> createState() =>
      _OrderTypeSettingsScreenState();
}

class _OrderTypeSettingsScreenState
    extends ConsumerState<OrderTypeSettingsScreen> {
  bool _isSubmitting = false;

  Future<void> _refresh() {
    return ref.read(orderTypesProvider.notifier).refresh();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _toggleActive(OrderTypeConfig orderType, bool isActive) async {
    if (_isSubmitting || !ref.read(canManageOrderTypesProvider)) return;

    final current = ref.read(orderTypesProvider).value ?? const [];
    final activeCount = current.where((item) => item.isActive).length;
    if (!isActive && orderType.isActive && activeCount <= 1) {
      _showSnack('Sisakan minimal satu tipe pesanan aktif.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(orderTypesProvider.notifier)
          .toggleActive(orderType.id, isActive);
      _showSnack(
        isActive
            ? '${orderType.name} diaktifkan.'
            : '${orderType.name} dinonaktifkan.',
      );
    } catch (e) {
      _showSnack('Gagal mengubah status: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteOrderType(OrderTypeConfig item) async {
    if (_isSubmitting || !ref.read(canManageOrderTypesProvider)) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Tipe Pesanan?'),
        content: Text('Apakah Anda yakin ingin menghapus "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(orderTypesProvider.notifier).deleteOrderType(item.id);
      _showSnack('Tipe pesanan "${item.name}" berhasil dihapus.');
    } catch (e) {
      _showSnack('Gagal menghapus: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openEditor({OrderTypeConfig? item}) async {
    if (_isSubmitting || !ref.read(canManageOrderTypesProvider)) return;

    final bootstrap = ref.read(homeBootstrapProvider).value;
    final outletId = bootstrap?.currentOutlet?.id;
    if (outletId == null) {
      _showSnack('Pilih outlet aktif terlebih dahulu.', isError: true);
      return;
    }

    final current = ref.read(orderTypesProvider).value ?? const [];
    final nextSortOrder = current.isEmpty
        ? 0
        : current
                .map((e) => e.sortOrder)
                .reduce((a, b) => a > b ? a : b) +
            10;

    final result = await showModalBottomSheet<OrderTypeConfig>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => _OrderTypeEditorSheet(
        initialItem: item,
        outletId: outletId,
        nextSortOrder: nextSortOrder,
        existingCodes: current
            .where((x) => x.id != item?.id)
            .map((x) => x.code)
            .toSet(),
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(orderTypesProvider.notifier).saveOrderType(result);
      _showSnack(
        item == null
            ? 'Tipe pesanan "${result.name}" berhasil ditambahkan.'
            : 'Tipe pesanan "${result.name}" berhasil diperbarui.',
      );
    } catch (e) {
      _showSnack('Gagal menyimpan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderTypesAsync = ref.watch(orderTypesProvider);
    final canManage = ref.watch(canManageOrderTypesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tipe Pesanan',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Dine In, Take Away, Ojek Online, & Pengantaran',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Tambah Tipe',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
            )
          : null,
      body: orderTypesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  'Gagal memuat tipe pesanan',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D4ED8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.touch_app_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pilihan Tipe Pesanan Fleksibel',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E3A8A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tipe pesanan yang aktif akan muncul di panel kasir POS dan dicetak pada struk belanja serta tiket dapur.',
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF1E40AF),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'DAFTAR TIPE PESANAN (${items.length})',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),

                ...items.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: item.isActive
                            ? theme.colorScheme.outlineVariant.withValues(alpha: 0.7)
                            : Colors.grey.shade300,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          // Leading Avatar
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: item.isActive
                                  ? const Color(0xFFEFF6FF)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: item.isActive
                                    ? const Color(0xFFBFDBFE)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                item.emoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        item.name,
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: item.isActive
                                              ? theme.colorScheme.onSurface
                                              : Colors.grey.shade500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (item.isSystemDefault) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Sistem',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // Badges
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (item.requiresTable)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: const Color(0xFFBFDBFE),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Text('🍽️ Butuh Meja',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF1D4ED8),
                                                )),
                                          ],
                                        ),
                                      ),
                                    if (item.surchargePercentage > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '+${item.surchargePercentage.toStringAsFixed(0)}% Harga',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF92400E),
                                          ),
                                        ),
                                      ),
                                    if (item.surchargeFlat > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3E8FF),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '+Rp ${item.surchargeFlat.toInt()}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF7E22CE),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Actions
                          if (canManage) ...[
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              tooltip: 'Edit Tipe Pesanan',
                              onPressed: () => _openEditor(item: item),
                            ),
                            if (!item.isSystemDefault)
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded,
                                    size: 20, color: Colors.red.shade400),
                                tooltip: 'Hapus',
                                onPressed: () => _deleteOrderType(item),
                              ),
                            Switch.adaptive(
                              value: item.isActive,
                              activeColor: const Color(0xFF1D4ED8),
                              onChanged: (val) => _toggleActive(item, val),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDITOR BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _OrderTypeEditorSheet extends StatefulWidget {
  const _OrderTypeEditorSheet({
    this.initialItem,
    required this.outletId,
    required this.nextSortOrder,
    required this.existingCodes,
  });

  final OrderTypeConfig? initialItem;
  final String outletId;
  final int nextSortOrder;
  final Set<String> existingCodes;

  @override
  State<_OrderTypeEditorSheet> createState() => _OrderTypeEditorSheetState();
}

class _OrderTypeEditorSheetState extends State<_OrderTypeEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _surchargePctController;
  late final TextEditingController _surchargeFlatController;

  late String _selectedIcon;
  late bool _requiresTable;
  late bool _isActive;
  bool _autoCode = true;

  final List<Map<String, String>> _availableIcons = [
    {'icon': 'restaurant', 'emoji': '🍽️', 'label': 'Restoran'},
    {'icon': 'shopping_bag', 'emoji': '🥡', 'label': 'Bungkus'},
    {'icon': 'motorcycle', 'emoji': '🛵', 'label': 'Ojol / Motor'},
    {'icon': 'delivery_dining', 'emoji': '🚚', 'label': 'Kurir / Antar'},
    {'icon': 'storefront', 'emoji': '🏪', 'label': 'Toko'},
    {'icon': 'coffee', 'emoji': '☕', 'label': 'Kopi / Bar'},
    {'icon': 'fastfood', 'emoji': '🍔', 'label': 'Cepat Saji'},
    {'icon': 'celebration', 'emoji': '🎉', 'label': 'Katering / Acara'},
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _codeController = TextEditingController(text: item?.code ?? '');
    _surchargePctController = TextEditingController(
      text: item != null && item.surchargePercentage > 0
          ? item.surchargePercentage.toStringAsFixed(0)
          : '',
    );
    _surchargeFlatController = TextEditingController(
      text: item != null && item.surchargeFlat > 0
          ? item.surchargeFlat.toInt().toString()
          : '',
    );

    _selectedIcon = item?.icon ?? 'restaurant';
    _requiresTable = item?.requiresTable ?? false;
    _isActive = item?.isActive ?? true;
    _autoCode = item == null;

    _nameController.addListener(() {
      if (_autoCode) {
        _codeController.text =
            OrderTypeConfig.normalizeCode(_nameController.text);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _surchargePctController.dispose();
    _surchargeFlatController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final code = OrderTypeConfig.normalizeCode(_codeController.text);
    if (widget.existingCodes.contains(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kode tipe pesanan sudah dipakai. Gunakan nama lain.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final pct = double.tryParse(_surchargePctController.text.trim()) ?? 0;
    final flat = double.tryParse(_surchargeFlatController.text.trim()) ?? 0;

    final config = (widget.initialItem ??
            OrderTypeConfig(
              id: '',
              outletId: widget.outletId,
              code: code,
              name: _nameController.text.trim(),
              sortOrder: widget.nextSortOrder,
            ))
        .copyWith(
      name: _nameController.text.trim(),
      code: code,
      icon: _selectedIcon,
      requiresTable: _requiresTable,
      isActive: _isActive,
      surchargePercentage: pct,
      surchargeFlat: flat,
    );

    Navigator.pop(context, config);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.initialItem != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEdit ? 'Edit Tipe Pesanan' : 'Tambah Tipe Pesanan Baru',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),

              // Nama
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Tipe Pesanan *',
                  hintText: 'Contoh: GoFood, GrabFood, Titip Teman...',
                  prefixIcon: const Icon(Icons.label_outline_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Pilihan Icon
              Text(
                'PILIH IKON / EMOJI',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableIcons.map((opt) {
                  final isSelected = _selectedIcon == opt['icon'];
                  return InkWell(
                    onTap: () => setState(() => _selectedIcon = opt['icon']!),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFEFF6FF)
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF1D4ED8)
                              : Colors.grey.shade300,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(opt['emoji']!,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            opt['label']!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? const Color(0xFF1D4ED8)
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Switch Perlu Meja
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Perlu Nomor Meja',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Kasir akan diminta memilih atau mengisi nomor meja (seperti Dine In)',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  value: _requiresTable,
                  activeColor: const Color(0xFF1D4ED8),
                  onChanged: (val) => setState(() => _requiresTable = val),
                ),
              ),
              const SizedBox(height: 14),

              // Surcharge Optional
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _surchargePctController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Mark-up Harga (%)',
                        hintText: 'Misal: 15',
                        suffixText: '%',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _surchargeFlatController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Biaya Bungkus/Flat',
                        hintText: 'Misal: 2000',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    isEdit ? 'Simpan Perubahan' : 'Tambahkan Tipe Pesanan',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
