import 'dart:async';
import 'package:dpos/core/domain/business_template_models.dart';
import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/core/services/location_search_service.dart';
import 'package:dpos/features/auth/data/auth_repository.dart';
import 'package:dpos/features/auth/domain/auth_models.dart';
import 'package:dpos/features/auth/presentation/auth_ui_helpers.dart';
import 'package:dpos/features/home/application/home_bootstrap_provider.dart';
import 'package:dpos/features/subscription/presentation/providers/business_template_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final _slugController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _coordsManualController = TextEditingController();
  final _locationSearchController = TextEditingController();

  int _currentStep = 0; // 0 = Pilih Jenis Usaha, 1 = Detail Profil Toko
  BusinessTypeTemplate? _selectedTemplate;
  double? _latitude;
  double? _longitude;
  int _geofenceRadius = 5000;
  bool _isGeofenceActive = true;
  bool _isDetectingLocation = false;
  bool _showManualCoords = false;
  bool _isSearchingLocation = false;
  List<LocationPlaceItem> _locationSearchResults = [];
  Timer? _locationDebounceTimer;
  bool _isSubmitting = false;
  bool _isCustomizingSlug = false;
  bool _hasManuallyEditedSlug = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _locationDebounceTimer?.cancel();
    _businessNameController.dispose();
    _slugController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _coordsManualController.dispose();
    _locationSearchController.dispose();
    super.dispose();
  }

  void _onBusinessNameChanged(String value) {
    if (!_hasManuallyEditedSlug) {
      final generated = _generateSlug(value);
      _slugController.text = generated;
    }
    setState(() {});
  }

  String _generateSlug(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }

  void _prefillFromProfile(AppProfile? profile) {
    if (profile == null || _prefilled) return;
    _prefilled = true;

    if (_emailController.text.isEmpty && profile.email != null) {
      _emailController.text = profile.email!;
    }
    if (_phoneController.text.isEmpty && profile.phone != null) {
      _phoneController.text = profile.phone!;
    }
    if (_businessNameController.text.isEmpty && profile.fullName != null) {
      final cleanName = profile.fullName!.trim();
      final suggested = cleanName.isNotEmpty ? 'Toko $cleanName' : 'Toko Saya';
      _businessNameController.text = suggested;
      _slugController.text = _generateSlug(suggested);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Ganti Akun?',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Anda akan keluar dari akun ini dan kembali ke halaman login.',
          style: GoogleFonts.inter(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(authRepositoryProvider).signOut();
        if (mounted) {
          context.goNamed(RouteNames.login);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal logout: $e')));
        }
      }
    }
  }

  Future<void> _detectLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Layanan lokasi (GPS) di perangkat tidak aktif. Mohon aktifkan GPS.',
              ),
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
                content: Text(
                  'Izin lokasi ditolak. Anda tetap dapat memasukkan koordinat manual.',
                ),
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
              content: Text(
                'Izin lokasi ditolak permanen. Buka pengaturan aplikasi untuk mengizinkan.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _coordsManualController.text =
              '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Titik koordinat GPS toko berhasil dikunci!'),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil titik GPS: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  Future<void> _openInMaps() async {
    if (_latitude == null || _longitude == null) return;
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$_latitude,$_longitude',
    );
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[OwnerOnboardingScreen] Gagal membuka maps: $e');
    }
  }

  void _parseManualLocation() {
    final text = _coordsManualController.text.trim();
    if (text.isEmpty) return;

    final regex = RegExp(
      r'[-+]?([0-9]*\.[0-9]+|[0-9]+)[,\s]+[-+]?([0-9]*\.[0-9]+|[0-9]+)',
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      final lat = double.tryParse(match.group(1) ?? '');
      final lng = double.tryParse(match.group(2) ?? '');
      if (lat != null &&
          lng != null &&
          lat >= -90 &&
          lat <= 90 &&
          lng >= -180 &&
          lng <= 180) {
        setState(() {
          _latitude = lat;
          _longitude = lng;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF16A34A),
            content: Text('Titik koordinat berhasil diterapkan!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Format koordinat tidak valid. Contoh valid: -6.2088, 106.8456',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Inline location search and geofencing are now directly embedded in the card.


  void _onLocationSearchChanged(String query) {
    _locationDebounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() {
        _locationSearchResults = [];
        _isSearchingLocation = false;
      });
      return;
    }

    _locationDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearchingLocation = true);
      final results = await LocationSearchService.instance.searchPlaces(
        trimmed,
        userLat: _latitude,
        userLng: _longitude,
      );
      if (mounted) {
        setState(() {
          _locationSearchResults = results;
          _isSearchingLocation = false;
        });
      }
    });
  }

  Future<void> _onSelectLocationPlace(LocationPlaceItem item) async {
    setState(() => _isSearchingLocation = true);
    final detailed = await LocationSearchService.instance.getPlaceDetails(item);
    if (mounted) {
      final finalItem = detailed ?? item;
      setState(() {
        _latitude = finalItem.latitude;
        _longitude = finalItem.longitude;
        _addressController.text = finalItem.displayName;
        _coordsManualController.text =
            '${finalItem.latitude.toStringAsFixed(6)}, ${finalItem.longitude.toStringAsFixed(6)}';
        _locationSearchResults = [];
        _locationSearchController.clear();
        _isSearchingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF16A34A),
          content: Text('Lokasi toko berhasil dikunci dari Google Maps!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (_selectedTemplate == null) {
      setState(() => _currentStep = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih jenis usaha Anda terlebih dahulu.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final rawSlug = _slugController.text.trim();
    final slug = rawSlug.isNotEmpty
        ? _generateSlug(rawSlug)
        : _generateSlug(_businessNameController.text.trim());

    if (slug.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link toko wajib diisi (minimal 1 karakter).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    var dialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF7A00).withValues(alpha: 0.20),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/icons/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF7A00),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Membuka Toko Baru Anda...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF18181B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sedang mengonfigurasi database kasir, produk awal, & tautan katalog online...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF71717A),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => dialogOpen = false);

    try {
      final rawPhone = _phoneController.text.trim();
      final cleanPhone = rawPhone.isNotEmpty
          ? normalizeIndonesianPhone(rawPhone)
          : null;

      await ref
          .read(authRepositoryProvider)
          .createOwnerBusiness(
            businessName: _businessNameController.text.trim(),
            slug: slug,
            businessPhone: cleanPhone,
            businessEmail: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            businessAddress: _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
            latitude: _latitude,
            longitude: _longitude,
            geofenceRadius: _geofenceRadius,
            isGeofenceActive: _isGeofenceActive,
            businessType: _selectedTemplate!.code,
            enabledFeatures: _selectedTemplate!.defaultEnabledFeatures,
          );

      ref.invalidate(homeBootstrapProvider);
      ref.invalidate(ownerBootstrapProvider);

      try {
        await ref
            .read(homeBootstrapProvider.future)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('[OwnerOnboardingScreen] bootstrap sync warning: $e');
      }

      if (!mounted) return;
      if (dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
      context.goNamed(RouteNames.dashboard);
    } catch (error) {
      if (!mounted) return;
      if (dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyiapkan toko: $error'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapAsync = ref.watch(ownerBootstrapProvider);

    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF9F6),
        body: bootstrapAsync.when(
          data: (bootstrap) {
            // Jika sudah ada bisnis, langsung arahkan ke dashboard
            if (bootstrap.business != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) context.goNamed(RouteNames.dashboard);
              });
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A00)),
                ),
              );
            }

            _prefillFromProfile(bootstrap.profile);

            return SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    children: [
                      // ── Top Navigation Bar ──
                      _buildTopBar(context),

                      // ── Step Progress Indicator ──
                      _buildStepProgress(),
                      const SizedBox(height: 20),

                      // ── Dynamic Step Content ──
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          layoutBuilder: (currentChild, previousChildren) =>
                              Stack(
                                alignment: Alignment.topCenter,
                                children: [
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              ),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: _currentStep == 0
                              ? _buildStepCategorySelection(context)
                              : _buildStepStoreDetails(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A00)),
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Gagal memuat data akun',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF71717A),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => ref.refresh(ownerBootstrapProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Coba Lagi'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A00),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TOP BAR: Logo + Logout / Switch Account
  // ---------------------------------------------------------------------------
  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4E4E7)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Image.asset(
              'assets/icons/logo.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mangga POS',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF18181B),
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Buka Toko Baru',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFF7A00),
                ),
              ),
            ],
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _isSubmitting ? null : _signOut,
            icon: const Icon(
              Icons.logout_rounded,
              size: 16,
              color: Color(0xFF71717A),
            ),
            label: Text(
              'Ganti Akun',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF71717A),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP PROGRESS BAR
  // ---------------------------------------------------------------------------
  Widget _buildStepProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
      child: Column(
        children: [
          Row(
            children: [
              _buildStepPill(
                stepIndex: 0,
                title: '1. Jenis Usaha',
                isActive: _currentStep == 0,
                isCompleted: _currentStep > 0,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: _currentStep > 0
                        ? const Color(0xFFFF7A00)
                        : const Color(0xFFE4E4E7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildStepPill(
                stepIndex: 1,
                title: '2. Info Toko',
                isActive: _currentStep == 1,
                isCompleted: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepPill({
    required int stepIndex,
    required String title,
    required bool isActive,
    required bool isCompleted,
  }) {
    final bgColor = isCompleted
        ? const Color(0xFFDCFCE7)
        : isActive
        ? const Color(0xFFFFF7ED)
        : const Color(0xFFF4F4F5);

    final textColor = isCompleted
        ? const Color(0xFF15803D)
        : isActive
        ? const Color(0xFFFF7A00)
        : const Color(0xFFA1A1AA);

    return InkWell(
      onTap: !_isSubmitting && isCompleted
          ? () => setState(() => _currentStep = stepIndex)
          : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFFFF7A00).withValues(alpha: 0.4)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCompleted) ...[
              const Icon(
                Icons.check_circle_rounded,
                size: 14,
                color: Color(0xFF15803D),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isActive || isCompleted
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 1: CATEGORY SELECTION
  // ---------------------------------------------------------------------------
  Widget _buildStepCategorySelection(BuildContext context) {
    final templatesAsync = ref.watch(businessTypeTemplatesProvider);

    return SingleChildScrollView(
      key: const ValueKey('step_category'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Headline
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'LANGKAH 1 DARI 2',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFF7A00),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pilih Jenis Usaha Anda',
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF18181B),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kami akan otomatis mengaktifkan modul kasir, manajemen pesanan, meja, atau stok sesuai jenis usaha Anda.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF71717A),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Template Cards
          templatesAsync.when(
            data: (templates) {
              if (templates.isEmpty) {
                return _buildEmptyTemplates();
              }

              // Auto-select first template if none selected yet
              if (_selectedTemplate == null && templates.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedTemplate == null) {
                    setState(() => _selectedTemplate = templates.first);
                  }
                });
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: templates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final template = templates[index];
                  final isSelected = _selectedTemplate?.id == template.id;
                  final info = _getCategoryInfo(template);

                  return _buildCategoryCard(
                    template: template,
                    info: info,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() => _selectedTemplate = template);
                    },
                  );
                },
              );
            },
            loading: () => Column(
              children: List.generate(
                3,
                (index) => Container(
                  height: 104,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE4E4E7)),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF7A00),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            error: (e, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Gagal memuat kategori usaha: $e',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Next Step Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: _selectedTemplate == null
                  ? null
                  : () {
                      setState(() => _currentStep = 1);
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledBackgroundColor: const Color(0xFFE4E4E7),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Lanjut ke Profil Toko',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required BusinessTypeTemplate template,
    required _CategoryDisplayInfo info,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? info.lightColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? info.primaryColor : const Color(0xFFE4E4E7),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? info.primaryColor.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: isSelected ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? info.primaryColor
                      : const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  info.icon,
                  size: 24,
                  color: isSelected ? Colors.white : const Color(0xFF52525B),
                ),
              ),
              const SizedBox(width: 14),

              // Title, Subtitle, & Tag Pills
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            info.title,
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF18181B),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        // Radio circle
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? info.primaryColor
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? info.primaryColor
                                  : const Color(0xFFA1A1AA),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF71717A),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Feature tags
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: info.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.85)
                                : const Color(0xFFF4F4F5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? info.primaryColor.withValues(alpha: 0.25)
                                  : const Color(0xFFE4E4E7),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? info.primaryColor
                                  : const Color(0xFF52525B),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTemplates() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E4E7)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 40,
            color: Color(0xFFA1A1AA),
          ),
          const SizedBox(height: 12),
          Text(
            'Tidak ada template bisnis yang tersedia.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF71717A),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2: STORE DETAILS & LIVE DIGITAL LINK PREVIEW
  // ---------------------------------------------------------------------------
  Widget _buildStepStoreDetails(BuildContext context) {
    final selectedInfo = _selectedTemplate != null
        ? _getCategoryInfo(_selectedTemplate!)
        : null;

    final currentSlug = _slugController.text.trim().isNotEmpty
        ? _slugController.text.trim()
        : 'nama-toko-anda';

    return SingleChildScrollView(
      key: const ValueKey('step_details'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button & category badge
            Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _currentStep = 0),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_back_rounded,
                          size: 16,
                          color: Color(0xFF71717A),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Kategori Usaha',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF71717A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (selectedInfo != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: selectedInfo.lightColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selectedInfo.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selectedInfo.icon,
                          size: 14,
                          color: selectedInfo.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          selectedInfo.title,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: selectedInfo.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              'Identitas & Alamat Toko',
              style: GoogleFonts.manrope(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF18181B),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Informasi ini akan dicetak di struk belanja kasir dan katalog digital pelanggan Anda.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF71717A),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),

            // Card Container for Form
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE4E4E7)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Nama Toko
                  Text(
                    'Nama Toko / Usaha *',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF18181B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _businessNameController,
                    onChanged: _onBusinessNameChanged,
                    textInputAction: TextInputAction.next,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF18181B),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Contoh: Kopi Kulo Tebet, Warung Berkah',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFFA1A1AA),
                      ),
                      prefixIcon: const Icon(
                        Icons.store_rounded,
                        color: Color(0xFFFF7A00),
                        size: 20,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF7A00),
                          width: 1.8,
                        ),
                      ),
                    ),
                    validator: (val) {
                      if ((val ?? '').trim().isEmpty) {
                        return 'Nama toko wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // 2. Live Interactive Digital Store Link Preview (Anti-AI-Slop)
                  _buildDigitalStoreLinkCard(currentSlug),
                  const SizedBox(height: 20),

                  // 3. Nomor WhatsApp Toko / Kasir
                  Text(
                    'Nomor WhatsApp Kasir / Toko',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF18181B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Untuk mengirimkan struk belanja digital langsung ke WhatsApp pelanggan.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF71717A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF18181B),
                    ),
                    decoration: InputDecoration(
                      hintText: '812-3456-7890',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFFA1A1AA),
                      ),
                      prefixIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Color(0xFFE4E4E7)),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.phone_android_rounded,
                              size: 18,
                              color: Color(0xFF15803D),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '+62',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF18181B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF7A00),
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Email Pemilik / Bisnis
                  Text(
                    'Email Pemilik / Toko (Opsional)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF18181B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Untuk menerima laporan rekap kasir harian & notifikasi akun.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF71717A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF18181B),
                    ),
                    decoration: InputDecoration(
                      hintText: 'owner@tokosaya.com',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFFA1A1AA),
                      ),
                      prefixIcon: const Icon(
                        Icons.mail_outline_rounded,
                        color: Color(0xFF71717A),
                        size: 20,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF7A00),
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. Alamat Lengkap Toko / Usaha
                  Text(
                    'Alamat Lengkap Toko / Outlet *',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF18181B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dicetak di struk belanja kasir & ditampilkan pada direktori website toko online.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF71717A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _addressController,
                    minLines: 2,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF18181B),
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Contoh: Jl. Ahmad Yani No. 45, RT 02/RW 04, Kel. Sukamaju, Kec. Cilodong, Kota Depok',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFFA1A1AA),
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFFFF7A00),
                          size: 20,
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF7A00),
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 6. Pin Titik Lokasi Toko / GPS (Online Web Ready)
                  _buildLocationPickerCard(),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Feature Highlights Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF15803D).withValues(alpha: 0.20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Color(0xFF15803D),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Semua data Anda tersimpan aman dan dapat langsung digunakan di Android, Tablet POS, & Windows.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF166534),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // CTA Button: Buka Toko Sekarang
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A00),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.rocket_launch_rounded, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _isSubmitting
                          ? 'Sedang Membuka Toko...'
                          : 'Buka Toko & Aktifkan Kasir',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DIGITAL STORE LINK PREVIEW (Anti-AI-Slop replacement for technical "Slug")
  // ---------------------------------------------------------------------------
  Widget _buildDigitalStoreLinkCard(String slug) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF7A00).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.language_rounded,
                size: 16,
                color: Color(0xFFFF7A00),
              ),
              const SizedBox(width: 6),
              Text(
                'Website & Katalog Digital Toko',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFC2410C),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  setState(() {
                    _isCustomizingSlug = !_isCustomizingSlug;
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isCustomizingSlug
                            ? Icons.check_circle_outline_rounded
                            : Icons.edit_rounded,
                        size: 13,
                        color: const Color(0xFFFF7A00),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isCustomizingSlug ? 'Selesai' : 'Ubah Link',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFF7A00),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Visual URL Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Row(
              children: [
                Text(
                  'pos.mudahkan.online/s/',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF71717A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Text(
                    slug,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFF7A00),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Inline manual edit if user toggles custom slug
          if (_isCustomizingSlug) ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: _slugController,
              onChanged: (val) {
                _hasManuallyEditedSlug = true;
                setState(() {});
              },
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF18181B),
              ),
              decoration: InputDecoration(
                hintText: 'nama-toko-anda',
                helperText: 'Gunakan huruf kecil, angka, dan tanda strip (-)',
                helperStyle: GoogleFonts.inter(fontSize: 11),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFFED7AA)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFFFF7A00),
                    width: 1.5,
                  ),
                ),
              ),
              validator: (val) {
                final text = (val ?? '').trim();
                if (text.isEmpty) {
                  return 'Link toko tidak boleh kosong';
                }
                if (!RegExp(r'^[a-z0-9-]+$').hasMatch(text)) {
                  return 'Hanya boleh huruf kecil, angka, dan tanda strip (-)';
                }
                return null;
              },
            ),
          ],

          const SizedBox(height: 6),
          Text(
            'Link ini bisa Anda pasang di bio Instagram & dibagikan ke pelanggan untuk melihat menu serta pesan online.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF71717A),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LOCATION PIN & GPS PICKER (Untuk direktori platform web online & ongkir)
  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // LOCATION PIN & GEOFENCE (INLINE - Direct Google Maps Search, No Modal)
  // ---------------------------------------------------------------------------
  Widget _buildLocationPickerCard() {
    final hasLocation = _latitude != null && _longitude != null;
    const radiusOptions = [1000, 3000, 5000, 10000, 20000];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasLocation ? const Color(0xFFF0FDF4) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasLocation ? const Color(0xFF86EFAC) : const Color(0xFFE4E4E7),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: hasLocation ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasLocation ? Icons.check_circle_rounded : Icons.search_rounded,
                  size: 16,
                  color: hasLocation ? const Color(0xFF15803D) : const Color(0xFFFF7A00),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasLocation
                          ? 'Titik GPS Toko Terkunci'
                          : 'Cari & Kunci Lokasi Toko (Google Maps)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: hasLocation
                            ? const Color(0xFF15803D)
                            : const Color(0xFF18181B),
                      ),
                    ),
                    Text(
                      'Untuk direktori web online & jangkauan delivery',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF71717A),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasLocation ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Web Ready',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: hasLocation ? const Color(0xFF15803D) : const Color(0xFFC2410C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. INLINE SEARCH INPUT (Google Places API New)
          TextFormField(
            controller: _locationSearchController,
            onChanged: _onLocationSearchChanged,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF18181B),
            ),
            decoration: InputDecoration(
              hintText: 'Ketik nama jalan / tempat / kota di sini...',
              hintStyle: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFFA1A1AA),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFFFF7A00),
                size: 20,
              ),
              suffixIcon: _isSearchingLocation
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A00)),
                        ),
                      ),
                    )
                  : _locationSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _locationSearchController.clear();
                            setState(() => _locationSearchResults = []);
                          },
                        )
                      : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFFF7A00),
                  width: 1.8,
                ),
              ),
            ),
          ),

          // 2. INLINE SEARCH SUGGESTIONS DROPDOWN
          if (_locationSearchResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD8A8), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: _locationSearchResults.length > 5
                      ? 5
                      : _locationSearchResults.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    thickness: 0.8,
                    color: Color(0xFFF4F4F5),
                  ),
                  itemBuilder: (context, index) {
                    final place = _locationSearchResults[index];
                    return InkWell(
                      onTap: () => _onSelectLocationPlace(place),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFF7ED),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                size: 16,
                                color: Color(0xFFFF7A00),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    place.title.isNotEmpty
                                        ? place.title
                                        : place.displayName,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF18181B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (place.subtitle.isNotEmpty)
                                    Text(
                                      place.subtitle,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: const Color(0xFF71717A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.north_west_rounded,
                              size: 14,
                              color: Color(0xFFA1A1AA),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // 3. TOMBOL GPS & BUKA DI MAPS
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isDetectingLocation ? null : _detectLocation,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF18181B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _isDetectingLocation
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A00)),
                        ),
                      )
                    : const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF15803D)),
                label: Text(
                  _isDetectingLocation ? 'Mencari GPS...' : 'Kunci GPS Saat Ini',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (hasLocation) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _openInMaps,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.map_rounded, size: 16, color: Color(0xFF2563EB)),
                  label: Text(
                    'Buka di Maps',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // 4. STATUS KOORDINAT TERKUNCI (Jika sudah dipilih)
          if (hasLocation) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: Color(0xFF15803D),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Terkunci: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF166534),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _latitude = null;
                        _longitude = null;
                        _coordsManualController.clear();
                      });
                    },
                    child: Text(
                      'Reset',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // 5. PENGATURAN GEOFENCING RADIUS (INLINE CHIPS)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Radius Jangkauan / Delivery',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF18181B),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isGeofenceActive ? 'Aktif' : 'Nonaktif',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _isGeofenceActive
                          ? const Color(0xFF15803D)
                          : const Color(0xFF71717A),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: _isGeofenceActive,
                      activeColor: const Color(0xFFFF7A00),
                      onChanged: (val) {
                        setState(() => _isGeofenceActive = val);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: radiusOptions.map((radius) {
              final isSelected = _geofenceRadius == radius;
              final label = radius >= 1000
                  ? '${(radius / 1000).toInt()} km'
                  : '$radius m';
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _geofenceRadius = radius);
                  }
                },
                selectedColor: const Color(0xFFFF7A00),
                backgroundColor: Colors.white,
                labelStyle: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF3F3F46),
                ),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFFFF7A00)
                      : const Color(0xFFE4E4E7),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 10),

          // 6. TOGGLE INPUT MANUAL / LINK MAPS
          InkWell(
            onTap: () {
              setState(() {
                _showManualCoords = !_showManualCoords;
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showManualCoords
                        ? Icons.expand_less_rounded
                        : Icons.add_link_rounded,
                    size: 14,
                    color: const Color(0xFF71717A),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showManualCoords
                        ? 'Tutup input koordinat manual'
                        : 'Atau masukkan koordinat manual / link Maps',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF71717A),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_showManualCoords) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _coordsManualController,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: '-6.2088, 106.8456 atau link Maps',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFFA1A1AA),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: _parseManualLocation,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF18181B),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Terapkan',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER: Category Visual Metadata
  // ---------------------------------------------------------------------------
  _CategoryDisplayInfo _getCategoryInfo(BusinessTypeTemplate template) {
    switch (template.code.toLowerCase()) {
      case 'fnb':
        return const _CategoryDisplayInfo(
          title: 'Resto, Cafe & Kuliner',
          subtitle: 'Kafe, resto, bakery, warung makan, & kedai kopi.',
          icon: Icons.restaurant_rounded,
          primaryColor: Color(0xFFFF7A00),
          lightColor: Color(0xFFFFF7ED),
          tags: [
            '🍽️ Meja & Dine-in',
            '👨‍🍳 Tiket Dapur / KDS',
            '🏷️ Varian & Topping',
          ],
        );
      case 'retail':
        return const _CategoryDisplayInfo(
          title: 'Retail, Toko & Minimarket',
          subtitle: 'Toko sembako, butik fashion, vape, & aksesoris.',
          icon: Icons.storefront_rounded,
          primaryColor: Color(0xFF15803D),
          lightColor: Color(0xFFF0FDF4),
          tags: [
            '📦 Manajemen Stok',
            '📷 Scan Barcode Kilat',
            '⚠️ Notif Stok Tipis',
          ],
        );
      case 'service':
        return const _CategoryDisplayInfo(
          title: 'Jasa, Salon & Bengkel',
          subtitle:
              'Barbershop, salon kecantikan, laundry, car wash, & servis.',
          icon: Icons.content_cut_rounded,
          primaryColor: Color(0xFF7C3AED),
          lightColor: Color(0xFFF5F3FF),
          tags: [
            '✂️ Nota Layanan',
            '👥 Komisi Karyawan',
            '📅 Booking Reservasi',
          ],
        );
      case 'general':
      default:
        return _CategoryDisplayInfo(
          title: template.name.isNotEmpty
              ? template.name
              : 'Usaha Umum & Lainnya',
          subtitle: template.description?.isNotEmpty == true
              ? template.description!
              : 'Untuk jenis usaha fleksibel dengan seluruh modul kasir aktif.',
          icon: _getIconData(template.iconName),
          primaryColor: const Color(0xFF0284C7),
          lightColor: const Color(0xFFF0F9FF),
          tags: const [
            '⚡ Transaksi Kasir Kilat',
            '💳 QRIS & Multi-Bayar',
            '📊 Laporan Laba Rugi',
          ],
        );
    }
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'restaurant_rounded':
        return Icons.restaurant_rounded;
      case 'shopping_bag_rounded':
        return Icons.shopping_bag_rounded;
      case 'handyman_rounded':
        return Icons.handyman_rounded;
      case 'apps_rounded':
        return Icons.apps_rounded;
      default:
        return Icons.store_rounded;
    }
  }
}

class _CategoryDisplayInfo {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color primaryColor;
  final Color lightColor;
  final List<String> tags;

  const _CategoryDisplayInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryColor,
    required this.lightColor,
    required this.tags,
  });
}
