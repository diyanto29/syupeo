import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:dpos/core/domain/business_template_models.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/features/auth/data/auth_repository.dart';
import 'package:dpos/features/auth/presentation/google_owner_sign_in_screen.dart';
import 'package:dpos/features/auth/presentation/owner_onboarding_screen.dart';
import 'package:dpos/features/auth/presentation/otp_verification_screen.dart';
import 'package:dpos/features/auth/presentation/splash_screen.dart';
import 'package:dpos/features/business_profile/presentation/business_profile_edit_screen.dart';
import 'package:dpos/features/dashboard/presentation/home_screen.dart';
import 'package:dpos/features/discount_management/presentation/views/discount_management_screen.dart';
import 'package:dpos/features/menu_management/presentation/views/menu_category_management_screen.dart';
import 'package:dpos/features/menu_management/presentation/views/menu_category_editor_screen.dart';
import 'package:dpos/features/menu_management/domain/menu_category_models.dart';
import 'package:dpos/core/domain/outlet_models.dart';
import 'package:dpos/features/outlet_management/presentation/outlet_picker_screen.dart';
import 'package:dpos/features/outlet_management/presentation/outlet_edit_screen.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:dpos/features/product_catalog/presentation/views/add_product_screen.dart';
import 'package:dpos/features/product_catalog/presentation/views/product_detail_screen.dart';
import 'package:dpos/features/product_catalog/presentation/views/product_dashboard_screen.dart';
import 'package:dpos/features/settings/presentation/views/payment_settings_screen.dart';
import 'package:dpos/features/settings/presentation/views/qris_settings_screen.dart';
import 'package:dpos/features/settings/presentation/views/printer_settings_screen.dart';
import 'package:dpos/features/settings/presentation/views/payment_notification_settings_screen.dart';
import 'package:dpos/features/settings/presentation/views/tax_settings_screen.dart';
import 'package:dpos/features/settings/presentation/views/order_type_settings_screen.dart';
import 'package:dpos/features/subscription/presentation/views/business_template_management_screen.dart';
import 'package:dpos/features/subscription/presentation/views/business_template_edit_screen.dart';
import 'package:dpos/features/subscription/presentation/views/business_account_management_screen.dart';
import 'package:dpos/features/subscription/presentation/views/subscription_screen.dart';
import 'package:dpos/features/settings/presentation/views/help_support_screen.dart';
import 'package:dpos/features/staff_management/presentation/user_management_screen.dart';
import 'package:dpos/features/transaction/presentation/widgets/cart_screen.dart';
import 'package:dpos/features/transaction/presentation/widgets/payment_screen.dart';
import 'package:dpos/features/transaction/presentation/history/transaction_detail_screen.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:dpos/features/customer_ordering/presentation/customer_order_screen.dart';
import 'package:dpos/features/inventory/presentation/views/supplier_list_screen.dart';
import 'package:dpos/features/inventory/presentation/views/purchase_order_list_screen.dart';
import 'package:dpos/features/inventory/presentation/views/create_purchase_order_screen.dart';
import 'package:dpos/features/inventory/presentation/views/receive_purchase_order_screen.dart';
import 'package:dpos/features/inventory/presentation/views/stock_adjustment_screen.dart';
import 'package:dpos/features/inventory/presentation/views/stock_history_screen.dart';
import 'package:dpos/features/inventory/presentation/views/add_edit_supplier_screen.dart';
import 'package:dpos/features/inventory/domain/inventory_models.dart';
import 'package:dpos/features/cash_flow/presentation/views/cash_flow_screen.dart';
import 'package:dpos/features/inventory/presentation/views/ingredient_list_screen.dart';
import 'package:dpos/features/inventory/presentation/views/recipe_management_screen.dart';
import 'package:dpos/features/inventory/presentation/views/stock_opname_sheet_screen.dart';
import 'package:dpos/features/inventory/presentation/views/stock_opname_history_screen.dart';
import 'routes_name.dart';
import 'routes_path.dart';

// ✅ Provider untuk menyimpan state routing (survive hot reload)
final routerStateProvider = StateProvider<RouterState>((ref) => RouterState());

class RouterState {
  bool isInitialRedirectDone = false;
  String? lastRoute;
}

class AppRouter {
  static GoRouter getRouter({
    List<NavigatorObserver>? observers,
    required GlobalKey<NavigatorState> rootKey,
    required Ref ref, // ✅ Gunakan Ref agar fleksibel (WidgetRef / ProviderRef)
  }) {
    return GoRouter(
      debugLogDiagnostics: kDebugMode,
      navigatorKey: rootKey,
      initialLocation: RoutesPath.splashScreen,
      redirect: (context, state) async {
        final route = state.matchedLocation;
        final isSplash = route == RoutesPath.splashScreen;
        final isLogin = route == RoutesPath.login;
        final isOtp = route == RoutesPath.otpVerification;
        final isOwnerOnboarding = route == RoutesPath.ownerOnboarding;
        final isDashboard = route == RoutesPath.dashboard;
        final isOutletPicker = route == RoutesPath.outletPicker;
        final isCustomerOrder = route.startsWith('/order/');

        if (isSplash || isCustomerOrder) {
          return null;
        }

        // 1. Cek sesi lokal Supabase secara instan (0 ms, tanpa request internet)
        final currentUser = SupabaseService.client.auth.currentUser;
        if (currentUser == null) {
          return isLogin || isOtp ? null : RoutesPath.login;
        }

        // 2. Ambil bootstrap dari memory Riverpod (0 ms).
        // Hanya memanggil loadBootstrap() via internet jika memory masih kosong (misal saat cold start).
        final cachedBootstrap = ref.read(homeBootstrapProvider).valueOrNull;
        final bootstrap =
            cachedBootstrap ??
            await ref.read(authRepositoryProvider).loadBootstrap();

        if (!bootstrap.isLoggedIn) {
          // Sesi Supabase lokal ada, tetapi profil masih dalam inisialisasi: jangan lempar balik ke login
          return null;
        }

        final isOwner =
            bootstrap.profile?.defaultRole.name == 'owner' ||
            bootstrap.business == null;
        if (isOwner && bootstrap.needsOwnerOnboarding) {
          return isOwnerOnboarding ? null : RoutesPath.ownerOnboarding;
        }

        if (bootstrap.needsOutletSelection) {
          return isOutletPicker ? null : RoutesPath.outletPicker;
        }

        if (isLogin ||
            isOtp ||
            (isOwnerOnboarding && !bootstrap.needsOwnerOnboarding) ||
            isOutletPicker) {
          return RoutesPath.dashboard;
        }

        if (isDashboard) {
          return null;
        }

        return null;
      },
      routes: <GoRoute>[
        GoRoute(
          path: RoutesPath.initialRoot,
          redirect: (_, __) => RoutesPath.splashScreen,
        ),
        GoRoute(
          name: RouteNames.splashScreen,
          path: RoutesPath.splashScreen,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const SplashScreen()),
        ),
        GoRoute(
          name: RouteNames.login,
          path: RoutesPath.login,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const GoogleOwnerSignInScreen()),
        ),
        GoRoute(
          name: RouteNames.otpVerification,
          path: RoutesPath.otpVerification,
          pageBuilder: (context, state) {
            final phone = state.uri.queryParameters['phone'] ?? '';
            return _buildPage(
              context,
              state,
              OtpVerificationScreen(phoneNumber: phone),
            );
          },
        ),
        GoRoute(
          name: RouteNames.ownerOnboarding,
          path: RoutesPath.ownerOnboarding,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const OwnerOnboardingScreen()),
        ),
        GoRoute(
          name: RouteNames.businessProfileEdit,
          path: RoutesPath.businessProfileEdit,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const BusinessProfileEditScreen()),
        ),
        GoRoute(
          name: RouteNames.outletEdit,
          path: RoutesPath.outletEdit,
          pageBuilder: (context, state) {
            final outlet = state.extra as Outlet;
            return _buildPage(context, state, OutletEditScreen(outlet: outlet));
          },
        ),
        GoRoute(
          name: RouteNames.userManagement,
          path: RoutesPath.userManagement,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const UserManagementScreen()),
        ),
        GoRoute(
          name: RouteNames.addUser,
          path: RoutesPath.addUser,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const AddUserPage()),
        ),
        GoRoute(
          name: RouteNames.menuCategoryManagement,
          path: RoutesPath.menuCategoryManagement,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const MenuCategoryManagementScreen()),
        ),
        GoRoute(
          name: RouteNames.menuCategoryEditor,
          path: RoutesPath.menuCategoryEditor,
          pageBuilder: (context, state) => _buildPage(
            context,
            state,
            MenuCategoryEditorScreen(
              initialCategory: state.extra as MenuCatalogCategory?,
            ),
          ),
        ),
        GoRoute(
          name: RouteNames.discountManagement,
          path: RoutesPath.discountManagement,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const DiscountManagementScreen()),
        ),
        GoRoute(
          name: RouteNames.productCatalogDashboard,
          path: RoutesPath.productCatalogDashboard,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const ProductDashboardScreen()),
        ),
        GoRoute(
          name: RouteNames.productDetail,
          path: RoutesPath.productDetail,
          pageBuilder: (context, state) => _buildPage(
            context,
            state,
            ProductDetailScreen(productId: state.extra as String?),
          ),
        ),
        GoRoute(
          name: RouteNames.addProduct,
          path: RoutesPath.addProduct,
          pageBuilder: (context, state) => _buildPage(
            context,
            state,
            AddProductScreen(initialItem: state.extra as MenuItem?),
          ),
        ),
        GoRoute(
          name: RouteNames.outletPicker,
          path: RoutesPath.outletPicker,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const OutletPickerScreen()),
        ),
        GoRoute(
          name: RouteNames.paymentSettings,
          path: RoutesPath.paymentSettings,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const PaymentSettingsScreen()),
        ),
        GoRoute(
          name: RouteNames.qrisSettings,
          path: RoutesPath.qrisSettings,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const QrisSettingsScreen()),
        ),
        GoRoute(
          name: RouteNames.printerSettings,
          path: RoutesPath.printerSettings,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const PrinterSettingsScreen()),
        ),
        GoRoute(
          name: RouteNames.paymentNotificationSettings,
          path: RoutesPath.paymentNotificationSettings,
          pageBuilder: (context, state) => _buildPage(
            context,
            state,
            const PaymentNotificationSettingsScreen(),
          ),
        ),
        GoRoute(
          name: RouteNames.taxSettings,
          path: RoutesPath.taxSettings,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const TaxSettingsScreen()),
        ),
        GoRoute(
          name: RouteNames.orderTypeSettings,
          path: RoutesPath.orderTypeSettings,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const OrderTypeSettingsScreen()),
        ),
        GoRoute(
          name: RouteNames.businessTemplateManagement,
          path: RoutesPath.businessTemplateManagement,
          pageBuilder: (context, state) => _buildPage(
            context,
            state,
            const BusinessTemplateManagementScreen(),
          ),
        ),
        GoRoute(
          name: RouteNames.businessTemplateEdit,
          path: RoutesPath.businessTemplateEdit,
          pageBuilder: (context, state) {
            final template = state.extra as BusinessTypeTemplate?;
            return _buildPage(
              context,
              state,
              BusinessTemplateEditScreen(template: template),
            );
          },
        ),
        GoRoute(
          name: RouteNames.businessAccountManagement,
          path: RoutesPath.businessAccountManagement,
          pageBuilder: (context, state) => _buildPage(
            context,
            state,
            const BusinessAccountManagementScreen(),
          ),
        ),
        GoRoute(
          name: RouteNames.transactionCart,
          path: RoutesPath.transactionCart,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const CartScreen()),
        ),
        GoRoute(
          name: RouteNames.transactionPayment,
          path: RoutesPath.transactionPayment,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const PaymentScreen()),
        ),
        GoRoute(
          name: RouteNames.transactionDetail,
          path: RoutesPath.transactionDetail,
          pageBuilder: (context, state) => _buildPage(
            context,
            state,
            TransactionDetailScreen(order: state.extra as TransactionOrder),
          ),
        ),
        GoRoute(
          name: RouteNames.dashboard,
          path: RoutesPath.dashboard,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const HomeScreen()),
        ),
        GoRoute(
          name: RouteNames.customerOrder,
          path: RoutesPath.customerOrder,
          pageBuilder: (context, state) {
            final outletId = state.pathParameters['outletId'] ?? '';
            final tableId = state.pathParameters['tableId'] ?? '';
            return _buildPage(
              context,
              state,
              CustomerOrderScreen(outletId: outletId, tableId: tableId),
            );
          },
        ),
        GoRoute(
          name: RouteNames.supplierList,
          path: RoutesPath.supplierList,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const SupplierListScreen()),
        ),
        GoRoute(
          name: RouteNames.purchaseOrderList,
          path: RoutesPath.purchaseOrderList,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const PurchaseOrderListScreen()),
        ),
        GoRoute(
          name: RouteNames.createPurchaseOrder,
          path: RoutesPath.createPurchaseOrder,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const CreatePurchaseOrderScreen()),
        ),
        GoRoute(
          name: RouteNames.receivePurchaseOrder,
          path: RoutesPath.receivePurchaseOrder,
          pageBuilder: (context, state) => _buildPage(
            context,
            state,
            ReceivePurchaseOrderScreen(po: state.extra as PurchaseOrder),
          ),
        ),
        GoRoute(
          name: RouteNames.stockAdjustment,
          path: RoutesPath.stockAdjustment,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const StockAdjustmentScreen()),
        ),
        GoRoute(
          name: RouteNames.stockOpnameSheet,
          path: RoutesPath.stockOpnameSheet,
          pageBuilder: (context, state) => _buildPage(
            context,
            state,
            StockOpnameSheetScreen(existingSessionId: state.extra as String?),
          ),
        ),
        GoRoute(
          name: RouteNames.stockOpnameHistory,
          path: RoutesPath.stockOpnameHistory,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const StockOpnameHistoryScreen()),
        ),
        GoRoute(
          name: RouteNames.stockHistory,
          path: RoutesPath.stockHistory,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const StockHistoryScreen()),
        ),
        GoRoute(
          name: RouteNames.addSupplier,
          path: RoutesPath.addSupplier,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const AddEditSupplierScreen()),
        ),
        GoRoute(
          name: RouteNames.editSupplier,
          path: RoutesPath.editSupplier,
          pageBuilder: (context, state) {
            final supplier = state.extra as Supplier?;
            return _buildPage(
              context,
              state,
              AddEditSupplierScreen(supplier: supplier),
            );
          },
        ),
        GoRoute(
          name: RouteNames.ingredientList,
          path: RoutesPath.ingredientList,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const IngredientListScreen()),
        ),
        GoRoute(
          name: RouteNames.recipeManagement,
          path: RoutesPath.recipeManagement,
          pageBuilder: (context, state) {
            final menuItem = state.extra as MenuItem?;
            return _buildPage(
              context,
              state,
              RecipeManagementScreen(initialMenuItem: menuItem),
            );
          },
        ),
        GoRoute(
          name: RouteNames.subscription,
          path: RoutesPath.subscription,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const SubscriptionScreen()),
        ),
        GoRoute(
          name: RouteNames.helpSupport,
          path: RoutesPath.helpSupport,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const HelpSupportScreen()),
        ),
        GoRoute(
          name: RouteNames.cashFlow,
          path: RoutesPath.cashFlow,
          pageBuilder: (context, state) =>
              _buildPage(context, state, const CashFlowScreen()),
        ),
      ],
      observers: observers,
    );
  }

  /// ✅ Update index hanya saat route benar-benar berubah
  // static void _handleRouteChange(GoRouter router, Ref ref) {
  //   try {
  //     final currentRoute = router.routerDelegate.currentConfiguration.uri.path;
  //     final routerState = ref.read(routerStateProvider);

  //     if (routerState.lastRoute == currentRoute) return;

  //     ref.read(routerStateProvider.notifier).update((value) {
  //       value.lastRoute = currentRoute;
  //       return value;
  //     });

  //     // final menuItems = ref.read(mainPodProvider).value?.menuItems ?? [];
  //     // if (menuItems.isEmpty) return;

  //     // final index = MainScreenUtils.getMenuIndexFromRoute(
  //     //   currentRoute,
  //     //   menuItems,
  //     // );
  //     // if (index == -1) return;

  //     // final currentIndex = ref.read(mainPodProvider).value?.selectedIndex ?? -1;
  //     // if (currentIndex != index) {
  //     //   ref.read(mainPodProvider.notifier).syncSelectedIndex(index);
  //     // }
  //   } catch (e) {
  //     if (kDebugMode) print('Error updating selected index: $e');
  //   }
  // }

  /// Helper: buat page tanpa transition kalau tablet
  static Page<void> _buildPage(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) {
    return NoTransitionPage<void>(key: state.pageKey, child: child);
  }
}
