import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/features/auth/data/auth_repository.dart';
import 'package:dpos/features/dashboard/presentation/navigation/owner_dashboard_navigation.dart';
import 'package:dpos/features/dashboard/presentation/widgets/owner_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Reusable drawer yang otomatis memuat bootstrap dan menangani logout.
class AppOwnerDrawer extends ConsumerWidget {
  const AppOwnerDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(homeBootstrapProvider).valueOrNull;
    if (bootstrap == null) return const SizedBox.shrink();

    return OwnerDrawer(
      bootstrap: bootstrap,
      onLogout: () async {
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
      },
    );
  }
}

/// Badge standar 'Syupeo' dengan dot hijau khas list kategori produk.
class AppTabletBadge extends StatelessWidget {
  const AppTabletBadge({
    super.key,
    this.label = 'Syupeo',
    this.dotColor = const Color(0xFF16A34A),
    this.bgColor = const Color(0xFFDCFCE7),
    this.textColor = const Color(0xFF16A34A),
  });

  final String label;
  final Color dotColor;
  final Color bgColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Leading widget standar untuk tablet yang memuat icon sidebar (drawer) dan tombol back dengan border box.
class AppTabletLeading extends ConsumerWidget {
  const AppTabletLeading({
    super.key,
    this.onBack,
    this.showBack = true,
    this.showSidebar = true,
  });

  final VoidCallback? onBack;
  final bool showBack;
  final bool showSidebar;

  static const double width = 108.0;

  static double leadingWidth(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return canPop ? 108.0 : 60.0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPop = Navigator.of(context).canPop();
    final menuHistory = ref.watch(ownerMenuHistoryProvider);
    final hasMenuHistory = menuHistory.length > 1;
    final shouldShowBack = showBack && (canPop || hasMenuHistory || onBack != null);

    void handleBack() {
      if (onBack != null) {
        onBack!();
      } else if (canPop) {
        Navigator.of(context).maybePop();
      } else if (hasMenuHistory) {
        final history = ref.read(ownerMenuHistoryProvider);
        if (history.length > 1) {
          final newHistory = List<OwnerMenu>.from(history)..removeLast();
          ref.read(ownerMenuHistoryProvider.notifier).state = newHistory;
          ref.read(ownerSelectedMenuProvider.notifier).state = newHistory.last;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSidebar)
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
                    size: 20,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          if (shouldShowBack) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: handleBack,
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
                  size: 20,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Header tablet standar bergaya list kategori produk (putih bergaris bawah dengan icon ber-border).
class AppTabletHeader extends ConsumerWidget implements PreferredSizeWidget {
  const AppTabletHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.badge,
    this.actions,
    this.onBack,
    this.showBack = true,
    this.showSidebar = true,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? badge;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final bool showBack;
  final bool showSidebar;

  @override
  Size get preferredSize => const Size.fromHeight(68.0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPop = Navigator.of(context).canPop();
    final menuHistory = ref.watch(ownerMenuHistoryProvider);
    final hasMenuHistory = menuHistory.length > 1;
    final shouldShowBack = showBack && (canPop || hasMenuHistory || onBack != null);

    void handleBack() {
      if (onBack != null) {
        onBack!();
      } else if (canPop) {
        Navigator.of(context).maybePop();
      } else if (hasMenuHistory) {
        final history = ref.read(ownerMenuHistoryProvider);
        if (history.length > 1) {
          final newHistory = List<OwnerMenu>.from(history)..removeLast();
          ref.read(ownerMenuHistoryProvider.notifier).state = newHistory;
          ref.read(ownerSelectedMenuProvider.notifier).state = newHistory.last;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (showSidebar) ...[
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
            ],
            if (shouldShowBack) ...[
              InkWell(
                onTap: handleBack,
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
            ],
            Expanded(
              child: Row(
                children: [
                  if (subtitle == null)
                    DefaultTextStyle(
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      child: title,
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DefaultTextStyle(
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                          child: title,
                        ),
                        const SizedBox(height: 2),
                        subtitle!,
                      ],
                    ),
                  if (badge != null) ...[const SizedBox(width: 10), badge!],
                ],
              ),
            ),
            if (actions != null) ...actions!,
          ],
        ),
      ),
    );
  }
}
