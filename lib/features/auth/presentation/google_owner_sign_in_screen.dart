import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/core/theme/app_theme.dart';
import 'package:dpos/features/auth/data/auth_repository.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GoogleOwnerSignInScreen extends ConsumerStatefulWidget {
  const GoogleOwnerSignInScreen({super.key});

  @override
  ConsumerState<GoogleOwnerSignInScreen> createState() =>
      _GoogleOwnerSignInScreenState();
}

class _GoogleOwnerSignInScreenState
    extends ConsumerState<GoogleOwnerSignInScreen> {
  bool _isSubmitting = false;

  Future<void> _submitGoogle() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);
    if (isDesktop && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Membuka browser untuk login Google. Silakan pilih akun di browser...',
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    }
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      final bootstrap = await ref.refresh(homeBootstrapProvider.future);
      if (!mounted) {
        return;
      }
      context.goNamed(
        bootstrap.needsOwnerOnboarding
            ? RouteNames.ownerOnboarding
            : bootstrap.needsOutletSelection
            ? RouteNames.outletPicker
            : RouteNames.dashboard,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_resolveLoginError(error, source: 'Google'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _resolveLoginError(Object error, {required String source}) {
    final raw = error.toString();
    final normalized = raw.toLowerCase();

    if (normalized.contains('42p17') &&
        normalized.contains('infinite recursion detected in policy') &&
        normalized.contains('outlets')) {
      return 'Login berhasil, tapi policy RLS tabel outlets di Supabase masih rekursif. Jalankan migration database terbaru lalu coba lagi.';
    }
    if (normalized.contains('claim_staff_invitation')) {
      return 'Flow claim invitation belum sinkron di database. Jalankan migration Supabase terbaru terlebih dahulu.';
    }
    if (normalized.contains('invitation tidak ditemukan')) {
      return 'Invitation untuk Staff ID ini belum ditemukan.';
    }
    if (normalized.contains('password awal tidak sesuai')) {
      return 'Password awal tidak sesuai dengan invitation.';
    }
    if (normalized.contains('rate limit email supabase tercapai') ||
        normalized.contains('over_email_send_rate_limit') ||
        normalized.contains('email rate limit exceeded')) {
      return 'Supabase masih mencoba mengirim email konfirmasi untuk akun staff dan sekarang kena rate limit. Nonaktifkan Confirm email di Supabase Auth > Providers > Email, lalu coba login lagi beberapa menit kemudian.';
    }
    if (normalized.contains('email not confirmed')) {
      return 'Signup staff berhasil dibuat, tapi email confirmation masih aktif di Supabase. Nonaktifkan email confirmation untuk flow ini.';
    }
    if (normalized.contains('email_address_invalid') ||
        normalized.contains('is invalid')) {
      return 'Supabase menolak pendaftaran otomatis staf karena verifikasi email aktif. Nonaktifkan "Confirm email" di Supabase Dashboard (Authentication > Providers > Email) lalu coba lagi.';
    }
    if (normalized.contains('sign_in_failed') &&
        (normalized.contains('apiexception: 10') ||
            normalized.contains('developer error'))) {
      return 'Google Sign-In Android release belum cocok dengan konfigurasi Firebase. Tambahkan SHA-1 dan SHA-256 dari keystore release & Play App Signing ke app Android `online.mudahkan.syupeo`, download ulang `android/app/google-services.json`, lalu build ulang APK/AAB release.';
    }

    return 'Login $source gagal: $raw';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 700;

    return Scaffold(
      body: SafeArea(
        child: isTablet
            ? _buildTabletLayout(context)
            : _buildMobileLayout(context),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TABLET LAYOUT (≥ 700px) — split-screen: branded left + form right
  // ---------------------------------------------------------------------------
  Widget _buildTabletLayout(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = theme.extension<ConciergeThemeTokens>();

    return Row(
      children: [
        // ── Left branding panel ──
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary,
                  scheme.primary.withValues(alpha: 0.85),
                  scheme.secondary.withValues(alpha: 0.90),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Decorative shapes
                Positioned(
                  top: -40,
                  left: -30,
                  child: _SoftShape(
                    width: 260,
                    height: 260,
                    color: Colors.white.withValues(alpha: 0.06),
                    rotation: 0.6,
                  ),
                ),
                Positioned(
                  bottom: -20,
                  right: -40,
                  child: _SoftOval(
                    width: 220,
                    height: 280,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                Positioned(
                  bottom: 60,
                  left: 30,
                  child: _QuoteShape(
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
                // Grid pattern overlay
                Positioned.fill(
                  child: CustomPaint(painter: _GridPatternPainter()),
                ),
                // Branding content
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 48,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/icons/logo.png',
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Syupeo',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Hero tagline
                      Text(
                        'Kelola bisnis\nAnda dari\nmana saja.',
                        style: theme.textTheme.displayLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.50),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Platform POS lengkap untuk restoran modern.\n'
                        'Outlet, staff, menu, dan transaksi — dalam satu dashboard.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Feature pills
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: const [
                          _BrandingPill(
                            icon: Icons.storefront_rounded,
                            label: 'Multi-Outlet',
                          ),
                          _BrandingPill(
                            icon: Icons.groups_rounded,
                            label: 'Staff Management',
                          ),
                          _BrandingPill(
                            icon: Icons.receipt_long_rounded,
                            label: 'Live Orders',
                          ),
                          _BrandingPill(
                            icon: Icons.insights_rounded,
                            label: 'Analytics',
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Bottom tagline
                      Text(
                        '© 2026 Syupeo — Solusi POS & Kemitraan Ritel.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Right form panel ──
        Expanded(
          flex: 4,
          child: Container(
            color: tokens?.baseSurface ?? scheme.surface,
            child: Stack(
              children: [
                // Subtle top decoration
                Positioned(
                  top: -10,
                  right: 20,
                  child: _SoftOval(
                    width: 100,
                    height: 130,
                    color: scheme.secondary.withValues(alpha: 0.06),
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 36,
                      vertical: 40,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Selamat Datang',
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontSize: 32,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Masuk untuk mengelola toko ritel & kasir POS Anda.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildLoginFormCard(context),
                          const SizedBox(height: 24),
                          // _buildSignUpRow(context),
                          // const SizedBox(height: 16),
                          // _buildPagerDots(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE LAYOUT (< 700px) — original single-column
  // ---------------------------------------------------------------------------
  Widget _buildMobileLayout(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Stack(
      children: [
        Positioned(
          top: 22,
          left: 42,
          child: _SoftShape(
            width: 192,
            height: 192,
            color: scheme.secondary.withValues(alpha: 0.08),
            rotation: 0.78,
          ),
        ),
        Positioned(
          top: -10,
          right: 12,
          child: _SoftOval(
            width: 140,
            height: 182,
            color: scheme.secondary.withValues(alpha: 0.10),
          ),
        ),
        Positioned(
          bottom: 52,
          left: -26,
          child: _QuoteShape(color: scheme.primary.withValues(alpha: 0.11)),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            width: 118,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
          child: Column(
            children: [
              const SizedBox(height: 6),
              _buildMobileHeroCard(context),
              const SizedBox(height: 24),
              // _buildSignUpRow(context),
              // const SizedBox(height: 14),
              // _buildPagerDots(context),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile hero card (logo + welcome + form)
  // ---------------------------------------------------------------------------
  Widget _buildMobileHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = theme.extension<ConciergeThemeTokens>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: (tokens?.tintedShadow ?? Colors.black12),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 22),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/icons/logo.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Syupeo',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontSize: 26,
                  color: scheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Selamat Datang',
            style: theme.textTheme.displayMedium?.copyWith(
              fontSize: 30,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Masuk untuk mengelola toko ritel & kasir POS Anda.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.70),
            ),
          ),
          const SizedBox(height: 28),
          _buildLoginFormCard(context),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared login form card (used by both mobile & tablet)
  // ---------------------------------------------------------------------------
  Widget _buildLoginFormCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Masuk sebagai Mitra Toko',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Gunakan akun Google Anda untuk mengakses POS kasir, katalog kulakan langsung dari pabrik, dan laporan toko.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.65),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitGoogle,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const _GoogleMark(),
              label: Text(
                _isSubmitting
                    ? 'Menghubungkan Google...'
                    : 'Masuk dengan Google',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0070FC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Aman • 100% Gratis Tanpa Biaya Berlangganan',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: Color(0xFF0070FC),
          height: 1.05,
        ),
      ),
    );
  }
}

class _SoftShape extends StatelessWidget {
  const _SoftShape({
    required this.width,
    required this.height,
    required this.color,
    required this.rotation,
  });

  final double width;
  final double height;
  final Color color;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(36),
        ),
      ),
    );
  }
}

class _SoftOval extends StatelessWidget {
  const _SoftOval({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _QuoteShape extends StatelessWidget {
  const _QuoteShape({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      '“',
      style: TextStyle(
        fontSize: 220,
        height: 0.7,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

class _BrandingPill extends StatelessWidget {
  const _BrandingPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    const spacing = 40.0;

    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
