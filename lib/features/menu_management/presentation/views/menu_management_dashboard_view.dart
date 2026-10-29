import 'package:flutter/material.dart';
import 'package:dpos/features/auth/domain/auth_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dpos/features/menu_management/data/menu_category_repository.dart';
import 'package:dpos/features/menu_management/data/menu_repository.dart';
import 'package:dpos/features/menu_management/domain/menu_category_models.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';

class MenuManagementDashboardView extends ConsumerWidget {
  const MenuManagementDashboardView({
    super.key,
    this.padding,
    required this.profile,
    required this.onNavigateToCategories,
    required this.onNavigateToItems,
    required this.onNavigateToPrices,
    required this.onNavigateToDiscounts,
    required this.onNavigateToRecipes,
  });

  final EdgeInsetsGeometry? padding;
  final AppProfile? profile;
  final VoidCallback onNavigateToCategories;
  final VoidCallback onNavigateToItems;
  final VoidCallback onNavigateToPrices;
  final VoidCallback onNavigateToDiscounts;
  final VoidCallback onNavigateToRecipes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final firstName = profile?.fullName?.split(' ').first ?? 'User';
    final menuItemsAsync = ref.watch(menuItemsProvider);
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final totalItems = menuItemsAsync.valueOrNull?.length ?? 0;
    final outOfStockItems = _countOutOfStockItems(menuItemsAsync.valueOrNull);
    final readyToSellItems = _countReadyToSellItems(menuItemsAsync.valueOrNull);
    final totalCategories = categoriesAsync.valueOrNull?.length ?? 0;
    final visibleCategories = _countVisibleCategories(
      categoriesAsync.valueOrNull,
    );

    final totalItemsValue = _resolveStatValue(menuItemsAsync, totalItems);
    final outOfStockValue = _resolveStatValue(menuItemsAsync, outOfStockItems);
    final categoriesValue = _resolveStatValue(categoriesAsync, totalCategories);

    final totalItemsSubtitle = _resolveSubtitle(
      asyncValue: menuItemsAsync,
      ready: '$readyToSellItems siap jual',
      empty: 'Belum ada item',
      error: 'Gagal memuat',
    );
    final outOfStockSubtitle = _resolveSubtitle(
      asyncValue: menuItemsAsync,
      ready: outOfStockItems == 0 ? 'Stok aman' : 'Perlu restock',
      empty: 'Belum ada item',
      error: 'Gagal memuat',
    );
    final categoriesSubtitle = _resolveSubtitle(
      asyncValue: categoriesAsync,
      ready: '$visibleCategories tampil di outlet',
      empty: 'Belum ada kategori',
      error: 'Gagal memuat',
    );

    return ListView(
      padding: padding ?? EdgeInsets.zero,
      children: [
        // 1. Welcome Card
        _WelcomeCard(name: firstName),
        const SizedBox(height: 24),

        // 2. Full Row Stats (No Scroll, merata)
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'TOTAL ITEM',
                value: totalItemsValue,
                subtitle: totalItemsSubtitle,
                icon: Icons.inventory_2_rounded,
                color: const Color(0xFF00897B),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                title: 'ITEM HABIS',
                value: outOfStockValue,
                subtitle: outOfStockSubtitle,
                icon: Icons.error_outline_rounded,
                color: const Color(0xFFE53935),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                title: 'TOTAL KATEGORI',
                value: categoriesValue,
                subtitle: categoriesSubtitle,
                icon: Icons.category_rounded,
                color: const Color(0xFF7E57C2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // 3. Section Header
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manajemen Operasional',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Kelola menu dan konfigurasi harga dengan presisi',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 4. Grid Actions (Kategori, Item, Harga, Discount)
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final maxWidth = constraints.maxWidth;
            final columnCount = maxWidth >= 1080
                ? 3
                : maxWidth >= 720
                ? 2
                : 1;
            final cardWidth =
                (maxWidth - (spacing * (columnCount - 1))) / columnCount;

            Widget buildCard({
              required String title,
              required String subtitle,
              required IconData icon,
              required Color color,
              required VoidCallback onTap,
            }) {
              return SizedBox(
                width: cardWidth,
                child: _ActionCard(
                  title: title,
                  subtitle: subtitle,
                  icon: icon,
                  iconColor: color,
                  onTap: onTap,
                ),
              );
            }

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                buildCard(
                  title: 'Kategori Produk',
                  subtitle:
                      'Kelola kelompok makanan, minuman, dan dessert per outlet.',
                  icon: Icons.category_rounded,
                  color: const Color(0xFF00897B),
                  onTap: onNavigateToCategories,
                ),
                buildCard(
                  title: 'Daftar Produk',
                  subtitle:
                      'Atur nama menu, deskripsi, stok, dan visibilitas jual.',
                  icon: Icons.restaurant_menu_rounded,
                  color: const Color(0xFF1565C0),
                  onTap: onNavigateToItems,
                ),
                // buildCard(
                //   title: 'Harga & Promo',
                //   subtitle: 'Konfigurasi skema harga bertingkat...',
                //   icon: Icons.price_change_rounded,
                //   color: const Color(0xFF7E57C2),
                //   onTap: onNavigateToPrices,
                // ),
                buildCard(
                  title: 'Discount',
                  subtitle:
                      'Kelola discount percentage, maksimal potongan, atau rupiah langsung.',
                  icon: Icons.local_offer_rounded,
                  color: const Color(0xFF5E35B1),
                  onTap: onNavigateToDiscounts,
                ),
                buildCard(
                  title: 'Resep & HPP (BOM)',
                  subtitle:
                      'Hitung Food Cost Percentage otomatis berdasarkan takaran bahan baku & harga supplier.',
                  icon: Icons.receipt_long_rounded,
                  color: const Color(0xFFE53935),
                  onTap: onNavigateToRecipes,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),

        const SizedBox(height: 12),
      ],
    );
  }
}

String _resolveStatValue<T>(AsyncValue<T> asyncValue, int value) {
  if (asyncValue.isLoading && asyncValue.valueOrNull == null) {
    return '...';
  }
  if (asyncValue.hasError && asyncValue.valueOrNull == null) {
    return '--';
  }
  return '$value';
}

String _resolveSubtitle<T>({
  required AsyncValue<T> asyncValue,
  required String ready,
  required String empty,
  required String error,
}) {
  final value = asyncValue.valueOrNull;
  if (asyncValue.isLoading && value == null) {
    return 'Memuat data';
  }
  if (asyncValue.hasError && value == null) {
    return error;
  }
  if (value is List && value.isEmpty) {
    return empty;
  }
  return ready;
}

int _countReadyToSellItems(List<MenuItem>? items) {
  if (items == null) {
    return 0;
  }
  return items.where((item) => item.isSellable).length;
}

int _countOutOfStockItems(List<MenuItem>? items) {
  if (items == null) {
    return 0;
  }

  var total = 0;
  for (final item in items) {
    if (!item.stockAvailable) {
      continue;
    }
    if (item.trackStockQuantity && item.stockQuantity <= 0) {
      total++;
      continue;
    }
    if (item.variants.isNotEmpty &&
        !item.variants.any((variant) => variant.stockAvailable)) {
      total++;
    }
  }
  return total;
}

int _countVisibleCategories(List<MenuCatalogCategory>? categories) {
  if (categories == null) {
    return 0;
  }
  return categories
      .where(
        (category) =>
            category.isVisibleInAllOutlets ||
            category.visibleOutletIds.isNotEmpty,
      )
      .length;
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF009688), Color(0xFF26A69A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good morning, $name!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ready to optimize your kitchen\'s menu today? Your current menu efficiency is up by 12%.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 9),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.62),
                            fontSize: 11,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurface.withValues(alpha: 0.2),
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
