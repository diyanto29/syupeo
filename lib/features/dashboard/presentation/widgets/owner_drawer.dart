import 'package:dpos/core/domain/app_enums.dart';
import 'package:dpos/core/domain/bootstrap_models.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/providers/feature_gate_provider.dart';
import 'package:dpos/features/auth/data/auth_repository.dart';
import 'package:dpos/features/dashboard/presentation/navigation/owner_dashboard_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/features/subscription/presentation/views/starter_kit_orders_sheet.dart';

class OwnerDrawer extends ConsumerWidget {
  const OwnerDrawer({
    super.key,
    required this.bootstrap,
    required this.onLogout,
  });

  final OwnerBootstrap bootstrap;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Drawer(
      width: 332,
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SidebarContent(bootstrap: bootstrap, onLogout: onLogout),
    );
  }
}

class SidebarContent extends ConsumerWidget {
  const SidebarContent({
    super.key,
    required this.bootstrap,
    required this.onLogout,
    this.isPinned = false,
  });

  final OwnerBootstrap bootstrap;
  final Future<void> Function() onLogout;
  final bool isPinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = bootstrap.profile;
    final business = bootstrap.business;
    final currentOutlet = bootstrap.currentOutlet;
    final selectedMenu = ref.watch(ownerSelectedMenuProvider);
    final role =
        bootstrap.membership?.role ?? profile?.defaultRole ?? AppRole.owner;
    final availableMenus = OwnerDashboardNavigation.availableMenusForBootstrap(
      bootstrap,
      ref,
    );
    final effectiveSelectedMenu = OwnerDashboardNavigation.effectiveMenu(
      selectedMenu: selectedMenu,
      bootstrap: bootstrap,
      ref: ref,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: scheme.primary, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: CircleAvatar(
                      backgroundColor: scheme.secondaryContainer,
                      backgroundImage: profile?.avatarUrl != null
                          ? NetworkImage(profile!.avatarUrl!)
                          : null,
                      child: profile?.avatarUrl == null
                          ? const Icon(Icons.person_rounded, size: 26)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.fullName ?? profile?.email ?? 'Akun Member',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        roleDisplayLabel(role, business: business).toUpperCase(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isPinned)
                  Icon(
                    Icons.menu_rounded,
                    color: scheme.onSurface.withValues(alpha: 0.68),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => handleOutletTap(context, ref, bootstrap),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F6FD),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.store_mall_directory_outlined,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OUTLET AKTIF',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.54),
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentOutlet?.name ?? business?.name ?? '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: scheme.onSurface.withValues(alpha: 0.58),
                    ),
                  ],
                ),
              ),
            ),
            if (business != null) ...[
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  StarterKitOrdersSheet.show(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFBFDBFE),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        size: 18,
                        color: Color(0xFF0070FC),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Starter Kit Syupeo',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E3A8A),
                              ),
                            ),
                            Text(
                              'Semua Fitur Kasir & POS Aktif Penuh',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                color: const Color(0xFF3B82F6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: scheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  OwnerDashboardNavigation.selectMenu(
                    ref,
                    OwnerMenu.starterKitOrder,
                    bootstrap: bootstrap,
                  );
                  if (!isPinned && Scaffold.maybeOf(context)?.isDrawerOpen == true) {
                    Navigator.of(context).pop();
                  }
                  context.goNamed(RouteNames.dashboard);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: business.isPendingActivation
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: business.isPendingActivation
                          ? const Color(0xFFFCD34D)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_shipping_rounded,
                        size: 16,
                        color: business.isPendingActivation
                            ? const Color(0xFFB45309)
                            : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          business.isPendingActivation
                              ? 'Riwayat Paket (Menunggu Aktivasi)'
                              : 'Riwayat Paket Usaha',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: business.isPendingActivation
                                ? const Color(0xFF92400E)
                                : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: business.isPendingActivation
                            ? const Color(0xFFB45309)
                            : scheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              business?.name ?? profile?.email ?? '-',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: Builder(
                builder: (context) {
                  final listChildren = <Widget>[];
                  MenuSection? currentSection;

                  for (final menu in availableMenus) {
                    if (menu.section != currentSection) {
                      currentSection = menu.section;
                      listChildren.add(
                        Padding(
                          padding: EdgeInsets.only(
                            left: 12,
                            right: 12,
                            top: listChildren.isEmpty ? 4 : 20,
                            bottom: 8,
                          ),
                          child: Row(
                            children: [
                              Text(
                                menu.section.label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.primary.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10.5,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    listChildren.add(
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: DrawerMenuTile(
                          menu: menu,
                          selected: menu == effectiveSelectedMenu,
                          onTap: () {
                            if (menu == OwnerMenu.printerSettings) {
                              if (isPinned) {
                                OwnerDashboardNavigation.selectMenu(
                                  ref,
                                  menu,
                                  bootstrap: bootstrap,
                                );
                              } else {
                                if (Scaffold.maybeOf(context)?.isDrawerOpen == true) {
                                  Navigator.of(context).pop();
                                }
                                context.pushNamed(RouteNames.printerSettings);
                              }
                            } else {
                              OwnerDashboardNavigation.selectMenu(
                                ref,
                                menu,
                                bootstrap: bootstrap,
                              );
                              if (!isPinned && Scaffold.maybeOf(context)?.isDrawerOpen == true) {
                                Navigator.of(context).pop();
                              }
                              context.goNamed(RouteNames.dashboard);
                            }
                          },
                        ),
                      ),
                    );
                  }

                  return ListView(
                    padding: EdgeInsets.zero,
                    children: listChildren,
                  );
                },
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 18),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onLogout,
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, color: scheme.secondary),
                        const SizedBox(width: 12),
                        Text(
                          'Keluar',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: const Color(0xFFD92D20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DrawerMenuTile extends ConsumerWidget {
  const DrawerMenuTile({
    super.key,
    required this.menu,
    required this.selected,
    required this.onTap,
  });

  final OwnerMenu menu;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final featureGate = ref.watch(featureGateProvider);
    final isProLocked = menu.featureKey != null && !featureGate.isEnabled(menu.featureKey!);

    return Material(
      color: selected ? scheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                menu.icon,
                color: selected
                    ? scheme.secondary
                    : scheme.onSurface.withValues(alpha: 0.68),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  menu.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: selected
                        ? scheme.secondary
                        : scheme.onSurface.withValues(alpha: 0.78),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              if (isProLocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
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

Future<void> handleOutletTap(
  BuildContext context,
  WidgetRef ref,
  OwnerBootstrap bootstrap,
) async {
  if (bootstrap.outlets.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Belum ada outlet aktif yang bisa dipilih.'),
      ),
    );
    return;
  }

  await showOutletBottomSheet(context, ref, bootstrap);
}

Future<void> showOutletBottomSheet(
  BuildContext context,
  WidgetRef ref,
  OwnerBootstrap bootstrap,
) async {
  var draftOutletId =
      bootstrap.currentOutlet?.id ??
      (bootstrap.outlets.isNotEmpty ? bootstrap.outlets.first.id : null);
  final role =
      bootstrap.membership?.role ??
      bootstrap.profile?.defaultRole ??
      AppRole.owner;
  final canManageOutlets = role == AppRole.owner;

  final action = await showModalBottomSheet<_OutletPickerAction>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
    ),
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final bottomInset = MediaQuery.of(context).viewInsets.bottom;

      return StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.74,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: scheme.outlineVariant.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pilih Outlet Aktif',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  'Switch outlet untuk kelola data spesifik.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurface.withValues(
                                      alpha: 0.62,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: bootstrap.outlets.length,
                          itemBuilder: (context, index) {
                            final outlet = bootstrap.outlets[index];
                            final isSelected = draftOutletId == outlet.id;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                color: isSelected
                                    ? scheme.primaryContainer
                                    : scheme.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isSelected
                                        ? scheme.primary
                                        : scheme.outlineVariant.withValues(
                                            alpha: 0.5,
                                          ),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    setModalState(
                                      () => draftOutletId = outlet.id,
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? scheme.primary
                                                : scheme.primary.withValues(
                                                    alpha: 0.1,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.store_rounded,
                                            color: isSelected
                                                ? Colors.white
                                                : scheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                outlet.name,
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: isSelected
                                                          ? scheme
                                                                .onPrimaryContainer
                                                          : scheme.onSurface,
                                                    ),
                                              ),
                                              Text(
                                                outlet.code ?? 'No Code',
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: isSelected
                                                          ? scheme.primary
                                                          : scheme.onSurface
                                                                .withValues(
                                                                  alpha: 0.54,
                                                                ),
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: scheme.primary,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (canManageOutlets) ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop(
                              const _OutletPickerAction(openManagement: true),
                            );
                          },
                          icon: const Icon(Icons.settings_outlined, size: 20),
                          label: const Text('Manajemen Semua Outlet'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pop(_OutletPickerAction(outletId: draftOutletId));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Konfirmasi Pilihan',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );

  if (action == null || !context.mounted) {
    return;
  }

  if (action.openManagement) {
    OwnerDashboardNavigation.selectMenu(
      ref,
      OwnerMenu.outletManagement,
      bootstrap: bootstrap,
    );
    if (context.mounted) {
      if (Scaffold.maybeOf(context)?.isDrawerOpen == true) {
        Navigator.of(context).pop();
      }
      context.goNamed(RouteNames.dashboard);
    }
    return;
  }

  final selectedOutletId = action.outletId;
  if (selectedOutletId == null) {
    return;
  }

  // logic simpan outlet aktif ke repository dan refresh bootstrap
  await ref.read(authRepositoryProvider).setCurrentOutletId(selectedOutletId);
  ref.invalidate(homeBootstrapProvider);
  if (context.mounted) {
    if (Scaffold.maybeOf(context)?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
  }
}

class _OutletPickerAction {
  const _OutletPickerAction({this.outletId, this.openManagement = false});
  final String? outletId;
  final bool openManagement;
}
