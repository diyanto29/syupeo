import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dpos/core/widgets/app_form_field.dart';

import 'package:dpos/core/domain/app_enums.dart';
import 'package:dpos/core/domain/bootstrap_models.dart';
import 'package:dpos/core/domain/outlet_models.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/providers/feature_gate_provider.dart';
import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/features/auth/data/auth_repository.dart';
import 'package:dpos/core/widgets/app_tablet_nav.dart';

final outletManagementOutletsProvider = FutureProvider.autoDispose
    .family<List<Outlet>, String>((ref, businessId) async {
      return ref
          .read(authRepositoryProvider)
          .fetchBusinessOutlets(businessId, includeInactive: true);
    });

class OutletManagementScreen extends ConsumerWidget {
  const OutletManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrapAsync = ref.watch(homeBootstrapProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 760;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppOwnerDrawer(),
      appBar: isTablet
          ? const AppTabletHeader(
              title: Text('Manajemen Outlet'),
              badge: AppTabletBadge(label: 'Mangga POS'),
            )
          : AppBar(
              title: const Text(
                'Manajemen Outlet',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              centerTitle: false,
            ),
      body: SafeArea(
        child: bootstrapAsync.when(
          data: (bootstrap) => OutletManagementView(bootstrap: bootstrap),
          error: (error, _) => Center(
            child: Text(
              'Gagal memuat outlet: $error',
              style: const TextStyle(color: Colors.red),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class OutletManagementView extends ConsumerStatefulWidget {
  const OutletManagementView({
    required this.bootstrap,
    super.key,
    this.padding,
  });

  final OwnerBootstrap bootstrap;
  final EdgeInsets? padding;

  @override
  ConsumerState<OutletManagementView> createState() =>
      _OutletManagementViewState();
}

class _OutletManagementViewState extends ConsumerState<OutletManagementView> {
  bool _isSubmitting = false;

  bool get _canManageOutlets {
    final role =
        widget.bootstrap.membership?.role ??
        widget.bootstrap.profile?.defaultRole ??
        AppRole.owner;
    return role == AppRole.owner;
  }

  Future<void> _setCurrentOutlet(Outlet outlet) async {
    if (_isSubmitting) return;

    if (!outlet.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aktifkan outlet ini terlebih dahulu sebelum digunakan.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(authRepositoryProvider).setCurrentOutletId(outlet.id);
      ref.invalidate(homeBootstrapProvider);
      final businessId = widget.bootstrap.business?.id;
      if (businessId != null) {
        ref.invalidate(outletManagementOutletsProvider(businessId));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Beralih ke outlet "${outlet.name}"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal beralih outlet: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showOutletFormSheet({Outlet? outlet}) async {
    final business = widget.bootstrap.business;
    if (business == null || _isSubmitting) return;

    if (outlet == null) {
      final repository = ref.read(authRepositoryProvider);
      final currentOutlets = await repository.fetchBusinessOutlets(business.id);
      final featureGate = ref.read(featureGateProvider);
      final maxOutlets = featureGate.getLimit('max_outlets');

      if (currentOutlets.length >= maxOutlets) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text('Batas Outlet Tercapai'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.store_rounded,
                  size: 56,
                  color: Color(0xFFFF7A00),
                ),
                const SizedBox(height: 16),
                Text(
                  'Batas outlet untuk akun Anda adalah $maxOutlets cabang. '
                  'Tingkatkan paket untuk menambah lebih banyak cabang outlet bisnis Anda.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.4),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Nanti Saja'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (!mounted) return;
                  context.pushNamed(RouteNames.businessAccountManagement);
                },
                child: const Text('Upgrade Paket'),
              ),
            ],
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    final result = await showModalBottomSheet<_OutletDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OutletFormSheet(
        outlet: outlet,
        businessName: business.name,
        canToggleActive: outlet != null,
        currentOutletId: widget.bootstrap.currentOutlet?.id,
      ),
    );

    if (result == null) return;

    setState(() => _isSubmitting = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      late final Outlet savedOutlet;

      if (outlet == null) {
        savedOutlet = await repository.createOutlet(
          businessId: business.id,
          name: result.name,
          code: result.code,
          address: result.address,
          phone: result.phone,
          latitude: result.latitude,
          longitude: result.longitude,
          geofenceRadius: result.geofenceRadius,
          isGeofenceActive: result.isGeofenceActive,
          timezone: result.timezone,
          isActive: result.isActive,
        );
      } else {
        savedOutlet = await repository.updateOutlet(
          outletId: outlet.id,
          businessId: business.id,
          name: result.name,
          code: result.code,
          address: result.address,
          phone: result.phone,
          latitude: result.latitude,
          longitude: result.longitude,
          geofenceRadius: result.geofenceRadius,
          isGeofenceActive: result.isGeofenceActive,
          timezone: result.timezone,
          isActive: result.isActive,
        );
      }

      if (result.setAsCurrent) {
        await repository.setCurrentOutletId(savedOutlet.id);
      }

      ref.invalidate(homeBootstrapProvider);
      ref.invalidate(outletManagementOutletsProvider(business.id));
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outlet == null
                ? 'Outlet "${savedOutlet.name}" berhasil dibuat.'
                : 'Data outlet berhasil diperbarui.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan outlet: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _toggleOutletStatus(
    Outlet outlet,
    List<Outlet> allOutlets,
  ) async {
    final business = widget.bootstrap.business;
    if (business == null || _isSubmitting) return;

    final activeOutlets = allOutlets.where((item) => item.isActive);
    final isCurrentOutlet = widget.bootstrap.currentOutlet?.id == outlet.id;

    if (outlet.isActive && activeOutlets.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimal harus ada 1 outlet aktif untuk operasional.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (outlet.isActive && isCurrentOutlet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Beralih ke outlet lain dulu sebelum menonaktifkan outlet ini.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(authRepositoryProvider).updateOutlet(
            outletId: outlet.id,
            businessId: business.id,
            name: outlet.name,
            code: outlet.code,
            address: outlet.address,
            phone: outlet.phone,
            timezone: outlet.timezone,
            isActive: !outlet.isActive,
          );
      ref.invalidate(homeBootstrapProvider);
      ref.invalidate(outletManagementOutletsProvider(business.id));
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outlet.isActive
                ? 'Outlet dinonaktifkan.'
                : 'Outlet berhasil diaktifkan.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengubah status: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final business = widget.bootstrap.business;
    final currentOutlet = widget.bootstrap.currentOutlet;
    final padding = widget.padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 24);

    final outletsAsync = business == null
        ? const AsyncValue<List<Outlet>>.data(<Outlet>[])
        : ref.watch(outletManagementOutletsProvider(business.id));

    return outletsAsync.when(
      data: (outlets) {
        final activeCount = outlets.where((o) => o.isActive).length;

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: _canManageOutlets
              ? FloatingActionButton.extended(
                  onPressed: _isSubmitting ? null : () => _showOutletFormSheet(),
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  elevation: 3,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Tambah Outlet',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                )
              : null,
          body: ListView(
            padding: padding.copyWith(bottom: 96),
            children: [
              // ── Header Summary Card (Clean & Elegant) ──
              _ModernHeaderCard(
                businessName: business?.name ?? 'Bisnis Anda',
                currentOutletName: currentOutlet?.name ?? 'Belum dipilih',
                activeCount: activeCount,
                totalCount: outlets.length,
              ),
              const SizedBox(height: 16),

              // ── Section Title ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daftar Cabang Toko',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    '$activeCount Aktif',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF15803D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (outlets.isEmpty)
                _EmptyOutletState(
                  canManageOutlets: _canManageOutlets,
                  onAddPressed: _canManageOutlets ? _showOutletFormSheet : null,
                )
              else
                ...outlets.map((outlet) {
                  final isCurrent = currentOutlet?.id == outlet.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ElegantOutletCard(
                      outlet: outlet,
                      isCurrent: isCurrent,
                      canManage: _canManageOutlets,
                      isBusy: _isSubmitting,
                      onSelect: isCurrent || !outlet.isActive
                          ? null
                          : () => _setCurrentOutlet(outlet),
                      onEdit: _canManageOutlets
                          ? () async {
                              await context.pushNamed(RouteNames.outletEdit, extra: outlet);
                              ref.invalidate(homeBootstrapProvider);
                              if (business != null) {
                                ref.invalidate(outletManagementOutletsProvider(business.id));
                              }
                            }
                          : null,
                      onToggleActive: _canManageOutlets
                          ? () => _toggleOutletStatus(outlet, outlets)
                          : null,
                    ),
                  );
                }),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Gagal memuat outlet: $error'),
      ),
    );
  }
}

// ── Header Card ──────────────────────────────────────────────
class _ModernHeaderCard extends StatelessWidget {
  const _ModernHeaderCard({
    required this.businessName,
    required this.currentOutletName,
    required this.activeCount,
    required this.totalCount,
  });

  final String businessName;
  final String currentOutletName;
  final int activeCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.12),
            scheme.primary.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalCount Cabang Terdaftar • $activeCount Beroperasi',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF15803D),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  'Outlet Aktif Saat Ini:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    currentOutletName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Elegant Outlet Card ──────────────────────────────────────
class _ElegantOutletCard extends StatelessWidget {
  const _ElegantOutletCard({
    required this.outlet,
    required this.isCurrent,
    required this.canManage,
    required this.isBusy,
    this.onSelect,
    this.onEdit,
    this.onToggleActive,
  });

  final Outlet outlet;
  final bool isCurrent;
  final bool canManage;
  final bool isBusy;
  final VoidCallback? onSelect;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent
              ? scheme.primary.withValues(alpha: 0.5)
              : scheme.outlineVariant.withValues(alpha: 0.2),
          width: isCurrent ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrent
                ? scheme.primary.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Icon, Name, Code & Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: outlet.isActive
                        ? (isCurrent
                            ? scheme.primary.withValues(alpha: 0.15)
                            : const Color(0xFFF0FDF4))
                        : const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    outlet.isActive
                        ? Icons.store_rounded
                        : Icons.storefront_outlined,
                    color: outlet.isActive
                        ? (isCurrent
                            ? scheme.primary
                            : const Color(0xFF15803D))
                        : const Color(0xFFA1A1AA),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              outlet.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: outlet.isActive
                                    ? scheme.onSurface
                                    : scheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          if (outlet.code != null &&
                              outlet.code!.trim().isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                outlet.code!.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  color: scheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (outlet.address != null &&
                          outlet.address!.trim().isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                outlet.address!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (outlet.phone != null &&
                          outlet.phone!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 14,
                                color: scheme.onSurface.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                outlet.phone!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Edit Menu button
                if (canManage)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                      size: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (val) {
                      if (val == 'edit') onEdit?.call();
                      if (val == 'toggle') onToggleActive?.call();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_location_alt_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('Edit Detail Cabang & GPS'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(
                              outlet.isActive
                                  ? Icons.pause_circle_outline_rounded
                                  : Icons.play_circle_outline_rounded,
                              size: 18,
                              color: outlet.isActive
                                  ? Colors.red
                                  : const Color(0xFF15803D),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              outlet.isActive
                                  ? 'Nonaktifkan Outlet'
                                  : 'Aktifkan Outlet',
                              style: TextStyle(
                                color: outlet.isActive
                                    ? Colors.red
                                    : const Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // Location & GPS Information Card (Terkait Lokasi & GPS)
            _buildLocationGpsStatus(context, scheme),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Row 2: Status Tag & Use Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.radio_button_checked_rounded,
                          size: 14,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Sedang Digunakan',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!outlet.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F4F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Nonaktif',
                      style: TextStyle(
                        color: Color(0xFF71717A),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Tersedia',
                      style: TextStyle(
                        color: Color(0xFF15803D),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),

                // Button "Pilih Outlet Ini"
                if (!isCurrent && outlet.isActive)
                  FilledButton.tonal(
                    onPressed: isBusy ? null : onSelect,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Gunakan Outlet Ini',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 14),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationGpsStatus(BuildContext context, ColorScheme scheme) {
    final hasCoords = outlet.latitude != null && outlet.longitude != null;

    if (hasCoords) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.my_location_rounded,
                size: 16,
                color: Color(0xFF15803D),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Titik GPS Terkunci',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF166534),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF86EFAC),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'Radius ${outlet.geofenceRadius ?? 5000}m',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${outlet.latitude!.toStringAsFixed(5)}, ${outlet.longitude!.toStringAsFixed(5)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF4B5563),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () async {
                final url = Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=${outlet.latitude},${outlet.longitude}',
                );
                try {
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  debugPrint('[OutletManagement] Gagal buka maps: $e');
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      size: 13,
                      color: Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Buka Maps',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDD5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.add_location_alt_rounded,
              size: 16,
              color: Color(0xFFEA580C),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Titik Lokasi & GPS Belum Diatur',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFC2410C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kunci koordinat agar validasi radius absensi kasir akurat.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF71717A),
                  ),
                ),
              ],
            ),
          ),
          if (canManage)
            InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A00),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF7A00).withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_location_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Atur GPS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Empty State ──────────────────────────────────────────────
class _EmptyOutletState extends StatelessWidget {
  const _EmptyOutletState({
    required this.canManageOutlets,
    this.onAddPressed,
  });

  final bool canManageOutlets;
  final VoidCallback? onAddPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.storefront_rounded,
                size: 32,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Outlet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tambahkan cabang outlet pertama Anda untuk mulai mencatat transaksi.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (canManageOutlets && onAddPressed != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAddPressed,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah Outlet Sekarang'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Bottom Sheet Form (Tambah / Edit) ────────────────────────
class _OutletFormSheet extends StatefulWidget {
  const _OutletFormSheet({
    required this.businessName,
    required this.canToggleActive,
    required this.currentOutletId,
    this.outlet,
  });

  final Outlet? outlet;
  final String businessName;
  final bool canToggleActive;
  final String? currentOutletId;

  @override
  State<_OutletFormSheet> createState() => _OutletFormSheetState();
}

class _OutletFormSheetState extends State<_OutletFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late String _selectedTimezone;
  late bool _isActive;
  late bool _setAsCurrent;
  double? _latitude;
  double? _longitude;
  int _geofenceRadius = 5000;
  bool _isGeofenceActive = true;
  bool _isDetectingGps = false;

  @override
  void initState() {
    super.initState();
    final outlet = widget.outlet;
    _nameController = TextEditingController(text: outlet?.name ?? '');
    _codeController = TextEditingController(text: outlet?.code ?? '');
    _addressController = TextEditingController(text: outlet?.address ?? '');
    _phoneController = TextEditingController(text: outlet?.phone ?? '');
    _selectedTimezone = outlet?.timezone ?? _outletTimezoneOptions.first.value;
    _isActive = outlet?.isActive ?? true;
    _setAsCurrent = outlet == null
        ? false
        : widget.currentOutletId == widget.outlet?.id;
    _latitude = outlet?.latitude;
    _longitude = outlet?.longitude;
    _geofenceRadius = outlet?.geofenceRadius ?? 5000;
    _isGeofenceActive = outlet?.isGeofenceActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _detectGps() async {
    setState(() => _isDetectingGps = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Layanan GPS perangkat belum aktif.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Izin akses lokasi ditolak.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin lokasi ditolak permanen.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF16A34A),
            content: Text('Titik GPS cabang berhasil dikunci!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil GPS: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDetectingGps = false);
      }
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      _OutletDraft(
        name: _nameController.text.trim(),
        code: _nullable(_codeController.text),
        address: _nullable(_addressController.text),
        phone: _nullable(_phoneController.text),
        latitude: _latitude,
        longitude: _longitude,
        geofenceRadius: _geofenceRadius,
        isGeofenceActive: _isGeofenceActive,
        timezone: _selectedTimezone,
        isActive: _isActive,
        setAsCurrent: _setAsCurrent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isEditMode = widget.outlet != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEditMode ? Icons.edit_rounded : Icons.add_business_rounded,
                      color: scheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditMode ? 'Ubah Data Outlet' : 'Tambah Outlet Baru',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          isEditMode
                              ? 'Perbarui informasi cabang toko Anda.'
                              : 'Tambahkan cabang toko baru di ${widget.businessName}.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              AppTextInput(
                label: 'Nama Outlet',
                isRequired: true,
                controller: _nameController,
                textInputAction: TextInputAction.next,
                hintText: 'Misal: Cabang Pasar Baru',
                validator: (val) {
                  if ((val ?? '').trim().isEmpty) return 'Nama outlet wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              AppTextInput(
                label: 'Kode Cabang (Opsional)',
                controller: _codeController,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-\s]')),
                ],
                hintText: 'Misal: CBG-01',
              ),
              const SizedBox(height: 12),

              AppTextInput(
                label: 'Alamat Cabang (Opsional)',
                controller: _addressController,
                textInputAction: TextInputAction.newline,
                minLines: 2,
                maxLines: 3,
                hintText: 'Jl. Merdeka No. 10...',
              ),
              const SizedBox(height: 12),

              AppTextInput(
                label: 'Nomor Telepon (Opsional)',
                controller: _phoneController,
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.phone,
                hintText: '0812xxxxxxx',
              ),
              const SizedBox(height: 12),


              const SizedBox(height: 16),
              // ── Card Koordinat GPS & Geofencing Cabang ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.radar_rounded,
                          size: 18,
                          color: Color(0xFFFF7A00),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Titik Koordinat & Geofencing',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF18181B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kunci titik GPS cabang outlet ini untuk validasi radius absensi kasir.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF71717A),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Status Koordinat
                    if (_latitude != null && _longitude != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF166534),
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Color(0xFF991B1B),
                              ),
                              tooltip: 'Hapus koordinat',
                              onPressed: () => setState(() {
                                _latitude = null;
                                _longitude = null;
                              }),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFED7AA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: Color(0xFFEA580C),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Belum ada titik GPS yang dikunci.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFFC2410C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),

                    // Tombol Kunci GPS Saat Ini
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isDetectingGps ? null : _detectGps,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF7A00),
                          side: const BorderSide(color: Color(0xFFFF7A00)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: _isDetectingGps
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A00)),
                                ),
                              )
                            : const Icon(Icons.my_location_rounded, size: 16),
                        label: Text(
                          _isDetectingGps ? 'Mencari Titik GPS...' : 'Kunci GPS Saat Ini',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    if (_latitude != null && _longitude != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Radius Toleransi Absensi Kasir:',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [1000, 3000, 5000, 10000, 20000].map((radius) {
                          final isSelected = _geofenceRadius == radius;
                          final label = radius >= 1000 ? '${radius ~/ 1000} km' : '${radius}m';
                          return ChoiceChip(
                            label: Text(label),
                            selected: isSelected,
                            selectedColor: const Color(0xFFFF7A00),
                            labelStyle: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : const Color(0xFF374151),
                            ),
                            onSelected: (val) {
                              if (val) setState(() => _geofenceRadius = radius);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              if (widget.canToggleActive) ...[
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  title: const Text(
                    'Status Outlet Aktif',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Outlet yang aktif dapat dipilih untuk transaksi kasir.',
                  ),
                  onChanged: (val) => setState(() {
                    _isActive = val;
                    if (!_isActive) _setAsCurrent = false;
                  }),
                ),
              ],

              SwitchListTile.adaptive(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _setAsCurrent,
                title: const Text(
                  'Gunakan Langsung di Perangkat Ini',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Otomatis beralih ke outlet ini setelah disimpan.',
                ),
                onChanged: _isActive
                    ? (val) => setState(() => _setAsCurrent = val)
                    : null,
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text(
                        isEditMode ? 'Simpan Perubahan' : 'Tambah Outlet',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
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

// ── Models & Helpers ─────────────────────────────────────────
class _OutletDraft {
  const _OutletDraft({
    required this.name,
    required this.code,
    required this.address,
    required this.phone,
    this.latitude,
    this.longitude,
    this.geofenceRadius = 5000,
    this.isGeofenceActive = true,
    required this.timezone,
    required this.isActive,
    required this.setAsCurrent,
  });

  final String name;
  final String? code;
  final String? address;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final int? geofenceRadius;
  final bool isGeofenceActive;
  final String timezone;
  final bool isActive;
  final bool setAsCurrent;
}

class _TimezoneOption {
  const _TimezoneOption({required this.value, required this.label});
  final String value;
  final String label;
}

const List<_TimezoneOption> _outletTimezoneOptions = [
  _TimezoneOption(
    value: 'Asia/Jakarta',
    label: '(WIB) Jakarta, Sumatera, Jawa',
  ),
  _TimezoneOption(
    value: 'Asia/Makassar',
    label: '(WITA) Bali, Kalimantan, Sulawesi',
  ),
  _TimezoneOption(
    value: 'Asia/Jayapura',
    label: '(WIT) Maluku, Papua',
  ),
];

String? _nullable(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
