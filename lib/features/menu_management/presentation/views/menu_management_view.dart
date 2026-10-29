import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/features/auth/domain/auth_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'menu_management_dashboard_view.dart';

class MenuManagementView extends StatelessWidget {
  const MenuManagementView({super.key, this.padding, this.profile});

  final EdgeInsetsGeometry? padding;
  final AppProfile? profile;

  @override
  Widget build(BuildContext context) {
    return MenuManagementDashboardView(
      padding: padding,
      profile: profile,
      onNavigateToCategories: () =>
          context.pushNamed(RouteNames.menuCategoryManagement),
      onNavigateToItems: () =>
          context.pushNamed(RouteNames.productCatalogDashboard),
      onNavigateToPrices: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fitur Harga & Promo akan segera tersedia.'),
          ),
        );
      },
      onNavigateToDiscounts: () =>
          context.pushNamed(RouteNames.discountManagement),
      onNavigateToRecipes: () =>
          context.pushNamed(RouteNames.recipeManagement),
    );
  }
}
