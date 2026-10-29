import 'package:dpos/core/domain/bootstrap_models.dart';
import 'package:dpos/core/domain/outlet_models.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/core/widgets/app_bottom_bar.dart';
import 'package:dpos/features/auth/data/auth_repository.dart';
import 'package:dpos/features/dashboard/presentation/widgets/owner_drawer.dart';
import 'package:go_router/go_router.dart';
import 'menu_category_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/menu_repository.dart';
import '../../data/menu_category_repository.dart';
import '../../domain/menu_category_models.dart';
import '../../domain/menu_models.dart';

class MenuCategoryManagementScreen extends ConsumerStatefulWidget {
  const MenuCategoryManagementScreen({super.key});

  @override
  ConsumerState<MenuCategoryManagementScreen> createState() =>
      _MenuCategoryManagementScreenState();
}

class _MenuCategoryManagementScreenState
    extends ConsumerState<MenuCategoryManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilterTab = 'all'; // 'all', 'global', 'specific'
  final Map<String, bool> _posActiveState = {};
  DateTime _lastSyncTime = DateTime.now();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
      if (!mounted) return;
      context.goNamed(RouteNames.login);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout gagal: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 760;
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final bootstrapAsync = ref.watch(homeBootstrapProvider);
    final canManageMenu = ref.watch(canManageCatalogProvider);
    final menuItemsAsync = ref.watch(menuItemsProvider);
    final menuItems = menuItemsAsync.value ?? const <MenuItem>[];

    final bootstrap = bootstrapAsync.value;
    final storeName = bootstrap?.business?.name ?? 'Toko Kelontong Berkah';
    final outlets = _activeOutletsFromBootstrap(bootstrap);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: bootstrap != null
          ? OwnerDrawer(bootstrap: bootstrap, onLogout: _handleLogout)
          : null,
      appBar: !isTablet
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF0F172A),
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              centerTitle: true,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Kategori Produk',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    storeName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          : null,
      body: SafeArea(
        child: bootstrapAsync.when(
          data: (_) {
            return categoriesAsync.when(
              data: (categoryList) {
                final filteredList = categoryList.where((cat) {
                  if (_searchQuery.isNotEmpty) {
                    if (!cat.name.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    )) {
                      return false;
                    }
                  }
                  if (isTablet) {
                    if (_selectedFilterTab == 'global' &&
                        !cat.isVisibleInAllOutlets) {
                      return false;
                    }
                    if (_selectedFilterTab == 'specific' &&
                        cat.isVisibleInAllOutlets) {
                      return false;
                    }
                  }
                  return true;
                }).toList();

                return isTablet
                    ? _buildTabletLayout(
                        context,
                        allCategories: categoryList,
                        filteredCategories: filteredList,
                        outlets: outlets,
                        menuItems: menuItems,
                        storeName: storeName,
                        canManageMenu: canManageMenu,
                      )
                    : _buildMobileLayout(
                        context,
                        allCategories: categoryList,
                        filteredCategories: filteredList,
                        outlets: outlets,
                        menuItems: menuItems,
                        canManageMenu: canManageMenu,
                      );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFFF97316)),
              ),
              error: (error, _) =>
                  Center(child: Text('Gagal memuat kategori: $error')),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFF97316)),
          ),
          error: (error, _) =>
              Center(child: Text('Gagal memuat outlet: $error')),
        ),
      ),
      bottomNavigationBar: !isTablet && canManageMenu
          ? AppBottomBar(
              child: ElevatedButton.icon(
                onPressed: () => _openCategoryEditor(),
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                label: const Text(
                  '+ Tambah Kategori Baru',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            )
          : null,
    );
  }

  List<Outlet> _activeOutletsFromBootstrap(OwnerBootstrap? bootstrap) {
    if (bootstrap == null) {
      return const [];
    }
    return bootstrap.outlets.where((outlet) => outlet.isActive).toList();
  }

  int _productCountForCategory(
    MenuCatalogCategory category,
    List<MenuItem> menuItems,
  ) {
    return menuItems.where((item) => item.categoryId == category.id).length;
  }

  String _skuSummaryForCategory(
    MenuCatalogCategory category,
    List<MenuItem> menuItems,
  ) {
    final categoryItems = menuItems
        .where((i) => i.categoryId == category.id)
        .toList();
    final skus = categoryItems
        .map((i) => i.sku)
        .where((s) => s != null && s.trim().isNotEmpty)
        .toList();

    if (skus.isEmpty) {
      return 'SKU: ${100 + category.visualIndex * 10}-${100 + category.visualIndex * 10 + categoryItems.length}';
    }
    if (skus.length == 1) {
      return 'SKU: ${skus.first}';
    }
    return 'SKU: ${skus.first}-${skus.last}';
  }

  // =========================================================================
  // MOBILE LAYOUT
  // =========================================================================

  Widget _buildMobileLayout(
    BuildContext context, {
    required List<MenuCatalogCategory> allCategories,
    required List<MenuCatalogCategory> filteredCategories,
    required List<Outlet> outlets,
    required List<MenuItem> menuItems,
    required bool canManageMenu,
  }) {
    final totalCategories = allCategories.length;
    final globalCategories = allCategories
        .where((c) => c.isVisibleInAllOutlets)
        .length;
    final specificCategories = allCategories
        .where((c) => !c.isVisibleInAllOutlets)
        .length;

    final specificOutletsCovered = allCategories
        .where((c) => !c.isVisibleInAllOutlets)
        .expand((c) => c.visibleOutletIds)
        .toSet()
        .length;
    final totalOutlets = outlets.length;

    return Column(
      children: [
        // Search Input
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari kategori produk...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
        ),

        // Scrollable content
        Expanded(
          child: filteredCategories.isEmpty && _searchQuery.isNotEmpty
              ? const Center(
                  child: Text(
                    'Tidak ada kategori yang cocok dengan pencarian.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                )
              : allCategories.isEmpty
              ? const _EmptyCategoryState()
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  header: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 3 Metric Summary Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildMobileSummaryCard(
                              label: 'TOTAL',
                              count: '$totalCategories',
                              subtext: 'Total Kategori',
                              labelColor: const Color(0xFF64748B),
                              countColor: const Color(0xFF0F172A),
                              icon: Icons.format_list_bulleted_rounded,
                              iconBgColor: const Color(0xFFF1F5F9),
                              iconColor: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMobileSummaryCard(
                              label: 'GLOBAL',
                              count: '$globalCategories',
                              subtext: 'Semua Outlet',
                              labelColor: const Color(0xFF16A34A),
                              countColor: const Color(0xFF16A34A),
                              icon: Icons.bar_chart_rounded,
                              iconBgColor: const Color(0xFFDCFCE7),
                              iconColor: const Color(0xFF16A34A),
                              bgDecorationColor: const Color(0xFFF0FDF4),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMobileSummaryCard(
                              label: 'KHUSUS',
                              count: '$specificCategories',
                              extraCount:
                                  ' ($specificOutletsCovered/$totalOutlets)',
                              subtext: 'Outlet Khusus',
                              labelColor: const Color(0xFFEA580C),
                              countColor: const Color(0xFFEA580C),
                              icon: Icons.location_on_outlined,
                              iconBgColor: const Color(0xFFFEF3C7),
                              iconColor: const Color(0xFFD97706),
                              bgDecorationColor: const Color(0xFFFFFBEB),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Blue Info Outlet Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFDBEAFE),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: RichText(
                                text: const TextSpan(
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1E3A8A),
                                    height: 1.35,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Info Outlet: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(text: 'Kategori dengan label '),
                                    TextSpan(
                                      text: 'Semua Outlet',
                                      style: TextStyle(
                                        color: Color(0xFF16A34A),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          ' otomatis sinkron di seluruh cabang kasir toko Anda.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'DAFTAR KATEGORI AKTIF',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF475569),
                              letterSpacing: 0.6,
                            ),
                          ),
                          Row(
                            children: const [
                              Icon(
                                Icons.swap_vert_rounded,
                                size: 16,
                                color: Color(0xFF94A3B8),
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Tahan titik untuk urutan',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                  itemCount: filteredCategories.length,
                  onReorder: canManageMenu
                      ? (oldIndex, newIndex) {
                          ref
                              .read(menuCategoriesProvider.notifier)
                              .reorderCategory(oldIndex, newIndex);
                        }
                      : (_, __) {},
                  itemBuilder: (context, index) {
                    final category = filteredCategories[index];
                    final productCount = _productCountForCategory(
                      category,
                      menuItems,
                    );

                    return Padding(
                      key: ValueKey(category.id),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildMobileCategoryCard(
                        context,
                        index: index,
                        category: category,
                        productCount: productCount,
                        outlets: outlets,
                        canManageMenu: canManageMenu,
                        allCategories: allCategories,
                      ),
                    );
                  },
                ),
        ),

        // Footer Note
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            'Semua pengaturan cabang tersinkronisasi otomatis dengan cloud Mangga POS.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileSummaryCard({
    required String label,
    required String count,
    String? extraCount,
    required String subtext,
    required Color labelColor,
    required Color countColor,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    Color? bgDecorationColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (bgDecorationColor != null)
            Positioned(
              right: -10,
              bottom: -10,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: bgDecorationColor.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: labelColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 14, color: iconColor),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    count,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: countColor,
                      height: 1.0,
                    ),
                  ),
                  if (extraCount != null)
                    Text(
                      extraCount,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtext,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCategoryCard(
    BuildContext context, {
    required int index,
    required MenuCatalogCategory category,
    required int productCount,
    required List<Outlet> outlets,
    required bool canManageMenu,
    required List<MenuCatalogCategory> allCategories,
  }) {
    final isSpecific = !category.isVisibleInAllOutlets;
    final themeInfo = _CategoryTheme.forCategory(
      category.name,
      category.visualIndex,
    );

    final visibleOutlets = outlets
        .where((o) => category.visibleOutletIds.contains(o.id))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSpecific ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
          width: isSpecific ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Drag handle
                if (canManageMenu)
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: Color(0xFFCBD5E1),
                        size: 22,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 4),

                // Category Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: themeInfo.backgroundColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    themeInfo.icon,
                    color: themeInfo.iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                // Name & details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$productCount Produk',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      if (category.isVisibleInAllOutlets)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFBBF7D0),
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bar_chart_rounded,
                                size: 12,
                                color: Color(0xFF16A34A),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Semua Outlet',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFFDE68A),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: Color(0xFFD97706),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${category.visibleOutletIds.length} Outlet Tertentu',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Edit & Delete actions
                if (canManageMenu)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: Color(0xFF64748B),
                        ),
                        onPressed: () =>
                            _openCategoryEditor(initialCategory: category),
                        visualDensity: VisualDensity.compact,
                        splashRadius: 20,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: Color(0xFFEF4444),
                        ),
                        onPressed: () =>
                            _confirmDeleteCategory(category: category),
                        visualDensity: VisualDensity.compact,
                        splashRadius: 20,
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // For Outlet Khusus: Show CABANG list & + Edit Outlet
          if (isSpecific) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  const Text(
                    'CABANG:',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final outlet in visibleOutlets)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  outlet.name,
                                  style: const TextStyle(
                                    fontSize: 10,
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
                  InkWell(
                    onTap: () => _openCategoryEditor(initialCategory: category),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        '+ Edit Outlet',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // TABLET LAYOUT
  // =========================================================================

  Widget _buildTabletLayout(
    BuildContext context, {
    required List<MenuCatalogCategory> allCategories,
    required List<MenuCatalogCategory> filteredCategories,
    required List<Outlet> outlets,
    required List<MenuItem> menuItems,
    required String storeName,
    required bool canManageMenu,
  }) {
    final totalCategories = allCategories.length;
    final globalCategories = allCategories
        .where((c) => c.isVisibleInAllOutlets)
        .length;
    final specificCategories = allCategories
        .where((c) => !c.isVisibleInAllOutlets)
        .length;

    final specificOutletsCovered = allCategories
        .where((c) => !c.isVisibleInAllOutlets)
        .expand((c) => c.visibleOutletIds)
        .toSet()
        .length;
    final totalOutlets = outlets.length;
    final outletNames = outlets.map((o) => o.name).toList();
    final outletSummary = outletNames.isEmpty
        ? 'Semua cabang toko'
        : outletNames.take(3).join(', ') +
              (outletNames.length > 3
                  ? ' & ${outletNames.length - 3} lainnya'
                  : '');

    final timeStr = DateFormat('HH:mm').format(_lastSyncTime);

    return Column(
      children: [
        // Top Tablet Navigation Bar
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          color: Colors.white,
          child: Row(
            children: [
              // 1. Sidebar Bawaan Menu Icon
              Builder(
                builder: (scaffoldContext) => InkWell(
                  onTap: () => Scaffold.of(scaffoldContext).openDrawer(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.menu_rounded,
                      color: Color(0xFF0F172A),
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Tombol Back
              InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Color(0xFF0F172A),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Kategori Produk',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Mangga POS',
                              style: TextStyle(
                                color: Color(0xFF16A34A),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$storeName • Mode Kasir Tablet',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              // Search input
              SizedBox(
                width: 310,
                height: 42,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Cari kategori produk (tekan '/' untuk cari)",
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 12,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 14),
              // + Tambah Kategori Baru Button
              if (canManageMenu)
                ElevatedButton.icon(
                  onPressed: () => _openCategoryEditor(),
                  icon: const Icon(Icons.add, size: 18, color: Colors.white),
                  label: const Text(
                    '+ Tambah Kategori Baru',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
            ],
          ),
        ),

        // Scrollable Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter tabs & Drag reorder hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildFilterTabItem(
                          label: 'Semua ($totalCategories)',
                          selected: _selectedFilterTab == 'all',
                          onTap: () =>
                              setState(() => _selectedFilterTab = 'all'),
                        ),
                        const SizedBox(width: 10),
                        _buildFilterTabItem(
                          label: 'Semua Outlet ($globalCategories)',
                          selected: _selectedFilterTab == 'global',
                          onTap: () =>
                              setState(() => _selectedFilterTab = 'global'),
                        ),
                        const SizedBox(width: 10),
                        _buildFilterTabItem(
                          label: 'Outlet Khusus ($specificCategories)',
                          selected: _selectedFilterTab == 'specific',
                          onTap: () =>
                              setState(() => _selectedFilterTab = 'specific'),
                        ),
                      ],
                    ),
                    const Row(
                      children: [
                        Icon(
                          Icons.swap_vert_rounded,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Drag pada titik grip untuk atur prioritas display kasir',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 3 Wide Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildTabletSummaryCard(
                        title: 'TOTAL KATEGORI',
                        badgeText: 'Aktif',
                        badgeBgColor: const Color(0xFFF1F5F9),
                        badgeTextColor: const Color(0xFF475569),
                        count: '$totalCategories',
                        countLabel: 'Kategori terdaftar',
                        subtext:
                            'Total ${menuItems.length} varian item aktif di katalog',
                        icon: Icons.format_list_bulleted_rounded,
                        iconBgColor: const Color(0xFFF1F5F9),
                        iconColor: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTabletSummaryCard(
                        title: 'SINKRONISASI GLOBAL',
                        titleColor: const Color(0xFF16A34A),
                        badgeText: '100% Sync',
                        badgeBgColor: const Color(0xFFDCFCE7),
                        badgeTextColor: const Color(0xFF16A34A),
                        count: '$globalCategories',
                        countColor: const Color(0xFF16A34A),
                        countLabel: 'Kategori (Semua Outlet)',
                        subtext: 'Otomatis muncul di $outletSummary',
                        icon: Icons.cloud_upload_outlined,
                        iconBgColor: const Color(0xFFDCFCE7),
                        iconColor: const Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTabletSummaryCard(
                        title: 'DISTRIBUSI KHUSUS',
                        titleColor: const Color(0xFFEA580C),
                        badgeText:
                            '$specificOutletsCovered/$totalOutlets Cabang',
                        badgeBgColor: const Color(0xFFFEF3C7),
                        badgeTextColor: const Color(0xFFD97706),
                        count: '$specificCategories',
                        countColor: const Color(0xFFEA580C),
                        countLabel: 'Kategori (Outlet Tertentu)',
                        subtext: 'Hanya ditugaskan ke cabang promosi aktif',
                        icon: Icons.location_on_outlined,
                        iconBgColor: const Color(0xFFFEF3C7),
                        iconColor: const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Guide Alert Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFDBEAFE),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1E3A8A),
                            ),
                            children: [
                              TextSpan(
                                text: 'Panduan Kasir Tablet: ',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              TextSpan(
                                text:
                                    'Perubahan ketersediaan outlet otomatis dipublikasikan ke semua mesin kasir tablet dalam kurun < 5 detik tanpa perlu me-restart sesi kasir.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () => _showOutletStatusSheet(context, outlets),
                        child: Text(
                          'Lihat Status Kasir ($totalOutlets Aktif)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daftar Kategori Produk (${filteredCategories.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      'Urutan tampilan kasir: Kiri Atas ke Kanan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 2-Column Grid of Category Cards
                if (filteredCategories.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    child: const Text(
                      'Tidak ada kategori yang ditemukan.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  )
                else
                  _buildTabletCardsGrid(
                    context,
                    filteredCategories: filteredCategories,
                    allCategories: allCategories,
                    outlets: outlets,
                    menuItems: menuItems,
                    canManageMenu: canManageMenu,
                  ),
              ],
            ),
          ),
        ),

        // Bottom Tablet Status Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Semua pengaturan cabang tersinkronisasi otomatis dengan cloud Mangga POS tablet.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const Spacer(),
              Text(
                'Sinkronisasi terakhir: Baru saja ($timeStr WIB)',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('|', style: TextStyle(color: Color(0xFFCBD5E1))),
              ),
              InkWell(
                onTap: () async {
                  setState(() => _lastSyncTime = DateTime.now());
                  ref.invalidate(menuCategoriesProvider);
                  ref.invalidate(homeBootstrapProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Katalog kategori berhasil disinkronkan.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Icon(
                      Icons.sync_rounded,
                      size: 16,
                      color: Color(0xFFEA580C),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Sync Sekarang',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTabItem({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildTabletSummaryCard({
    required String title,
    Color? titleColor,
    required String badgeText,
    required Color badgeBgColor,
    required Color badgeTextColor,
    required String count,
    Color? countColor,
    required String countLabel,
    required String subtext,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: titleColor ?? const Color(0xFF64748B),
                  letterSpacing: 0.6,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          count,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: countColor ?? const Color(0xFF0F172A),
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          countLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtext,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabletCardsGrid(
    BuildContext context, {
    required List<MenuCatalogCategory> filteredCategories,
    required List<MenuCatalogCategory> allCategories,
    required List<Outlet> outlets,
    required List<MenuItem> menuItems,
    required bool canManageMenu,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 16) / 2;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (int i = 0; i < filteredCategories.length; i++)
              SizedBox(
                width: cardWidth,
                child: DragTarget<int>(
                  onWillAcceptWithDetails: (details) => details.data != i,
                  onAcceptWithDetails: (details) {
                    final oldIndex = details.data;
                    ref
                        .read(menuCategoriesProvider.notifier)
                        .reorderCategory(oldIndex, i);
                  },
                  builder: (context, candidateData, rejectedData) {
                    final isHovered = candidateData.isNotEmpty;
                    final category = filteredCategories[i];
                    final productCount = _productCountForCategory(
                      category,
                      menuItems,
                    );
                    final skuSummary = _skuSummaryForCategory(
                      category,
                      menuItems,
                    );

                    final cardWidget = _buildTabletCategoryCard(
                      context,
                      category: category,
                      productCount: productCount,
                      skuSummary: skuSummary,
                      outlets: outlets,
                      canManageMenu: canManageMenu,
                      allCategories: allCategories,
                    );

                    if (!canManageMenu) {
                      return cardWidget;
                    }

                    return LongPressDraggable<int>(
                      data: i,
                      feedback: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(width: cardWidth, child: cardWidget),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.35,
                        child: cardWidget,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: isHovered
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFF97316,
                                    ).withValues(alpha: 0.3),
                                    blurRadius: 12,
                                  ),
                                ]
                              : null,
                        ),
                        child: cardWidget,
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTabletCategoryCard(
    BuildContext context, {
    required MenuCatalogCategory category,
    required int productCount,
    required String skuSummary,
    required List<Outlet> outlets,
    required bool canManageMenu,
    required List<MenuCatalogCategory> allCategories,
  }) {
    final isSpecific = !category.isVisibleInAllOutlets;
    final themeInfo = _CategoryTheme.forCategory(
      category.name,
      category.visualIndex,
    );
    final isPosActive = _posActiveState[category.id] ?? true;

    final visibleOutlets = outlets
        .where((o) => category.visibleOutletIds.contains(o.id))
        .toList();
    final totalOutlets = outlets.length;
    final progress = totalOutlets > 0
        ? (visibleOutlets.length / totalOutlets)
        : 0.0;
    final percentStr = (progress * 100).toInt();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSpecific ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
          width: isSpecific ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top right ribbon for specific distribution
          if (isSpecific)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFEA580C),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: const Text(
                  'DISTRIBUSI KHUSUS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Grip, Artwork, Name, Counts, Edit/Delete
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 8, right: 8),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: Color(0xFFCBD5E1),
                        size: 22,
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: themeInfo.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        themeInfo.icon,
                        color: themeInfo.iconColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$productCount Produk',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (isSpecific)
                                Text(
                                  '• ${visibleOutlets.length} dari $totalOutlets Outlet Aktif',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFEA580C),
                                  ),
                                )
                              else
                                Text(
                                  '• $skuSummary',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (canManageMenu)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 19,
                              color: Color(0xFF64748B),
                            ),
                            onPressed: () =>
                                _openCategoryEditor(initialCategory: category),
                            visualDensity: VisualDensity.compact,
                            splashRadius: 18,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 19,
                              color: Color(0xFFEF4444),
                            ),
                            onPressed: () =>
                                _confirmDeleteCategory(category: category),
                            visualDensity: VisualDensity.compact,
                            splashRadius: 18,
                          ),
                        ],
                      ),
                  ],
                ),

                // Middle section for Outlet Khusus
                if (isSpecific) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'OUTLET AKTIF (${visibleOutlets.length} CABANG):',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      if (canManageMenu)
                        InkWell(
                          onTap: () =>
                              _openCategoryEditor(initialCategory: category),
                          child: const Text(
                            '+ Atur Outlet',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEA580C),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Chips of active & non-active outlets
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final outlet in outlets)
                        if (category.visibleOutletIds.contains(outlet.id))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  outlet.name,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFF1F5F9),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFCBD5E1),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${outlet.name} (Nonaktif)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Progress bar
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: const Color(0xFFF1F5F9),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFF59E0B),
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$percentStr% Cabang',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                // Bottom row: Status chip, sync note, Tampil POS switch
                Row(
                  children: [
                    if (!isSpecific) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFBBF7D0),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Semua Outlet ($totalOutlets Cabang)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Sinkron otomatis',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Kategori promo terbatas',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                    const Spacer(),
                    const Text(
                      'Tampil POS:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch.adaptive(
                        value: isPosActive,
                        activeColor: const Color(0xFF10B981),
                        onChanged: (val) {
                          setState(() {
                            _posActiveState[category.id] = val;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                val
                                    ? '${category.name} diaktifkan di POS.'
                                    : '${category.name} dinonaktifkan di POS.',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOutletStatusSheet(BuildContext context, List<Outlet> outlets) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront_rounded, color: Color(0xFF2563EB)),
                const SizedBox(width: 10),
                Text(
                  'Status Kasir Outlet (${outlets.length} Aktif)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final outlet in outlets)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF16A34A),
                    size: 20,
                  ),
                ),
                title: Text(
                  outlet.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'ID: ${outlet.id.substring(0, 8)}... • POS Aktif',
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Online',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // ACTIONS: EDITOR & DELETE
  // =========================================================================

  Future<void> _openCategoryEditor({
    MenuCatalogCategory? initialCategory,
  }) async {
    if (!ref.read(canManageCatalogProvider)) {
      return;
    }

    await Navigator.of(context).push<MenuCatalogCategory>(
      MaterialPageRoute(
        builder: (context) =>
            MenuCategoryEditorScreen(initialCategory: initialCategory),
      ),
    );
  }

  Future<void> _confirmDeleteCategory({
    required MenuCatalogCategory category,
  }) async {
    if (!ref.read(canManageCatalogProvider)) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text(
          'Hapus kategori ${category.name}? Pengaturan outlet pada kategori ini juga akan ikut dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(menuCategoriesProvider.notifier).deleteCategory(category.id);

    if (!mounted) return;

    final currentState = ref.read(menuCategoriesProvider);
    if (currentState.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus kategori: ${currentState.error}'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${category.name} dihapus dari katalog.')),
    );
  }
}

class _CategoryTheme {
  const _CategoryTheme({
    required this.backgroundColor,
    required this.iconColor,
    required this.icon,
  });

  final Color backgroundColor;
  final Color iconColor;
  final IconData icon;

  static _CategoryTheme forCategory(String name, int visualIndex) {
    final lower = name.toLowerCase();
    if (lower.contains('makan') ||
        lower.contains('snack') ||
        lower.contains('food') ||
        lower.contains('roti')) {
      return const _CategoryTheme(
        backgroundColor: Color(0xFFFEF3C7),
        iconColor: Color(0xFFD97706),
        icon: Icons.restaurant_rounded,
      );
    }
    if (lower.contains('minum') ||
        lower.contains('kopi') ||
        lower.contains('coffee') ||
        lower.contains('drink') ||
        lower.contains('tea') ||
        lower.contains('teh') ||
        lower.contains('jus')) {
      return const _CategoryTheme(
        backgroundColor: Color(0xFFE0F2FE),
        iconColor: Color(0xFF0284C7),
        icon: Icons.local_cafe_rounded,
      );
    }
    if (lower.contains('sembako') ||
        lower.contains('retail') ||
        lower.contains('belanja') ||
        lower.contains('toko') ||
        lower.contains('barang')) {
      return const _CategoryTheme(
        backgroundColor: Color(0xFFD1FAE5),
        iconColor: Color(0xFF059669),
        icon: Icons.shopping_bag_outlined,
      );
    }
    if (lower.contains('paket') ||
        lower.contains('combo') ||
        lower.contains('hemat') ||
        lower.contains('promo') ||
        lower.contains('diskon')) {
      return const _CategoryTheme(
        backgroundColor: Color(0xFFF3E8FF),
        iconColor: Color(0xFF9333EA),
        icon: Icons.local_offer_outlined,
      );
    }

    const fallbacks = [
      _CategoryTheme(
        backgroundColor: Color(0xFFFEF3C7),
        iconColor: Color(0xFFD97706),
        icon: Icons.restaurant_rounded,
      ),
      _CategoryTheme(
        backgroundColor: Color(0xFFE0F2FE),
        iconColor: Color(0xFF0284C7),
        icon: Icons.local_cafe_rounded,
      ),
      _CategoryTheme(
        backgroundColor: Color(0xFFD1FAE5),
        iconColor: Color(0xFF059669),
        icon: Icons.shopping_bag_outlined,
      ),
      _CategoryTheme(
        backgroundColor: Color(0xFFF3E8FF),
        iconColor: Color(0xFF9333EA),
        icon: Icons.local_offer_outlined,
      ),
      _CategoryTheme(
        backgroundColor: Color(0xFFFFE4E6),
        iconColor: Color(0xFFE11D48),
        icon: Icons.cake_rounded,
      ),
    ];
    return fallbacks[visualIndex % fallbacks.length];
  }
}

class _EmptyCategoryState extends StatelessWidget {
  const _EmptyCategoryState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: Color(0xFFCBD5E1)),
            SizedBox(height: 16),
            Text(
              'Belum ada kategori',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Tambahkan kategori baru untuk mulai menyusun katalog per outlet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
