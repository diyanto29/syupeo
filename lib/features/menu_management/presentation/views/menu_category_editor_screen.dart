import 'package:dpos/core/domain/bootstrap_models.dart';
import 'package:dpos/core/domain/outlet_models.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/core/widgets/app_bottom_bar.dart';
import 'package:dpos/features/auth/data/auth_repository.dart';
import 'package:dpos/features/dashboard/presentation/widgets/owner_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../data/menu_category_repository.dart';
import '../../data/menu_repository.dart';
import '../../domain/menu_category_models.dart';
import '../../domain/menu_models.dart';

class MenuCategoryEditorScreen extends ConsumerStatefulWidget {
  const MenuCategoryEditorScreen({super.key, this.initialCategory});

  final MenuCatalogCategory? initialCategory;

  @override
  ConsumerState<MenuCategoryEditorScreen> createState() =>
      _MenuCategoryEditorScreenState();
}

class _MenuCategoryEditorScreenState
    extends ConsumerState<MenuCategoryEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  late bool _isVisibleInAllOutlets;
  late Set<String> _selectedOutletIds;
  late int _selectedVisualIndex;
  bool _tampilDiPOS = true;
  String? _outletErrorText;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final cat = widget.initialCategory;
    _nameController = TextEditingController(text: cat?.name ?? '');
    _isVisibleInAllOutlets = cat?.isVisibleInAllOutlets ?? false;
    _selectedOutletIds = {...?cat?.visibleOutletIds};
    _selectedVisualIndex = cat?.visualIndex ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await ref.read(authRepositoryProvider).signOut();
      if (!context.mounted) return;
      context.goNamed(RouteNames.login);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout gagal: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 760;
    final bootstrapAsync = ref.watch(homeBootstrapProvider);
    final menuItemsAsync = ref.watch(menuItemsProvider);
    final menuItems = menuItemsAsync.value ?? const <MenuItem>[];

    final bootstrap = bootstrapAsync.value;
    final outlets = _activeOutletsFromBootstrap(bootstrap);
    final isEditing = widget.initialCategory != null;

    if (_isVisibleInAllOutlets && _selectedOutletIds.isEmpty) {
      _selectedOutletIds = outlets.map((o) => o.id).toSet();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: bootstrap != null
          ? OwnerDrawer(
              bootstrap: bootstrap,
              onLogout: () => _handleLogout(context),
            )
          : null,
      body: SafeArea(
        child: isTablet
            ? _buildTabletView(
                context,
                bootstrap: bootstrap,
                outlets: outlets,
                menuItems: menuItems,
                isEditing: isEditing,
              )
            : _buildMobileView(
                context,
                bootstrap: bootstrap,
                outlets: outlets,
                menuItems: menuItems,
                isEditing: isEditing,
              ),
      ),
      bottomNavigationBar: !isTablet
          ? AppBottomBar(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFFF1F5F9),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => _submit(bootstrap, outlets),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB45309),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isEditing ? 'Simpan' : '+ Tambah',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  List<Outlet> _activeOutletsFromBootstrap(OwnerBootstrap? bootstrap) {
    if (bootstrap == null) return const [];
    return bootstrap.outlets.where((o) => o.isActive).toList();
  }

  // =========================================================================
  // TABLET VIEW (CLEAN, PAKAI SIDEBAR BAWAAN / DRAWER)
  // =========================================================================

  Widget _buildTabletView(
    BuildContext context, {
    required OwnerBootstrap? bootstrap,
    required List<Outlet> outlets,
    required List<MenuItem> menuItems,
    required bool isEditing,
  }) {
    return Column(
      children: [
        // Tablet Top Bar: Back, Breadcrumb, Online Sync, Avatar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              // 1. Sidebar Bawaan Menu Icon
              Builder(
                builder: (scaffoldContext) => InkWell(
                  onTap: () => Scaffold.of(scaffoldContext).openDrawer(),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.menu_rounded,
                      size: 20,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Icon Back
              InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // 3. Title & Breadcrumb
              InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                child: const Text(
                  'Kategori Produk',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
              ),
              Text(
                isEditing ? 'Edit Kategori' : 'Tambah Kategori Baru',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),

              // Right side: Online Sync
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
                    SizedBox(width: 6),
                    Text(
                      'Online Sync',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Centered Form Card
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top grey pill indicator
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Title & POS CONFIG Badge
                        Row(
                          children: [
                            Text(
                              isEditing ? 'Edit Kategori' : 'Tambah Kategori',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFDBEAFE),
                                ),
                              ),
                              child: const Text(
                                'POS CONFIG',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2563EB),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Atur nama kategori dan outlet mana yang boleh menampilkannya. Jumlah produk akan dihitung otomatis dari item menu.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Form content shared
                        _buildFormFields(
                          context,
                          outlets: outlets,
                          isTablet: true,
                        ),

                        const SizedBox(height: 28),

                        // Bottom Buttons: Batal & Tambah
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 14,
                                ),
                                backgroundColor: const Color(0xFFF1F5F9),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Batal',
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _submit(bootstrap, outlets),
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.add,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                              label: Text(
                                isEditing
                                    ? 'Simpan Kategori'
                                    : 'Tambah Kategori',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF97316),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // MOBILE VIEW
  // =========================================================================

  Widget _buildMobileView(
    BuildContext context, {
    required OwnerBootstrap? bootstrap,
    required List<Outlet> outlets,
    required List<MenuItem> menuItems,
    required bool isEditing,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Mobile Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Color(0xFF0F172A),
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Edit Kategori' : 'Tambah Kategori',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'POS Management',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          // Body Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges: POS CONFIG & Cloud Sync Ready
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 6,
                              color: Color(0xFF2563EB),
                            ),
                            SizedBox(width: 5),
                            Text(
                              'POS CONFIG',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Row(
                        children: [
                          Icon(
                            Icons.sync_rounded,
                            size: 14,
                            color: Color(0xFF475569),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Cloud Sync Ready',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'Atur nama kategori dan outlet mana yang boleh menampilkannya. Jumlah produk akan dihitung otomatis dari item menu.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Shared Form Content
                  _buildFormFields(context, outlets: outlets, isTablet: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SHARED FORM FIELDS
  // =========================================================================

  Widget _buildFormFields(
    BuildContext context, {
    required List<Outlet> outlets,
    required bool isTablet,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name Field & Counter
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Nama Kategori *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              '${_nameController.text.length}/40 Karakter',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextFormField(
            controller: _nameController,
            maxLength: 40,
            decoration: const InputDecoration(
              hintText: 'e.g. Makanan, Minuman, Snack',
              hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              counterText: '',
              suffixIcon: Icon(
                Icons.local_offer_outlined,
                size: 20,
                color: Color(0xFF94A3B8),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            onChanged: (val) => setState(() {}),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama kategori wajib diisi.';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),

        // Quick Icon Selector
        const Text(
          'Pilihan Ikon Cepat',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildQuickIconCard(
                index: 0,
                label: 'Makanan',
                icon: Icons.restaurant_rounded,
                selectedColor: const Color(0xFFD97706),
                selectedBg: const Color(0xFFFEF3C7),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickIconCard(
                index: 1,
                label: 'Minuman',
                icon: Icons.local_cafe_rounded,
                selectedColor: const Color(0xFF0284C7),
                selectedBg: const Color(0xFFE0F2FE),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickIconCard(
                index: 2,
                label: 'Camilan',
                icon: Icons.cookie_outlined,
                selectedColor: const Color(0xFF9333EA),
                selectedBg: const Color(0xFFF3E8FF),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickIconCard(
                index: 3,
                label: 'Retail',
                icon: Icons.storefront_outlined,
                selectedColor: const Color(0xFF059669),
                selectedBg: const Color(0xFFD1FAE5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Green Info Notice Container
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Jumlah produk akan mengikuti item menu yang memakai kategori ini secara otomatis saat katalog disimpan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF166534),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Outlet Scope Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Ketersediaan Outlet',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Multi-branch',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
            const Text(
              'Replikasi Data',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Segmented Tab Selector
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isVisibleInAllOutlets = true;
                      _outletErrorText = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _isVisibleInAllOutlets
                          ? const Color(0xFFFEF3C7)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _isVisibleInAllOutlets
                          ? '✓ Semua Outlet'
                          : 'Semua Outlet',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _isVisibleInAllOutlets
                            ? const Color(0xFF92400E)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isVisibleInAllOutlets = false;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_isVisibleInAllOutlets
                          ? const Color(0xFFFEF3C7)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      !_isVisibleInAllOutlets
                          ? '✓ Outlet Tertentu'
                          : 'Outlet Tertentu',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: !_isVisibleInAllOutlets
                            ? const Color(0xFF92400E)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Outlet Selection Card (When Outlet Tertentu selected)
        if (!_isVisibleInAllOutlets)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pilih outlet yang boleh menggunakan kategori ini:',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (_selectedOutletIds.length == outlets.length) {
                            _selectedOutletIds.clear();
                          } else {
                            _selectedOutletIds = outlets
                                .map((o) => o.id)
                                .toSet();
                          }
                          _outletErrorText = null;
                        });
                      },
                      child: Text(
                        _selectedOutletIds.length == outlets.length
                            ? 'Batal Pilih'
                            : 'Pilih Semua',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Outlets list
                for (int i = 0; i < outlets.length; i++) ...[
                  _buildOutletItemCard(outlets[i], isMain: i == 0),
                  const SizedBox(height: 8),
                ],

                if (_outletErrorText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _outletErrorText!,
                    style: const TextStyle(
                      color: Color(0xFFC62828),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_selectedOutletIds.length} dari ${outlets.length} outlet aktif dipilih',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Siap replikasi',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Tampilkan di katalog kasir POS toggle card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.visibility_outlined,
                  size: 20,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tampilkan di katalog kasir POS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Kategori akan langsung muncul pada grid terminal kasir aktif',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _tampilDiPOS,
                activeColor: const Color(0xFF005ECC),
                onChanged: (val) => setState(() => _tampilDiPOS = val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickIconCard({
    required int index,
    required String label,
    required IconData icon,
    required Color selectedColor,
    required Color selectedBg,
  }) {
    final isSelected = _selectedVisualIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedVisualIndex = index;
          if (_nameController.text.trim().isEmpty) {
            _nameController.text = label;
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? selectedColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? selectedColor : const Color(0xFF64748B),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? selectedColor : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutletItemCard(Outlet outlet, {bool isMain = false}) {
    final isChecked = _selectedOutletIds.contains(outlet.id);

    return InkWell(
      onTap: () {
        setState(() {
          if (isChecked) {
            _selectedOutletIds.remove(outlet.id);
          } else {
            _selectedOutletIds.add(outlet.id);
          }
          _outletErrorText = null;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isChecked
                ? const Color(0xFFFDE68A)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Color(0xFF2563EB),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        outlet.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (isMain) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF451A03),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'MAIN',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    outlet.code != null && outlet.code!.isNotEmpty
                        ? '${outlet.code} • Outlet Aktif'
                        : 'Sesi Terminal • Siap sinkron',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: isChecked,
              activeColor: const Color(0xFF005ECC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedOutletIds.add(outlet.id);
                  } else {
                    _selectedOutletIds.remove(outlet.id);
                  }
                  _outletErrorText = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SUBMIT HANDLER
  // =========================================================================

  Future<void> _submit(OwnerBootstrap? bootstrap, List<Outlet> outlets) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isVisibleInAllOutlets &&
        outlets.isNotEmpty &&
        _selectedOutletIds.isEmpty) {
      setState(() {
        _outletErrorText = 'Pilih minimal satu outlet.';
      });
      return;
    }

    final businessId = bootstrap?.business?.id;
    if (businessId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data bisnis belum tersedia.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final initialCategory = widget.initialCategory;
      final nextCategory = MenuCatalogCategory(
        id: initialCategory?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        visualIndex: _selectedVisualIndex,
        businessId: initialCategory?.businessId ?? businessId,
        isVisibleInAllOutlets: _isVisibleInAllOutlets,
        visibleOutletIds: _isVisibleInAllOutlets
            ? const []
            : _selectedOutletIds.toList(),
      );

      await ref
          .read(menuCategoriesProvider.notifier)
          .upsertCategory(nextCategory);

      if (!mounted) return;

      final currentState = ref.read(menuCategoriesProvider);
      if (currentState.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan kategori: ${currentState.error}'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      Navigator.of(context).maybePop(nextCategory);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            initialCategory == null
                ? 'Kategori baru berhasil ditambahkan.'
                : 'Kategori berhasil diperbarui.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }
}
