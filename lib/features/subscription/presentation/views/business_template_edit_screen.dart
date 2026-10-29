import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/core/domain/business_template_models.dart';
import 'package:dpos/core/widgets/app_tablet_nav.dart';
import 'package:dpos/features/auth/data/auth_repository.dart';
import 'package:dpos/features/subscription/presentation/providers/business_template_provider.dart';
import 'package:go_router/go_router.dart';

class BusinessTemplateEditScreen extends ConsumerStatefulWidget {
  final BusinessTypeTemplate? template;
  const BusinessTemplateEditScreen({super.key, this.template});

  @override
  ConsumerState<BusinessTemplateEditScreen> createState() =>
      _BusinessTemplateEditScreenState();
}

class _BusinessTemplateEditScreenState
    extends ConsumerState<BusinessTemplateEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _descController;
  late Map<String, String> _featuresConfig;
  String _selectedIcon = 'restaurant_rounded';
  late TextEditingController _freeMaxTxController;
  late TextEditingController _proMaxTxController;
  late TextEditingController _freeMaxProductsController;
  late TextEditingController _proMaxProductsController;
  late TextEditingController _freeMaxOutletsController;
  late TextEditingController _proMaxOutletsController;
  late TextEditingController _waiterLabelController;
  late TextEditingController _kitchenLabelController;
  late TextEditingController _cashierLabelController;
  late TextEditingController _adminLabelController;

  final _availableFeatures = [
    {
      'key': 'transaction',
      'label': 'Transaksi POS',
      'icon': Icons.point_of_sale_rounded,
    },
    {
      'key': 'order_mgmt',
      'label': 'Pesanan & Draft',
      'icon': Icons.assignment_rounded,
    },
    {
      'key': 'menu_mgmt',
      'label': 'Manajemen Produk & Diskon',
      'icon': Icons.inventory_2_rounded,
    },
    {
      'key': 'master_catalog',
      'label': 'Master Catalog (Sampel Produk)',
      'icon': Icons.auto_stories_rounded,
    },
    {
      'key': 'table_mgmt',
      'label': 'Manajemen Meja',
      'icon': Icons.table_restaurant_rounded,
    },
    {
      'key': 'kitchen_kds',
      'label': 'Antrian Dapur',
      'icon': Icons.grid_view_rounded,
    },
    {
      'key': 'inventory',
      'label': 'Inventori / Stok',
      'icon': Icons.inventory_2_rounded,
    },
    {
      'key': 'tiered_pricing',
      'label': 'Harga Bertingkat / Grosir',
      'icon': Icons.layers_outlined,
    },
    {
      'key': 'cash_flow',
      'label': 'Manajemen Kas & Shift',
      'icon': Icons.account_balance_wallet_rounded,
    },
    {
      'key': 'qr_order',
      'label': 'QR Self-Order',
      'icon': Icons.qr_code_scanner_rounded,
    },
    {
      'key': 'reports',
      'label': 'Laporan Analitik',
      'icon': Icons.bar_chart_rounded,
    },
    {
      'key': 'editable_price',
      'label': 'Bisa Edit Harga Jual (Nego)',
      'icon': Icons.price_change_outlined,
    },
    {
      'key': 'subscription',
      'label': 'Menu Paket Langganan',
      'icon': Icons.workspace_premium_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template?.name);
    _codeController = TextEditingController(text: widget.template?.code);
    _descController = TextEditingController(text: widget.template?.description);
    _featuresConfig = Map.from(widget.template?.featuresConfig ?? {});
    // Initialize missing features as 'off'
    for (var f in _availableFeatures) {
      final key = f['key'] as String;
      if (!_featuresConfig.containsKey(key)) {
        _featuresConfig[key] = 'off';
      }
    }
    _selectedIcon = widget.template?.iconName ?? 'restaurant_rounded';

    final limits = widget.template?.limitsConfig ?? {};
    final free = limits['free'] as Map? ?? {};
    final pro = limits['pro'] as Map? ?? {};

    _freeMaxTxController = TextEditingController(
      text:
          (free['max_transactions'] ?? widget.template?.maxTransactions ?? 100)
              .toString(),
    );
    _proMaxTxController = TextEditingController(
      text: (pro['max_transactions'] ?? 99999).toString(),
    );
    _freeMaxProductsController = TextEditingController(
      text: (free['max_products'] ?? widget.template?.maxProducts ?? 50)
          .toString(),
    );
    _proMaxProductsController = TextEditingController(
      text: (pro['max_products'] ?? 99999).toString(),
    );
    _freeMaxOutletsController = TextEditingController(
      text: (free['max_outlets'] ?? widget.template?.maxOutlets ?? 1)
          .toString(),
    );
    _proMaxOutletsController = TextEditingController(
      text: (pro['max_outlets'] ?? 5).toString(),
    );

    final roleLabels = widget.template?.roleLabels ?? {};
    _waiterLabelController = TextEditingController(text: roleLabels['waiter']);
    _kitchenLabelController = TextEditingController(
      text: roleLabels['kitchen'],
    );
    _cashierLabelController = TextEditingController(
      text: roleLabels['cashier'],
    );
    _adminLabelController = TextEditingController(text: roleLabels['admin']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descController.dispose();
    _freeMaxTxController.dispose();
    _proMaxTxController.dispose();
    _freeMaxProductsController.dispose();
    _proMaxProductsController.dispose();
    _freeMaxOutletsController.dispose();
    _proMaxOutletsController.dispose();
    _waiterLabelController.dispose();
    _kitchenLabelController.dispose();
    _cashierLabelController.dispose();
    _adminLabelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isEdit = widget.template != null;
    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppOwnerDrawer(),
      appBar: isTablet
          ? AppTabletHeader(
              title: Text(isEdit ? 'Edit Template' : 'Template Baru'),
              badge: const AppTabletBadge(label: 'Mangga POS'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Simpan'),
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
              title: Text(isEdit ? 'Edit Template' : 'Template Baru'),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Simpan'),
                  ),
                ),
              ],
            ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    'Informasi Dasar',
                    Icons.info_outline_rounded,
                  ),
                  _buildCard(
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: 'Nama Template',
                          hint: 'Contoh: Cafe & Resto, Retail Modern',
                          validator: (v) =>
                              v?.isEmpty == true ? 'Wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _codeController,
                          label: 'Kode Template',
                          hint: 'kebab-case (unique)',
                          enabled: !isEdit,
                          validator: (v) =>
                              v?.isEmpty == true ? 'Wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _descController,
                          label: 'Deskripsi',
                          hint: 'Penjelasan singkat template ini',
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Visual & Icon', Icons.palette_outlined),
                  _buildCard(
                    child: Column(
                      children: [
                        const Text(
                          'Pilih Icon untuk Tampilan Onboarding',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        _buildIconSelector(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader(
                    'Batasan Sistem (Limits)',
                    Icons.speed_rounded,
                  ),
                  _buildCard(
                    child: Column(
                      children: [
                        _buildTierLimitRow(
                          'LIMIT PAKET FREE',
                          _freeMaxTxController,
                          _freeMaxProductsController,
                          _freeMaxOutletsController,
                          Colors.blue,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(),
                        ),
                        _buildTierLimitRow(
                          'LIMIT PAKET PRO',
                          _proMaxTxController,
                          _proMaxProductsController,
                          _proMaxOutletsController,
                          Colors.amber,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader(
                    'Custom Role Labels',
                    Icons.badge_outlined,
                  ),
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ganti nama peran agar sesuai dengan bisnis jasa/showroom.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _waiterLabelController,
                                label: 'Waiter (e.g. Sales/Marketer)',
                                hint: 'Waiter',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _kitchenLabelController,
                                label: 'Kitchen (e.g. Teknisi/Mekanik)',
                                hint: 'Kitchen',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _cashierLabelController,
                                label: 'Cashier (e.g. Finance)',
                                hint: 'Cashier',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _adminLabelController,
                                label: 'Admin (e.g. Supervisor)',
                                hint: 'Admin',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader(
                    'Konfigurasi Fitur & Tiering',
                    Icons.toggle_on_outlined,
                  ),
                  _buildCard(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: _availableFeatures.map((f) {
                        final key = f['key'] as String;
                        final currentVal = _featuresConfig[key] ?? 'off';

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: scheme.outlineVariant.withOpacity(0.3),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                f['icon'] as IconData,
                                size: 20,
                                color: currentVal != 'off'
                                    ? scheme.primary
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  f['label'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: 'off',
                                    label: Text(
                                      'OFF',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                  ),
                                  ButtonSegment(
                                    value: 'free',
                                    label: Text(
                                      'FREE',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                  ),
                                  ButtonSegment(
                                    value: 'pro',
                                    label: Text(
                                      'PRO',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ],
                                selected: {currentVal},
                                onSelectionChanged: (val) {
                                  setState(
                                    () => _featuresConfig[key] = val.first,
                                  );
                                },
                                style: const ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                showSelectedIcon: false,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTierLimitRow(
    String tierLabel,
    TextEditingController txController,
    TextEditingController prodController,
    TextEditingController outletController,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              tierLabel,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: color,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: txController,
                label: 'Max Transaksi',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: prodController,
                label: 'Max Produk',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: outletController,
                label: 'Max Outlet',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.2,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          enabled: enabled,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: scheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconSelector() {
    final icons = [
      'restaurant_rounded',
      'shopping_bag_rounded',
      'handyman_rounded',
      'apps_rounded',
      'motorcycle_rounded',
      'local_laundry_service_rounded',
      'business_center_rounded',
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: icons.map((icon) {
        final isSelected = _selectedIcon == icon;
        final scheme = Theme.of(context).colorScheme;
        return GestureDetector(
          onTap: () => setState(() => _selectedIcon = icon),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? scheme.primary : scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? scheme.primary : scheme.outlineVariant,
              ),
            ),
            child: Icon(
              _getIconData(icon),
              color: isSelected ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'restaurant_rounded':
        return Icons.restaurant_rounded;
      case 'shopping_bag_rounded':
        return Icons.shopping_bag_rounded;
      case 'handyman_rounded':
        return Icons.handyman_rounded;
      case 'apps_rounded':
        return Icons.apps_rounded;
      case 'motorcycle_rounded':
        return Icons.motorcycle_rounded;
      case 'local_laundry_service_rounded':
        return Icons.local_laundry_service_rounded;
      default:
        return Icons.business_center_rounded;
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final limitsConfig = {
      'free': {
        'max_transactions': int.tryParse(_freeMaxTxController.text) ?? 100,
        'max_products': int.tryParse(_freeMaxProductsController.text) ?? 50,
        'max_outlets': int.tryParse(_freeMaxOutletsController.text) ?? 1,
      },
      'pro': {
        'max_transactions': int.tryParse(_proMaxTxController.text) ?? 99999,
        'max_products': int.tryParse(_proMaxProductsController.text) ?? 99999,
        'max_outlets': int.tryParse(_proMaxOutletsController.text) ?? 5,
      },
    };

    final template = BusinessTypeTemplate(
      id: widget.template?.id ?? '',
      name: _nameController.text,
      code: _codeController.text,
      description: _descController.text,
      iconName: _selectedIcon,
      defaultEnabledFeatures: _featuresConfig.entries
          .where((e) => e.value != 'off')
          .map((e) => e.key)
          .toList(),
      featuresConfig: _featuresConfig,
      limitsConfig: limitsConfig,
      // Fallback for old system
      maxTransactions: limitsConfig['free']!['max_transactions'] as int,
      maxProducts: limitsConfig['free']!['max_products'] as int,
      maxOutlets: limitsConfig['free']!['max_outlets'] as int,
      showAds: false,
      roleLabels: {
        'waiter': _waiterLabelController.text.trim(),
        'kitchen': _kitchenLabelController.text.trim(),
        'cashier': _cashierLabelController.text.trim(),
        'admin': _adminLabelController.text.trim(),
      }..removeWhere((key, value) => value.isEmpty),
    );

    try {
      if (widget.template == null) {
        await ref
            .read(authRepositoryProvider)
            .createBusinessTypeTemplate(template);
      } else {
        await ref
            .read(authRepositoryProvider)
            .updateBusinessTypeTemplate(template);
      }
      ref.invalidate(businessTypeTemplatesProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        log(e.toString());
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
