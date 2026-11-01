import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/core/domain/app_enums.dart';
import 'package:dpos/core/domain/bootstrap_models.dart';
import 'package:dpos/core/domain/business_models.dart';
import 'package:dpos/core/domain/outlet_models.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/auth/data/auth_repository.dart';
import 'package:dpos/features/auth/domain/auth_models.dart' show AppProfile;
import 'package:dpos/features/dashboard/presentation/navigation/owner_dashboard_navigation.dart';
import 'package:dpos/features/dashboard/presentation/widgets/owner_drawer.dart';
import 'package:dpos/features/menu_management/presentation/views/menu_management_view.dart';
import 'package:dpos/features/outlet_management/presentation/outlet_management_screen.dart';
import 'package:dpos/features/settings/data/printer_settings_repository.dart';
import 'package:dpos/features/staff_management/presentation/user_management_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dpos/features/business_profile/presentation/business_profile_dashboard_view.dart';
import 'package:dpos/features/settings/presentation/views/settings_screen.dart';
import 'package:dpos/features/settings/presentation/views/printer_settings_screen.dart';
import 'package:dpos/features/table_session/presentation/table_session_screen.dart';
import 'package:dpos/features/transaction/presentation/transaction_screen.dart';
import 'package:dpos/features/transaction/presentation/history/transaction_history_screen.dart';
import 'package:dpos/features/transaction/presentation/orders/order_management_screen.dart';
import 'package:dpos/features/waiter/presentation/waiter_workspace_screens.dart';
import 'package:dpos/features/dashboard/presentation/widgets/sales_dashboard_view.dart';
import 'package:dpos/features/reports/presentation/report_screen.dart';
import 'package:dpos/features/waiter/presentation/screens/table_qr_generator_screen.dart';
import 'package:dpos/features/inventory/presentation/views/inventory_dashboard_view.dart';
import 'package:dpos/features/kitchen/presentation/kitchen_queue_screen.dart';

import 'package:dpos/core/widgets/announcement_banner_widget.dart';
import 'package:dpos/core/services/notification_service.dart';
import 'package:dpos/core/services/soundbox_tts_service.dart';
import 'package:dpos/features/dashboard/presentation/widgets/store_activated_dialog.dart';
import 'package:dpos/features/subscription/presentation/views/subscription_screen.dart';
import 'package:dpos/features/subscription/presentation/views/starter_kit_orders_sheet.dart';
import 'package:dpos/features/subscription/presentation/views/restock_catalog_screen.dart';
import 'package:dpos/features/settings/presentation/views/help_support_screen.dart';
import 'package:dpos/features/cash_flow/presentation/views/cash_flow_screen.dart';
import 'package:dpos/features/customer_debt/presentation/customer_debt_screen.dart';
import 'package:dpos/features/ai_assistant/presentation/screens/ai_assistant_screen.dart';
import 'package:dpos/core/widgets/app_tablet_nav.dart';

final _printerConnectionNoticeShownProvider = StateProvider<bool>(
  (ref) => false,
);

final _seenPendingStoreActivationProvider = StateProvider<bool>(
  (ref) => false,
);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bootstrapAsync = ref.watch(homeBootstrapProvider);
    final selectedMenu = ref.watch(ownerSelectedMenuProvider);
    final effectiveMenu = OwnerDashboardNavigation.effectiveMenu(
      selectedMenu: selectedMenu,
      bootstrap: bootstrapAsync.value,
      ref: ref,
    );

    // Track jika saat ini sedang dalam status pending
    final currentBiz = bootstrapAsync.valueOrNull?.business;
    if (currentBiz != null && currentBiz.isPendingActivation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(_seenPendingStoreActivationProvider) != true) {
          ref.read(_seenPendingStoreActivationProvider.notifier).state = true;
        }
      });
    }

    // Realtime listener untuk mendeteksi aktivasi toko oleh Admin Web
    ref.listen<AsyncValue<OwnerBootstrap>>(homeBootstrapProvider, (previous, next) {
      final prevBiz = previous?.valueOrNull?.business;
      final nextBiz = next.valueOrNull?.business;

      final hadSeenPending = ref.read(_seenPendingStoreActivationProvider);
      final wasPending = prevBiz?.isPendingActivation ?? hadSeenPending;
      final isNowActive = nextBiz != null && !nextBiz.isPendingActivation && nextBiz.status == 'active';

      if (wasPending && isNowActive) {
        ref.read(_seenPendingStoreActivationProvider.notifier).state = false;

        // 1. Notifikasi lokal foreground
        NotificationService.instance.showInstantAlert(
          title: 'Toko Telah Aktif! 🎉',
          body: 'Toko "${nextBiz.name}" berhasil diaktifkan oleh Admin Syupeo. Selamat berjualan!',
        );

        // 2. Pengumuman suara via Soundbox TTS
        try {
          ref.read(soundboxTtsServiceProvider).speak(
            'Selamat! Toko ${nextBiz.name} telah aktif dan siap digunakan untuk berjualan.',
          );
        } catch (_) {}

        // 3. Tampilkan dialog selebrasi interaktif
        if (context.mounted) {
          StoreActivatedDialog.show(
            context,
            nextBiz,
            onStartSelling: () {
              OwnerDashboardNavigation.selectMenu(
                ref,
                OwnerMenu.transaction,
                bootstrap: next.valueOrNull,
              );
            },
            onCheckShipping: () {
              OwnerDashboardNavigation.selectMenu(
                ref,
                OwnerMenu.starterKitOrder,
                bootstrap: next.valueOrNull,
              );
            },
          );
        }
      }
    });

    Future<void> handleLogout() async {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const _LogoutLoadingDialog(),
      );

      try {
        await ref.read(authRepositoryProvider).signOut();
        OwnerDashboardNavigation.resetMenu(ref);
        ref.read(_printerConnectionNoticeShownProvider.notifier).state = false;
        ref.invalidate(homeBootstrapProvider);
        if (!context.mounted) {
          return;
        }
        Navigator.of(context, rootNavigator: true).pop();
        context.goNamed(RouteNames.login);
      } catch (error) {
        if (!context.mounted) {
          return;
        }
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Logout gagal: $error')));
      }
    }

    final isTablet = MediaQuery.sizeOf(context).width >= 760;
    final isDesktopPlatform = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);
    final isPinnedSidebar =
        isDesktopPlatform && MediaQuery.sizeOf(context).width >= 720;
    final hideAppBar =
        (isTablet || isPinnedSidebar) &&
        (effectiveMenu == OwnerMenu.settings ||
            effectiveMenu == OwnerMenu.reports ||
            effectiveMenu == OwnerMenu.businessProfile ||
            effectiveMenu == OwnerMenu.cashFlow);

    return PopScope(
      canPop: ref.watch(ownerMenuHistoryProvider).length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        final history = ref.read(ownerMenuHistoryProvider);
        if (history.length > 1) {
          final newHistory = List<OwnerMenu>.from(history)..removeLast();
          ref.read(ownerMenuHistoryProvider.notifier).state = newHistory;
          ref.read(ownerSelectedMenuProvider.notifier).state = newHistory.last;
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: isPinnedSidebar
            ? null
            : hideAppBar
                ? null
                : isTablet
                    ? PreferredSize(
                    preferredSize: const Size.fromHeight(68),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Container(
                          height: 68,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Builder(
                                builder: (context) => InkWell(
                                  onTap: () => Scaffold.of(context).openDrawer(),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.menu_rounded,
                                      color: Color(0xFF0F172A),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              if (ref.watch(ownerMenuHistoryProvider).length > 1) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    final history = ref.read(ownerMenuHistoryProvider);
                                    if (history.length > 1) {
                                      final newHistory = List<OwnerMenu>.from(history)..removeLast();
                                      ref.read(ownerMenuHistoryProvider.notifier).state = newHistory;
                                      ref.read(ownerSelectedMenuProvider.notifier).state = newHistory.last;
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.arrow_back_rounded,
                                      color: Color(0xFF0F172A),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 14),
                              Text(
                                effectiveMenu.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const AppTabletBadge(label: 'Syupeo'),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Tanya Asisten AI',
                                icon: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.blue.shade600, Colors.indigo.shade600],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                onPressed: () {
                                  OwnerDashboardNavigation.selectMenu(
                                    ref,
                                    OwnerMenu.aiAssistant,
                                    bootstrap: bootstrapAsync.value,
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: scheme.secondaryContainer,
                                backgroundImage:
                                    bootstrapAsync.value?.profile?.avatarUrl != null
                                    ? NetworkImage(
                                        bootstrapAsync.value!.profile!.avatarUrl!,
                                      )
                                    : null,
                                child: bootstrapAsync.value?.profile?.avatarUrl == null
                                    ? const Icon(Icons.person_rounded)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : AppBar(
                    title: Text(effectiveMenu.title),
                    leading: Builder(
                      builder: (context) {
                        return IconButton(
                          icon: const Icon(Icons.menu_rounded),
                          onPressed: () {
                            Scaffold.of(context).openDrawer();
                          },
                        );
                      },
                    ),
                    actions: [
                      IconButton(
                        tooltip: 'Tanya Asisten AI',
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade600, Colors.indigo.shade600],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        onPressed: () {
                          OwnerDashboardNavigation.selectMenu(
                            ref,
                            OwnerMenu.aiAssistant,
                            bootstrap: bootstrapAsync.value,
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: scheme.secondaryContainer,
                          backgroundImage:
                              bootstrapAsync.value?.profile?.avatarUrl != null
                              ? NetworkImage(
                                  bootstrapAsync.value!.profile!.avatarUrl!,
                                )
                              : null,
                          child: bootstrapAsync.value?.profile?.avatarUrl == null
                              ? const Icon(Icons.person_rounded)
                              : null,
                        ),
                      ),
                    ],
                  ),

      floatingActionButton:
          effectiveMenu == OwnerMenu.staff &&
                  OwnerDashboardNavigation.canManageStaff(bootstrapAsync.value)
              ? FloatingActionButton(
                  onPressed: () async {
                    final created = await context.pushNamed<bool>(
                      RouteNames.addUser,
                    );
                    if (created == true) {
                      ref.invalidate(homeBootstrapProvider);
                    }
                  },
                  child: const Icon(Icons.person_add_alt_1_rounded),
                )
              : effectiveMenu == OwnerMenu.home
                  ? FloatingActionButton.extended(
                      onPressed: () {
                        OwnerDashboardNavigation.selectMenu(
                          ref,
                          OwnerMenu.aiAssistant,
                          bootstrap: bootstrapAsync.value,
                        );
                      },
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                      label: const Text(
                        'Tanya AI',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    )
                  : null,
      drawer: isPinnedSidebar
          ? null
          : bootstrapAsync.maybeWhen(
              data: (bootstrap) =>
                  OwnerDrawer(bootstrap: bootstrap, onLogout: handleLogout),
              orElse: () => null,
            ),
      body: SafeArea(
        child: bootstrapAsync.when(
          data: (bootstrap) {
            final effectiveMenu = OwnerDashboardNavigation.effectiveMenu(
              selectedMenu: selectedMenu,
              bootstrap: bootstrap,
              ref: ref,
            );
            if (bootstrap.needsOwnerOnboarding) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.goNamed(RouteNames.ownerOnboarding);
              });
              return const Center(child: CircularProgressIndicator());
            }

            final profile = bootstrap.profile;
            final business = bootstrap.business;
            final isStaffManagement = effectiveMenu == OwnerMenu.staff;
            final isOutletManagement =
                effectiveMenu == OwnerMenu.outletManagement;
            final isMenuManagement = effectiveMenu == OwnerMenu.menuManagement;
            final isRestockCatalog = effectiveMenu == OwnerMenu.restockCatalog;
            final isBusinessProfile =
                effectiveMenu == OwnerMenu.businessProfile;
            final isSettings = effectiveMenu == OwnerMenu.settings;
            final isPrinterSettings =
                effectiveMenu == OwnerMenu.printerSettings;
            final isTransaction = effectiveMenu == OwnerMenu.transaction;
            final isCashFlow = effectiveMenu == OwnerMenu.cashFlow;
            final isCustomerDebt = effectiveMenu == OwnerMenu.customerDebt;
            final isTransactionHistory =
                effectiveMenu == OwnerMenu.checkoutVoid;
            final isStarterKitOrder =
                effectiveMenu == OwnerMenu.starterKitOrder;
            final isOrderManagement =
                effectiveMenu == OwnerMenu.orderManagement;
            final isTableSession = effectiveMenu == OwnerMenu.tableSession;
            final isTableTracker = effectiveMenu == OwnerMenu.tableTracker;
            final isWaiterOrders = effectiveMenu == OwnerMenu.waiterOrders;
            final isWaiterHistory = effectiveMenu == OwnerMenu.waiterHistory;
            final isHome = effectiveMenu == OwnerMenu.home;
            final isReports = effectiveMenu == OwnerMenu.reports;
            final isQrSelfOrder = effectiveMenu == OwnerMenu.qrSelfOrder;
            final isInventory = effectiveMenu == OwnerMenu.inventory;
            final isKitchenQueue = effectiveMenu == OwnerMenu.kitchenQueue;
            final isSubscription = effectiveMenu == OwnerMenu.subscription;
            final isSupport = effectiveMenu == OwnerMenu.support;
            final isAiAssistant = effectiveMenu == OwnerMenu.aiAssistant;
            final role = bootstrap.effectiveRole ?? AppRole.owner;

            if (effectiveMenu == OwnerMenu.home) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showPrinterConnectionNoticeIfNeeded(context, ref);
              });
            }

            final content = Container(
              color: const Color(0xFFF8FAFC),
              child: isStarterKitOrder
                  ? const StarterKitOrdersSheet(isEmbedded: true)
                  : isTransaction
                  ? TransactionScreen(
                      padding: isTablet
                          ? const EdgeInsets.fromLTRB(20, 8, 20, 0)
                          : const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    )
                  : isCashFlow
                  ? const CashFlowScreen()
                  : isCustomerDebt
                  ? CustomerDebtScreen(
                      padding: isTablet
                          ? const EdgeInsets.fromLTRB(28, 20, 28, 24)
                          : const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    )
                  : isQrSelfOrder
                  ? TableQrGeneratorScreen(
                      outletId: bootstrap.currentOutlet?.id ?? '',
                      outletName: bootstrap.currentOutlet?.name ?? bootstrap.business?.name ?? '',
                    )
                  : isStaffManagement
                  ? const UserManagementView(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                    )
                  : isOutletManagement
                  ? OutletManagementView(
                      bootstrap: bootstrap,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    )
                  : isMenuManagement
                  ? MenuManagementView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      profile: profile,
                    )
                  : isRestockCatalog
                  ? const RestockCatalogScreen()
                  : isBusinessProfile
                  ? BusinessProfileDashboardView(
                      bootstrap: bootstrap,
                      padding: isTablet
                          ? const EdgeInsets.fromLTRB(24, 20, 24, 24)
                          : const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    )
                  : isSettings
                  ? SettingsScreen(
                      padding: isTablet
                          ? const EdgeInsets.fromLTRB(28, 20, 28, 24)
                          : const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    )
                  : isPrinterSettings
                  ? const PrinterSettingsScreen()
                  : isTransactionHistory
                  ? const TransactionHistoryScreen(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                    )
                  : isTableSession
                  ? role == AppRole.waiter
                        ? const WaiterSessionOverviewScreen(
                            padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                          )
                        : const TableSessionScreen(
                            padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                          )
                  : isTableTracker
                  ? const WaiterTableTrackerScreen(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                    )
                  : isWaiterOrders
                  ? const WaiterOrdersScreen(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                    )
                  : isWaiterHistory
                  ? const WaiterTransactionHistoryScreen(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                    )
                  : isOrderManagement
                  ? const OrderManagementScreen(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                    )
                  : isReports
                  ? ReportScreen(
                      padding: isTablet
                          ? EdgeInsets.zero
                          : const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    )
                  : isInventory
                  ? InventoryDashboardView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    )
                  : isKitchenQueue
                  ? KitchenQueueScreen(
                      padding: isTablet
                          ? const EdgeInsets.fromLTRB(20, 8, 20, 0)
                          : const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    )
                  : isHome
                  ? const SalesDashboardView(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                    )
                  : isSubscription
                  ? const SubscriptionScreen()
                  : isAiAssistant
                  ? const AiAssistantScreen()
                  : isSupport
                  ? HelpSupportView(
                      padding: isTablet
                          ? const EdgeInsets.fromLTRB(24, 20, 24, 24)
                          : const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        _OwnerHeroCard(
                          profile: profile,
                          business: business,
                          membership: bootstrap.membership,
                          currentOutlet: bootstrap.currentOutlet,
                          selectedMenu: effectiveMenu,
                        ),
                        const AnnouncementBannerWidget(),
                        const SizedBox(height: 16),
                        ..._buildMenuSections(
                          context,
                          bootstrap: bootstrap,
                          selectedMenu: effectiveMenu,
                        ),
                      ],
                    ),
            );

            if (isPinnedSidebar) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 300,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      border: const Border(
                        right: BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                    ),
                    child: SidebarContent(
                      bootstrap: bootstrap,
                      onLogout: handleLogout,
                      isPinned: true,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!hideAppBar)
                          Container(
                            height: 68,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (ref.watch(ownerMenuHistoryProvider).length > 1) ...[
                                  InkWell(
                                    onTap: () {
                                      final history = ref.read(ownerMenuHistoryProvider);
                                      if (history.length > 1) {
                                        final newHistory = List<OwnerMenu>.from(history)..removeLast();
                                        ref.read(ownerMenuHistoryProvider.notifier).state = newHistory;
                                        ref.read(ownerSelectedMenuProvider.notifier).state = newHistory.last;
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_back_rounded,
                                        color: Color(0xFF0F172A),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                ],
                                Text(
                                  effectiveMenu.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const AppTabletBadge(label: 'Syupeo'),
                                const Spacer(),
                                IconButton(
                                  tooltip: 'Tanya Asisten AI',
                                  icon: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.blue.shade600, Colors.indigo.shade600],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  onPressed: () {
                                    OwnerDashboardNavigation.selectMenu(
                                      ref,
                                      OwnerMenu.aiAssistant,
                                      bootstrap: bootstrap,
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: scheme.secondaryContainer,
                                  backgroundImage:
                                      bootstrap.profile?.avatarUrl != null
                                      ? NetworkImage(
                                          bootstrap.profile!.avatarUrl!,
                                        )
                                      : null,
                                  child: bootstrap.profile?.avatarUrl == null
                                      ? const Icon(Icons.person_rounded)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        Expanded(child: content),
                      ],
                    ),
                  ),
                ],
              );
            }

            return content;
          },
          error: (error, _) =>
              Center(child: Text('Gagal memuat owner: $error')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    ),
  );
}

  Future<void> _showPrinterConnectionNoticeIfNeeded(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (ref.read(_printerConnectionNoticeShownProvider)) {
      return;
    }

    ref.read(_printerConnectionNoticeShownProvider.notifier).state = true;

    final settings = await PrinterSettings.load();
    const service = ThermalPrinterService();
    var connected = false;
    try {
      connected = await service.connectionStatus;
      if (!connected && settings.hasSelectedPrinter) {
        connected = await service.autoConnect(settings: settings);
      }
    } catch (_) {
      connected = false;
    }

    if (!context.mounted || connected) {
      return;
    }

    final route = ModalRoute.of(context);
    if ((route != null && !route.isCurrent) ||
        ref.read(ownerSelectedMenuProvider) != OwnerMenu.home) {
      return;
    }

    final printerName = settings.selectedPrinterName;
    final message = settings.hasSelectedPrinter && printerName != null
        ? '$printerName belum terhubung.'
        : 'Printer kasir belum diatur atau belum terhubung.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Atur Printer',
          onPressed: () {
            if (!context.mounted) {
              return;
            }

            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            context.pushNamed(RouteNames.printerSettings);
          },
        ),
      ),
    );
  }

  List<Widget> _buildMenuSections(
    BuildContext context, {
    required OwnerBootstrap bootstrap,
    required OwnerMenu selectedMenu,
  }) {
    final business = bootstrap.business;
    return switch (selectedMenu) {
      OwnerMenu.home => [
        _SectionCard(
          title: 'Quick Pulse',
          subtitle: 'Ringkasan hal penting yang owner perlu lihat hari ini.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(
                label: 'Outlet Aktif',
                value: '1',
                caption: business?.name ?? 'Belum ada outlet',
              ),
              const _StatCard(
                label: 'Penjualan Hari Ini',
                value: 'Rp 4.86jt',
                caption: 'Target menuju closing',
              ),
              const _StatCard(
                label: 'Order Berjalan',
                value: '18',
                caption: 'Perlu pantauan shift malam',
              ),
              const _StatCard(
                label: 'Staff Online',
                value: '7',
                caption: 'Waiter, kitchen, cashier aktif',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _SectionCard(
          title: 'Owner Focus',
          subtitle: 'Arah implementasi fitur inti owner setelah login.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FeatureRow(
                icon: Icons.storefront_rounded,
                title: 'Outlet & profil bisnis',
                description:
                    'Kelola identitas bisnis, jam operasional, dan kontak utama outlet.',
              ),
              SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.restaurant_menu_rounded,
                title: 'Menu & resep',
                description:
                    'Atur kategori, harga, foto, recipe cost, dan status stok menu.',
              ),
              SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.groups_rounded,
                title: 'Staff & role',
                description:
                    'Undang waiter, kitchen, dan cashier dengan hak akses masing-masing.',
              ),
            ],
          ),
        ),
      ],
      OwnerMenu.transaction => const [],
      OwnerMenu.starterKitOrder => const [],
      OwnerMenu.outletManagement => const [],
      OwnerMenu.businessProfile => const [],
      OwnerMenu.menuManagement => const [],
      OwnerMenu.restockCatalog => const [],
      OwnerMenu.tableSession => [
        const _SectionCard(
          title: 'Table Session',
          subtitle:
              'Pantau meja aktif, request waiter, dan validasi pesanan customer.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FeatureRow(
                icon: Icons.table_restaurant_rounded,
                title: 'Live table tracker',
                description:
                    'Pantau meja aktif, request waiter, dan validasi pesanan customer.',
              ),
              SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.notifications_active_rounded,
                title: 'Waiter request',
                description:
                    'Respons panggilan meja, refill, split bill, dan status bantuan customer secara real-time.',
              ),
              SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.fact_check_rounded,
                title: 'Order validation',
                description:
                    'Validasi item dan catatan pesanan customer sebelum order diproses lebih jauh.',
              ),
            ],
          ),
        ),
      ],
      OwnerMenu.tableTracker => const [],
      OwnerMenu.waiterOrders => const [],
      OwnerMenu.waiterHistory => const [],
      OwnerMenu.kitchenQueue => const [],
      OwnerMenu.checkoutVoid => const [],
      OwnerMenu.orderManagement => const [],
      OwnerMenu.staff => const [],
      OwnerMenu.reports => [
        const _SectionCard(
          title: 'Laporan & Analitik',
          subtitle:
              'Area owner untuk ringkasan laba rugi, performa staff, dan insight penjualan.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FeatureRow(
                icon: Icons.trending_up_rounded,
                title: 'Daily performance',
                description:
                    'Penjualan harian, gross sales, dan item terlaris per shift.',
              ),
              SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.insights_rounded,
                title: 'Profitability',
                description:
                    'Margin menu, recipe cost, dan item yang perlu evaluasi harga.',
              ),
              SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.file_download_rounded,
                title: 'Export',
                description:
                    'Unduh laporan Excel atau PDF untuk kebutuhan kasir dan akuntansi.',
              ),
            ],
          ),
        ),
      ],
      OwnerMenu.settings => const [],

      OwnerMenu.support => [
        const _SectionCard(
          title: 'Help & Support',
          subtitle:
              'Ruang owner untuk dokumentasi, support issue, dan status sistem.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FeatureRow(
                icon: Icons.menu_book_rounded,
                title: 'Panduan owner',
                description:
                    'Dokumentasi setup awal, onboarding staff, dan SOP operasional.',
              ),
              SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.bug_report_rounded,
                title: 'Issue reporting',
                description:
                    'Kirim laporan bug untuk drawer, auth, transaksi, dan sinkronisasi data.',
              ),
              SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.health_and_safety_rounded,
                title: 'System status',
                description:
                    'Pantau konektivitas Supabase, auth provider, dan service realtime.',
              ),
            ],
          ),
        ),
      ],
      OwnerMenu.cashFlow => const [],
      OwnerMenu.customerDebt => const [],
      OwnerMenu.qrSelfOrder => const [],
      OwnerMenu.printerSettings => const [],
      OwnerMenu.subscription => const [],
      OwnerMenu.aiAssistant => const [],
      OwnerMenu.inventory => [
        const _SectionCard(
          title: 'Manajemen Inventaris',
          subtitle:
              'Kelola stok produk, daftar supplier, dan alur pembelian barang.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FeatureRow(
                icon: Icons.inventory_2_rounded,
                title: 'Stok Opname',
                description:
                    'Lakukan penyesuaian stok manual untuk barang rusak, hilang, atau bonus.',
              ),
              SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.shopping_cart_checkout_rounded,
                title: 'Purchase Order (PO)',
                description:
                    'Buat pesanan barang ke supplier dan update stok otomatis saat barang diterima.',
              ),
              SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.local_shipping_rounded,
                title: 'Supplier',
                description:
                    'Kelola daftar supplier dan informasi kontak untuk mempermudah restock.',
              ),
            ],
          ),
        ),
      ],
    };
  }
}

class _LogoutLoadingDialog extends StatelessWidget {
  const _LogoutLoadingDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Dialog(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Sedang keluar dari akun...',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerHeroCard extends StatelessWidget {
  const _OwnerHeroCard({
    required this.profile,
    required this.business,
    required this.membership,
    required this.currentOutlet,
    required this.selectedMenu,
  });

  final AppProfile? profile;
  final Business? business;
  final BusinessMember? membership;
  final Outlet? currentOutlet;
  final OwnerMenu selectedMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFF12343B), Color(0xFF2B4E6F), Color(0xFFC27638)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedMenu.title,
            style: theme.textTheme.displayMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            selectedMenu.subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeroPill(
                label: 'Member',
                value: profile?.fullName ?? profile?.email ?? '-',
              ),
              _HeroPill(
                label: 'Bisnis',
                value: business?.name ?? 'Belum ada bisnis',
              ),
              _HeroPill(
                label: 'Outlet',
                value: currentOutlet?.name ?? business?.name ?? 'Belum dipilih',
              ),
              _HeroPill(
                label: 'Role',
                value: roleDisplayLabel(
                  membership?.role ?? profile?.defaultRole ?? AppRole.owner,
                  business: business,
                ),
              ),
              _HeroPill(
                label: 'Plan',
                value: business?.plan?.name ?? 'Free / Regular',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: (MediaQuery.sizeOf(context).width - 80) / 2,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.54),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: scheme.primary, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.62),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
