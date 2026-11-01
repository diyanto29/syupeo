import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/core/theme/app_theme.dart';
import 'package:dpos/core/services/wilayah_service.dart';
import 'package:dpos/core/widgets/wilayah_picker_sheet.dart';
import 'package:dpos/core/widgets/location_geofence_dialog.dart';
import 'package:dpos/features/auth/data/auth_repository.dart';
import 'package:dpos/features/auth/domain/auth_models.dart';
import 'package:dpos/features/home/application/home_bootstrap_provider.dart';
import 'package:dpos/features/subscription/domain/starter_kit_model.dart';
import 'package:dpos/features/auth/presentation/widgets/onboarding_shop_details_step.dart';
import 'package:dpos/features/auth/presentation/widgets/onboarding_starter_kit_step.dart';
import 'package:dpos/features/auth/presentation/widgets/onboarding_submitting_dialog.dart';

final ownerBootstrapProvider = FutureProvider<OwnerBootstrap>((ref) {
  return ref.read(authRepositoryProvider).loadBootstrap();
});

class OwnerOnboardingScreen extends ConsumerStatefulWidget {
  const OwnerOnboardingScreen({super.key});

  @override
  ConsumerState<OwnerOnboardingScreen> createState() =>
      _OwnerOnboardingScreenState();
}

class _OwnerOnboardingScreenState extends ConsumerState<OwnerOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _detailAddressController = TextEditingController();

  // Wilayah & Geofencing
  WilayahSelection? _wilayahSelection;
  double? _latitude;
  double? _longitude;
  int _geofenceRadius = 5000;
  bool _isGeofenceActive = true;
  String? _geofenceAddress;

  int _currentStep = 0; // 0 = Data Toko, 1 = Pilih Paket Usaha
  StarterKit? _selectedKit;
  bool _isSubmitting = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _detailAddressController.dispose();
    super.dispose();
  }

  String _cleanDisplayPhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('62')) {
      digits = digits.substring(2);
    }
    while (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  void _prefillFromProfile(AppProfile? profile) {
    if (profile == null || _prefilled) return;
    _prefilled = true;

    if (_ownerNameController.text.isEmpty && profile.fullName != null) {
      _ownerNameController.text = profile.fullName!.trim();
    }
    if (_phoneController.text.isEmpty && profile.phone != null) {
      _phoneController.text = _cleanDisplayPhone(profile.phone!.trim());
    }
    if (_businessNameController.text.isEmpty && profile.fullName != null) {
      final name = profile.fullName!.trim();
      _businessNameController.text = name.isNotEmpty
          ? 'Toko $name'
          : 'Toko Syupeo';
    }
  }

  String _generateSlug(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }

  Future<void> _pickWilayah() async {
    final result = await WilayahPickerSheet.show(context);
    if (result != null && mounted) {
      setState(() {
        _wilayahSelection = result;
      });
    }
  }

  Future<void> _pickGeofenceLocation() async {
    final result = await LocationGeofenceDialog.show(
      context,
      initialAddress: _geofenceAddress ?? _detailAddressController.text,
      initialLatitude: _latitude,
      initialLongitude: _longitude,
      initialRadius: _geofenceRadius,
      initialIsActive: _isGeofenceActive,
    );

    if (result != null && mounted) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _geofenceRadius = result.geofenceRadius;
        _isGeofenceActive = result.isGeofenceActive;
        _geofenceAddress = result.address;
        if (_detailAddressController.text.isEmpty && result.address != null) {
          _detailAddressController.text = result.address!;
        }
      });
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Ganti Akun?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Anda akan keluar dan kembali ke halaman login.',
          style: GoogleFonts.inter(color: AppTheme.textBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(authRepositoryProvider).signOut();
      if (mounted) {
        context.goNamed(RouteNames.login);
      }
    }
  }

  Future<void> _submitAndFinish({bool withKit = true}) async {
    if (_isSubmitting) return;

    final businessName = _businessNameController.text.trim();
    if (businessName.isEmpty) {
      setState(() => _currentStep = 0);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nama Toko wajib diisi')));
      return;
    }

    setState(() => _isSubmitting = true);
    showOnboardingSubmittingDialog(context);

    try {
      final rawDigits = _cleanDisplayPhone(_phoneController.text.trim());
      final cleanPhone = rawDigits.isNotEmpty ? '+62$rawDigits' : null;
      final slug = _generateSlug(businessName);

      // Gabungkan alamat lengkap dari wilayah & detail
      final addressParts = [
        if (_detailAddressController.text.trim().isNotEmpty)
          _detailAddressController.text.trim(),
        if (_wilayahSelection != null && _wilayahSelection!.hasSelection)
          _wilayahSelection!.formattedText
        else if (_geofenceAddress != null)
          _geofenceAddress!,
      ];
      final combinedAddress = addressParts.isNotEmpty
          ? addressParts.join(' • ')
          : null;

      final orderCode = 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      await ref
          .read(authRepositoryProvider)
          .createOwnerBusiness(
            businessName: businessName,
            slug: slug.isNotEmpty
                ? slug
                : 'toko-${DateTime.now().millisecondsSinceEpoch % 10000}',
            businessPhone: cleanPhone,
            ownerName: _ownerNameController.text.trim().isNotEmpty
                ? _ownerNameController.text.trim()
                : null,
            businessAddress: combinedAddress,
            province: _wilayahSelection?.province?.name,
            city: _wilayahSelection?.regency?.name,
            district: _wilayahSelection?.district?.name,
            village: _wilayahSelection?.village?.name,
            starterKitId: withKit ? _selectedKit?.id : null,
            starterKitName: withKit ? _selectedKit?.name : null,
            orderCode: withKit ? orderCode : null,
            latitude: _latitude,
            longitude: _longitude,
            geofenceRadius: _geofenceRadius,
            isGeofenceActive: _isGeofenceActive,
            businessType: 'retail',
            enabledFeatures: const [
              'pos',
              'cashier',
              'inventory',
              'reports',
              'realtime_notifications',
            ],
          );

      ref.invalidate(homeBootstrapProvider);
      ref.invalidate(ownerBootstrapProvider);

      try {
        await ref
            .read(homeBootstrapProvider.future)
            .timeout(const Duration(seconds: 8));
      } catch (_) {}

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading
      }

      // Jika memesan starter kit, buka WhatsApp CS Syupeo untuk instruksi pembayaran
      if (withKit && _selectedKit != null) {
        try {
          final kitTitle = _selectedKit!.name;
          final kitPrice = 'Rp ${NumberFormat.decimalPattern('id_ID').format(_selectedKit!.price)}';
          final message =
              'Halo Tim Syupeo, saya ingin memesan $kitTitle ($kitPrice) untuk toko "$businessName" (Kode Order: $orderCode).\n\n'
              'Nama Pemilik: ${_ownerNameController.text.trim().isNotEmpty ? _ownerNameController.text.trim() : 'Owner'}\n'
              'Alamat Toko: ${combinedAddress ?? '-'}\n'
              'No. WhatsApp: ${cleanPhone ?? '-'}\n\n'
              'Mohon instruksi pembayaran dan aktivasi akun toko saya. Terima kasih!';

          final waUrl = 'https://wa.me/6285624277920?text=${Uri.encodeComponent(message)}';
          final uri = Uri.parse(waUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (waErr) {
          debugPrint('[owner_onboarding] launch WA note: $waErr');
        }
      }

      if (mounted) {
        context.goNamed(RouteNames.dashboard);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat toko: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapAsync = ref.watch(ownerBootstrapProvider);

    return bootstrapAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppTheme.surfaceSubtle,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: AppTheme.surfaceSubtle,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppTheme.danger,
                ),
                const SizedBox(height: 12),
                Text(
                  'Gagal memuat profil',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(ownerBootstrapProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (bootstrap) {
        _prefillFromProfile(bootstrap.profile);

        return Scaffold(
          backgroundColor: AppTheme.surfaceSubtle,
          appBar: AppBar(
            backgroundColor: AppTheme.surface,
            elevation: 0,
            leading: _currentStep > 0
                ? IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppTheme.text,
                    ),
                    onPressed: () => setState(() => _currentStep = 0),
                  )
                : null,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/icons/logo.png', width: 26, height: 26),
                const SizedBox(width: 8),
                Text(
                  'Syupeo Mitra',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: _signOut,
                icon: const Icon(
                  Icons.logout_rounded,
                  size: 16,
                  color: AppTheme.textMuted,
                ),
                label: Text(
                  'Keluar',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: _currentStep == 0
                    ? OnboardingShopDetailsStep(
                        formKey: _formKey,
                        businessNameController: _businessNameController,
                        ownerNameController: _ownerNameController,
                        phoneController: _phoneController,
                        detailAddressController: _detailAddressController,
                        wilayahSelection: _wilayahSelection,
                        onPickWilayah: _pickWilayah,
                        latitude: _latitude,
                        longitude: _longitude,
                        geofenceRadius: _geofenceRadius,
                        isGeofenceActive: _isGeofenceActive,
                        onPickGeofenceLocation: _pickGeofenceLocation,
                        onNextStep: () {
                          if (_formKey.currentState!.validate()) {
                            setState(() => _currentStep = 1);
                          }
                        },
                        onSkip: () {
                          if (_formKey.currentState!.validate()) {
                            _submitAndFinish(withKit: false);
                          }
                        },
                        cleanDisplayPhone: _cleanDisplayPhone,
                      )
                    : OnboardingStarterKitStep(
                        selectedKit: _selectedKit,
                        onSelectKit: (kit) {
                          setState(() => _selectedKit = kit);
                        },
                        onSubmitWithKit: () {
                          _submitAndFinish(withKit: true);
                        },
                        onSkip: () {
                          _submitAndFinish(withKit: false);
                        },
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
