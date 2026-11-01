import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/widgets/app_tablet_nav.dart';
import 'package:dpos/features/settings/data/payment_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class PaymentSettingsScreen extends ConsumerStatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  ConsumerState<PaymentSettingsScreen> createState() =>
      _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends ConsumerState<PaymentSettingsScreen> {
  bool _isSubmitting = false;

  Future<void> _refresh() {
    return ref.read(paymentMethodsProvider.notifier).refresh();
  }

  Future<void> _toggleMethod(PaymentMethodConfig method, bool isActive) async {
    if (_isSubmitting || !ref.read(canManagePaymentSettingsProvider)) {
      return;
    }

    final methods = ref.read(paymentMethodsProvider).valueOrNull ?? const [];
    final activeCount = methods.where((item) => item.isActive).length;
    if (!isActive && method.isActive && activeCount <= 1) {
      _showSnack('Sisakan minimal satu metode pembayaran aktif.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(paymentMethodsProvider.notifier)
          .saveMethod(method.copyWith(isActive: isActive));
      if (!mounted) {
        return;
      }
      _showSnack(
        isActive
            ? '${method.name} diaktifkan.'
            : '${method.name} dinonaktifkan.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack('Gagal memperbarui metode pembayaran: $error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _openEditor({PaymentMethodConfig? method}) async {
    if (_isSubmitting || !ref.read(canManagePaymentSettingsProvider)) {
      return;
    }

    final bootstrap = ref.read(homeBootstrapProvider).valueOrNull;
    final outletId = bootstrap?.currentOutlet?.id;
    if (outletId == null) {
      _showSnack('Pilih outlet aktif terlebih dahulu.');
      return;
    }

    final methods = ref.read(paymentMethodsProvider).valueOrNull ?? const [];
    final nextSortOrder = methods.isEmpty
        ? 0
        : methods
                  .map((item) => item.sortOrder)
                  .reduce((value, item) => value > item ? value : item) +
              10;

    final result = await showModalBottomSheet<PaymentMethodConfig>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return _PaymentMethodEditorSheet(
          initialMethod: method,
          outletId: outletId,
          nextSortOrder: nextSortOrder,
          existingCodes: methods
              .where((item) => item.id != method?.id)
              .map((item) => item.code)
              .toSet(),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(paymentMethodsProvider.notifier).saveMethod(result);
      if (!mounted) {
        return;
      }
      _showSnack(
        method == null
            ? 'Metode pembayaran berhasil ditambahkan.'
            : 'Metode pembayaran berhasil diperbarui.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack('Gagal menyimpan metode pembayaran: $error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deleteMethod(PaymentMethodConfig method) async {
    if (_isSubmitting ||
        method.isSystemDefault ||
        !ref.read(canManagePaymentSettingsProvider)) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Metode Pembayaran'),
          content: Text(
            '"${method.name}" akan dihapus dari outlet aktif. Lanjutkan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(paymentMethodsProvider.notifier).deleteMethod(method);
      if (!mounted) {
        return;
      }
      _showSnack('${method.name} dihapus.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack('Gagal menghapus metode pembayaran: $error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapAsync = ref.watch(homeBootstrapProvider);
    final methodsAsync = ref.watch(paymentMethodsProvider);
    final canManage = ref.watch(canManagePaymentSettingsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 760;

    final bootstrap = bootstrapAsync.valueOrNull;
    final outlet = bootstrap?.currentOutlet;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppOwnerDrawer(),
      appBar: isWide
          ? AppTabletHeader(
              title: const Text('Konfigurasi Pembayaran'),
              badge: const AppTabletBadge(label: 'Syupeo'),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _isSubmitting ? null : _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                if (canManage)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : () => _openEditor(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Tambah'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : AppBar(
              title: const Text('Konfigurasi Pembayaran'),
              centerTitle: true,
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _isSubmitting ? null : _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
      floatingActionButton: canManage && !isWide
          ? FloatingActionButton(
              onPressed: _isSubmitting ? null : () => _openEditor(),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (bootstrapAsync.isLoading && bootstrap == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (bootstrapAsync.hasError && bootstrap == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Gagal memuat outlet: ${bootstrapAsync.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (outlet == null) {
              return _EmptyPaymentState(
                icon: Icons.storefront_outlined,
                title: 'Outlet belum dipilih',
                message: 'Pilih outlet aktif untuk mengatur pembayaran.',
              );
            }

            return methodsAsync.when(
              data: (methods) => _PaymentMethodsContent(
                outletName: outlet.name,
                methods: methods,
                canManage: canManage,
                isSubmitting: _isSubmitting,
                isWide: isWide,
                onRefresh: _refresh,
                onAdd: () => _openEditor(),
                onEdit: (method) => _openEditor(method: method),
                onDelete: _deleteMethod,
                onToggle: _toggleMethod,
              ),
              error: (error, _) => _EmptyPaymentState(
                icon: Icons.cloud_off_outlined,
                title: 'Gagal memuat pembayaran',
                message: '$error',
                action: FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba Lagi'),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }
}

class _PaymentMethodsContent extends StatelessWidget {
  const _PaymentMethodsContent({
    required this.outletName,
    required this.methods,
    required this.canManage,
    required this.isSubmitting,
    required this.isWide,
    required this.onRefresh,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final String outletName;
  final List<PaymentMethodConfig> methods;
  final bool canManage;
  final bool isSubmitting;
  final bool isWide;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdd;
  final ValueChanged<PaymentMethodConfig> onEdit;
  final ValueChanged<PaymentMethodConfig> onDelete;
  final void Function(PaymentMethodConfig method, bool isActive) onToggle;

  @override
  Widget build(BuildContext context) {
    final activeCount = methods.where((item) => item.isActive).length;
    final contentWidth = isWide ? 980.0 : double.infinity;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          isWide ? 32 : 16,
          16,
          isWide ? 32 : 16,
          96,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PaymentSummaryPanel(
                    outletName: outletName,
                    activeCount: activeCount,
                    totalCount: methods.length,
                    canManage: canManage,
                    onAdd: isSubmitting ? null : onAdd,
                  ),
                  const SizedBox(height: 16),
                  if (methods.isEmpty)
                    const _EmptyPaymentState(
                      icon: Icons.payments_outlined,
                      title: 'Belum ada metode pembayaran',
                      message: 'Tambahkan metode pembayaran untuk outlet ini.',
                    )
                  else
                    for (final method in methods) ...[
                      _PaymentMethodTile(
                        method: method,
                        canManage: canManage,
                        isSubmitting: isSubmitting,
                        onEdit: () => onEdit(method),
                        onDelete: method.isSystemDefault
                            ? null
                            : () => onDelete(method),
                        onToggle: (value) => onToggle(method, value),
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentSummaryPanel extends StatelessWidget {
  const _PaymentSummaryPanel({
    required this.outletName,
    required this.activeCount,
    required this.totalCount,
    required this.canManage,
    this.onAdd,
  });

  final String outletName;
  final int activeCount;
  final int totalCount;
  final bool canManage;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.payments_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  outletName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$activeCount aktif dari $totalCount metode',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withOpacity(0.58),
                  ),
                ),
              ],
            ),
          ),
          if (canManage)
            IconButton.filledTonal(
              tooltip: 'Tambah metode',
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.method,
    required this.canManage,
    required this.isSubmitting,
    required this.onEdit,
    required this.onToggle,
    this.onDelete,
  });

  final PaymentMethodConfig method;
  final bool canManage;
  final bool isSubmitting;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _paymentMethodColor(method.type, scheme);

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: canManage && !isSubmitting ? onEdit : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: method.isActive
                  ? color.withOpacity(0.28)
                  : scheme.outlineVariant.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(method.isActive ? 0.14 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _paymentMethodIcon(method.type),
                  color: method.isActive
                      ? color
                      : scheme.onSurface.withOpacity(0.36),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      method.displaySubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
              if (canManage) ...[
                IconButton(
                  tooltip: 'Edit',
                  onPressed: isSubmitting ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Hapus',
                    onPressed: isSubmitting ? null : onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                Switch(
                  value: method.isActive,
                  onChanged: isSubmitting ? null : onToggle,
                ),
              ] else
                _StatusPill(isActive: method.isActive),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive ? Colors.green : Theme.of(context).disabledColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Aktif' : 'Nonaktif',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PaymentMethodEditorSheet extends StatefulWidget {
  const _PaymentMethodEditorSheet({
    required this.outletId,
    required this.nextSortOrder,
    required this.existingCodes,
    this.initialMethod,
  });

  final String outletId;
  final int nextSortOrder;
  final Set<String> existingCodes;
  final PaymentMethodConfig? initialMethod;

  @override
  State<_PaymentMethodEditorSheet> createState() =>
      _PaymentMethodEditorSheetState();
}

class _PaymentMethodEditorSheetState extends State<_PaymentMethodEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _providerController = TextEditingController();
  final _accountLabelController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _sortOrderController = TextEditingController();

  PaymentMethodType _type = PaymentMethodType.custom;
  bool _isActive = true;
  bool _requiresReference = false;
  bool _allowsChange = false;

  bool get _isEditing => widget.initialMethod != null;
  bool get _canEditCode => widget.initialMethod?.isSystemDefault != true;

  @override
  void initState() {
    super.initState();
    final method = widget.initialMethod;
    _nameController.text = method?.name ?? '';
    _codeController.text = method?.code ?? '';
    _providerController.text = method?.provider ?? '';
    _accountLabelController.text = method?.accountLabel ?? '';
    _accountNumberController.text = method?.accountNumber ?? '';
    _instructionsController.text = method?.instructions ?? '';
    _sortOrderController.text = (method?.sortOrder ?? widget.nextSortOrder)
        .toString();
    _type = method?.type ?? PaymentMethodType.custom;
    _isActive = method?.isActive ?? true;
    _requiresReference = method?.requiresReference ?? false;
    _allowsChange = method?.allowsChange ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _providerController.dispose();
    _accountLabelController.dispose();
    _accountNumberController.dispose();
    _instructionsController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final normalizedCode = PaymentMethodConfig.normalizeCode(
      _codeController.text,
    );
    final method = PaymentMethodConfig(
      id: widget.initialMethod?.id ?? const Uuid().v4(),
      outletId: widget.outletId,
      code: normalizedCode,
      name: _nameController.text.trim(),
      type: _type,
      provider: _providerController.text,
      accountLabel: _accountLabelController.text,
      accountNumber: _accountNumberController.text,
      instructions: _instructionsController.text,
      isActive: _isActive,
      sortOrder: int.tryParse(_sortOrderController.text.trim()) ?? 0,
      requiresReference: _requiresReference,
      allowsChange: _allowsChange,
      metadata: widget.initialMethod?.metadata ?? const {},
      createdAt: widget.initialMethod?.createdAt,
      updatedAt: widget.initialMethod?.updatedAt,
    );

    Navigator.of(context).pop(method);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing
                      ? 'Edit Metode Pembayaran'
                      : 'Tambah Metode Pembayaran',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nama metode',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Nama metode wajib diisi.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeController,
                  enabled: _canEditCode,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Kode',
                  ),
                  validator: (value) {
                    final normalized = PaymentMethodConfig.normalizeCode(
                      value ?? '',
                    );
                    if (normalized.isEmpty) {
                      return 'Kode wajib diisi.';
                    }
                    if (!RegExp(
                      r'^[a-z0-9][a-z0-9_]{0,62}$',
                    ).hasMatch(normalized)) {
                      return 'Gunakan huruf kecil, angka, atau underscore.';
                    }
                    if (widget.existingCodes.contains(normalized)) {
                      return 'Kode sudah dipakai di outlet ini.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PaymentMethodType>(
                  value: _type,
                  decoration: const InputDecoration(
                    labelText: 'Jenis',
                  ),
                  items: PaymentMethodType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _type = value;
                      if (value == PaymentMethodType.cash) {
                        _allowsChange = true;
                        _requiresReference = false;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _providerController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Provider',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _accountLabelController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Label akun',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _accountNumberController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nomor akun',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sortOrderController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Urutan',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _instructionsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Catatan',
                  ),
                ),
                const SizedBox(height: 12),
                _EditorSwitch(
                  title: 'Aktif',
                  subtitle: 'Tersedia di pilihan pembayaran kasir',
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                _EditorSwitch(
                  title: 'Wajib nomor referensi',
                  subtitle: 'Dipakai untuk approval, settlement, atau trace ID',
                  value: _requiresReference,
                  onChanged: (value) =>
                      setState(() => _requiresReference = value),
                ),
                _EditorSwitch(
                  title: 'Dukung kembalian',
                  subtitle: 'Umumnya hanya untuk pembayaran tunai',
                  value: _allowsChange,
                  onChanged: (value) => setState(() => _allowsChange = value),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.primary,
                        ),
                        child: const Text('Simpan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorSwitch extends StatelessWidget {
  const _EditorSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _EmptyPaymentState extends StatelessWidget {
  const _EmptyPaymentState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: scheme.onSurface.withOpacity(0.36)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withOpacity(0.58),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

IconData _paymentMethodIcon(PaymentMethodType type) {
  switch (type) {
    case PaymentMethodType.cash:
      return Icons.money_rounded;
    case PaymentMethodType.card:
      return Icons.credit_card_rounded;
    case PaymentMethodType.qris:
      return Icons.qr_code_scanner_rounded;
    case PaymentMethodType.bankTransfer:
      return Icons.account_balance_rounded;
    case PaymentMethodType.eWallet:
      return Icons.account_balance_wallet_rounded;
    case PaymentMethodType.custom:
      return Icons.payments_outlined;
  }
}

Color _paymentMethodColor(PaymentMethodType type, ColorScheme scheme) {
  switch (type) {
    case PaymentMethodType.cash:
      return Colors.green;
    case PaymentMethodType.card:
      return scheme.primary;
    case PaymentMethodType.qris:
      return Colors.orange;
    case PaymentMethodType.bankTransfer:
      return Colors.blue;
    case PaymentMethodType.eWallet:
      return Colors.teal;
    case PaymentMethodType.custom:
      return scheme.secondary;
  }
}
