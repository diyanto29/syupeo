import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/core/theme/app_theme.dart';
import 'package:dpos/core/widgets/syupeo_shimmer.dart';
import 'package:dpos/core/domain/bootstrap_models.dart';
import 'package:dpos/core/domain/outlet_models.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OutletPickerScreen extends ConsumerStatefulWidget {
  const OutletPickerScreen({super.key});

  @override
  ConsumerState<OutletPickerScreen> createState() => _OutletPickerScreenState();
}

class _OutletPickerScreenState extends ConsumerState<OutletPickerScreen> {
  bool _isSubmitting = false;

  Future<void> _selectOutlet(String outletId) async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(authRepositoryProvider).setCurrentOutletId(outletId);
      ref.invalidate(homeBootstrapProvider);
      if (!mounted) {
        return;
      }
      context.goNamed(RouteNames.dashboard);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memilih outlet: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 700;
    final bootstrapAsync = ref.watch(homeBootstrapProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Outlet'), centerTitle: !isTablet),
      body: SafeArea(
        child: bootstrapAsync.when(
          data: (bootstrap) => isTablet
              ? _buildTabletLayout(context, bootstrap)
              : _buildMobileLayout(context, bootstrap),
          error: (error, _) =>
              Center(child: Text('Gagal memuat outlet: $error')),
          loading: () => ListView(
            padding: EdgeInsets.all(isTablet ? 40 : 20),
            children: List.generate(
              isTablet ? 4 : 3,
              (_) => const OutletCardSkeleton(),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TABLET LAYOUT (Grid)
  // ---------------------------------------------------------------------------
  Widget _buildTabletLayout(BuildContext context, OwnerBootstrap bootstrap) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = theme.extension<ConciergeThemeTokens>();

    if (bootstrap.outlets.isEmpty) {
      return _buildEmptyState(theme);
    }

    return Column(
      children: [
        // Premium Header Section for Tablet
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selamat Datang di ${bootstrap.business?.name ?? 'Syupeo'}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.secondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Silakan pilih outlet yang ingin Anda kelola hari ini untuk memulai aktivitas POS.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.60),
                ),
              ),
            ],
          ),
        ),
        // Grid of Outlets
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(40),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: 2.2,
            ),
            itemCount: bootstrap.outlets.length,
            itemBuilder: (context, index) {
              return _buildOutletCard(
                context,
                bootstrap.outlets[index],
                bootstrap,
                tokens,
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE LAYOUT (List)
  // ---------------------------------------------------------------------------
  Widget _buildMobileLayout(BuildContext context, OwnerBootstrap bootstrap) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = theme.extension<ConciergeThemeTokens>();

    if (bootstrap.outlets.isEmpty) {
      return _buildEmptyState(theme);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Pilih outlet yang ingin Anda kelola sekarang.',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Outlet aktif ini akan dipakai sebagai konteks kerja untuk modul POS berikutnya.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
        const SizedBox(height: 24),
        for (final outlet in bootstrap.outlets) ...[
          _buildOutletCard(context, outlet, bootstrap, tokens),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED: Outlet Card
  // ---------------------------------------------------------------------------
  Widget _buildOutletCard(
    BuildContext context,
    Outlet outlet,
    OwnerBootstrap bootstrap,
    ConciergeThemeTokens? tokens,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: _isSubmitting ? null : () => _selectOutlet(outlet.id),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: scheme.secondary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      outlet.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      outlet.code?.toUpperCase() ??
                          bootstrap.business?.name ??
                          '-',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (outlet.address != null &&
                        outlet.address!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        outlet.address!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: scheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.store_outlined,
              size: 64,
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum ada outlet aktif yang bisa dipilih untuk akun ini.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
