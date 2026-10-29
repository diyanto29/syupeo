import 'dart:async';
import 'package:dpos/core/theme/app_theme.dart';
import 'package:dpos/core/domain/bootstrap_models.dart';
import 'package:dpos/core/domain/business_models.dart';
import 'package:dpos/core/domain/business_template_models.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/services/location_search_service.dart';
import 'package:dpos/core/widgets/app_tablet_nav.dart';
import 'package:dpos/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class BusinessProfileEditScreen extends ConsumerStatefulWidget {
  const BusinessProfileEditScreen({super.key});

  @override
  ConsumerState<BusinessProfileEditScreen> createState() =>
      _BusinessProfileEditScreenState();
}

class _BusinessProfileEditScreenState
    extends ConsumerState<BusinessProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _slugController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _locationSearchController = TextEditingController();
  double? _latitude;
  double? _longitude;
  int _geofenceRadius = 5000;
  bool _isGeofenceActive = true;
  bool _isDetectingGps = false;
  bool _isSearchingLocation = false;
  List<LocationPlaceItem> _locationSearchResults = [];
  Timer? _locationDebounceTimer;
  String _selectedTimezone = _timezoneOptions.first.value;
  String? _selectedBusinessType;
  List<BusinessTypeTemplate> _templates = [];
  bool _didPrefill = false;
  bool _isSubmitting = false;
  bool _isLoadingTemplates = true;
  bool _isCustomizingSlug = false;
  bool _hasManuallyEditedSlug = false;

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

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final templates = await ref
          .read(authRepositoryProvider)
          .fetchBusinessTypeTemplates();
      if (mounted) {
        setState(() {
          _templates = templates;
          _isLoadingTemplates = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTemplates = false);
      }
    }
  }

  @override
  void dispose() {
    _locationDebounceTimer?.cancel();
    _locationSearchController.dispose();
    _businessNameController.dispose();
    _slugController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ownerNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

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

    _locationDebounceTimer = Timer(const Duration(milliseconds: 450), () async {
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
        _locationSearchResults = [];
        _locationSearchController.clear();
        _isSearchingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF16A34A),
          content: Text('Titik lokasi berhasil dikunci dari Google Maps!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }


  Future<void> _detectCurrentGps() async {
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
            content: Text('Titik GPS toko berhasil dikunci!'),
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
      debugPrint('[BusinessProfileEdit] Gagal buka maps: $e');
    }
  }

  Future<void> _save(Business business) async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);

      // Normalisasi format nomor telepon dengan prefix +62
      String? cleanPhone;
      final rawDigits = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
      if (rawDigits.isNotEmpty) {
        cleanPhone = '+62$rawDigits';
      }

      final rawSlug = _slugController.text.trim();
      final slug = rawSlug.isNotEmpty
          ? _generateSlug(rawSlug)
          : _generateSlug(_businessNameController.text.trim());

      // Update basic profile with location & geofencing
      await authRepo.updateOwnerBusinessProfile(
        businessId: business.id,
        businessName: _businessNameController.text.trim(),
        slug: slug,
        timezone: _selectedTimezone,
        businessPhone: cleanPhone,
        businessEmail: _nullable(_emailController.text),
        businessAddress: _nullable(_addressController.text),
        latitude: _latitude,
        longitude: _longitude,
        geofenceRadius: _geofenceRadius,
        isGeofenceActive: _isGeofenceActive,
        ownerName: _nullable(_ownerNameController.text),
        businessType: _selectedBusinessType,
      );

      // If business type changed, apply the template
      if (_selectedBusinessType != null &&
          _selectedBusinessType != business.businessType) {
        await authRepo.applyBusinessTypeTemplate(
          businessId: business.id,
          templateCode: _selectedBusinessType!,
        );
      }

      ref.invalidate(homeBootstrapProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF15803D),
          content: Text('Profil toko berhasil diperbarui!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).maybePop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          content: Text('Gagal menyimpan profil toko: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _prefill(OwnerBootstrap bootstrap) {
    if (_didPrefill) {
      return;
    }

    final business = bootstrap.business;
    final profile = bootstrap.profile;
    if (business == null) {
      return;
    }

    _businessNameController.text = business.name;
    _slugController.text = business.slug ?? _generateSlug(business.name);
    _emailController.text = business.email ?? '';

    // Bersihkan prefix +62 / 62 / 0 agar input field bersih seperti di onboarding
    final rawPhone = (business.phone != null && business.phone!.trim().isNotEmpty)
        ? business.phone!
        : (bootstrap.currentOutlet?.phone ??
            bootstrap.outlets.where((o) => o.phone != null && o.phone!.trim().isNotEmpty).firstOrNull?.phone ??
            '');
    var cleanPhone = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('62')) {
      cleanPhone = cleanPhone.substring(2);
    } else if (cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1);
    }
    _phoneController.text = cleanPhone;

    _ownerNameController.text = profile?.fullName ?? '';
    _addressController.text = business.address ?? (bootstrap.currentOutlet?.address ?? '');
    _latitude = business.latitude ?? bootstrap.currentOutlet?.latitude;
    _longitude = business.longitude ?? bootstrap.currentOutlet?.longitude;
    _geofenceRadius = business.geofenceRadius ?? bootstrap.currentOutlet?.geofenceRadius ?? 5000;
    _isGeofenceActive = business.isGeofenceActive;
    _selectedTimezone =
        _timezoneOptions.any((option) => option.value == business.timezone)
        ? business.timezone
        : _timezoneOptions.first.value;
    _selectedBusinessType = business.businessType;
    _didPrefill = true;
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 600;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = theme.extension<ConciergeThemeTokens>();
    final bootstrapAsync = ref.watch(homeBootstrapProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppOwnerDrawer(),
      appBar: isTablet
          ? AppTabletHeader(
              title: const Text('Edit Profil Bisnis'),
              badge: const AppTabletBadge(label: 'Mangga POS'),
              actions: [
                bootstrapAsync.maybeWhen(
                  data: (bootstrap) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ElevatedButton.icon(
                      onPressed: bootstrap.business == null || _isSubmitting
                          ? null
                          : () => _save(bootstrap.business!),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(_isSubmitting ? 'Menyimpan...' : 'Simpan Perubahan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            )
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: const Text('Edit Profil Bisnis'),
              centerTitle: true,
              actions: [
                bootstrapAsync.maybeWhen(
                  data: (bootstrap) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton.icon(
                      onPressed: bootstrap.business == null || _isSubmitting
                          ? null
                          : () => _save(bootstrap.business!),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline_rounded, size: 20),
                      label: Text(_isSubmitting ? 'Saving...' : 'Save Changes'),
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
      body: SafeArea(
        child: bootstrapAsync.when(
          data: (bootstrap) {
            final business = bootstrap.business;
            if (business == null) {
              return const Center(
                child: Text('Bisnis belum tersedia untuk diedit.'),
              );
            }

            _prefill(bootstrap);

            if (isTablet) {
              return _buildTabletLayout(
                context,
                bootstrap,
                business,
                theme,
                scheme,
                tokens,
              );
            }
            return _buildMobileLayout(
              context,
              bootstrap,
              business,
              theme,
              scheme,
              tokens,
            );
          },
          error: (error, _) =>
              Center(child: Text('Gagal memuat business profile: $error')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TABLET LAYOUT (Split Screen)
  // ---------------------------------------------------------------------------
  Widget _buildTabletLayout(
    BuildContext context,
    OwnerBootstrap bootstrap,
    Business business,
    ThemeData theme,
    ColorScheme scheme,
    ConciergeThemeTokens? tokens,
  ) {
    return Row(
      children: [
        // Left Side: Informative & Branding Panel
        Expanded(
          flex: 4,
          child: Container(
            color: scheme.surfaceContainerLow,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IntroCard(
                    ownerName: bootstrap.profile?.fullName,
                    businessUpdatedAt: business.updatedAtLabel,
                    business: business,
                  ),
                  const SizedBox(height: 32),
                  _InfoNoticeCard(
                    icon: Icons.verified_user_outlined,
                    title: 'Data Aman & Terenkripsi',
                    subtitle:
                        'Semua perubahan diproteksi melalui akses owner dan koneksi Supabase.',
                    iconColor: scheme.primary,
                  ),
                  const SizedBox(height: 16),
                  _InfoNoticeCard(
                    icon: Icons.history_toggle_off_rounded,
                    title: 'Riwayat Perubahan',
                    subtitle:
                        'Terakhir diperbarui pada ${business.updatedAtLabel ?? 'akun bisnis ini'}',
                    iconColor: const Color(0xFFF59A23),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'PANDUAN PROFIL',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.secondary.withValues(alpha: 0.5),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _TipTile(
                    icon: Icons.lightbulb_outline_rounded,
                    text: 'Gunakan slug yang mudah diingat untuk akses cepat.',
                  ),
                  _TipTile(
                    icon: Icons.contact_mail_outlined,
                    text:
                        'Email bisnis akan digunakan untuk notifikasi sistem.',
                  ),
                ],
              ),
            ),
          ),
        ),
        // Right Side: Form Content
        Expanded(
          flex: 6,
          child: Container(
            color: tokens?.baseSurface ?? scheme.surface,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: _buildMainFormCard(context, business, tokens, scheme),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE LAYOUT (Single Column)
  // ---------------------------------------------------------------------------
  Widget _buildMobileLayout(
    BuildContext context,
    OwnerBootstrap bootstrap,
    Business business,
    ThemeData theme,
    ColorScheme scheme,
    ConciergeThemeTokens? tokens,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _IntroCard(
          ownerName: bootstrap.profile?.fullName,
          businessUpdatedAt: business.updatedAtLabel,
          business: business,
        ),
        const SizedBox(height: 20),
        _buildMainFormCard(context, business, tokens, scheme),
        const SizedBox(height: 20),
        _InfoNoticeCard(
          icon: Icons.verified_user_outlined,
          title: 'Data Aman & Terenkripsi',
          subtitle:
              'Semua perubahan diproteksi melalui akses owner dan koneksi Supabase.',
          iconColor: scheme.primary,
        ),
        const SizedBox(height: 12),
        _InfoNoticeCard(
          icon: Icons.history_toggle_off_rounded,
          title: 'Riwayat Perubahan',
          subtitle:
              'Terakhir diperbarui pada ${business.updatedAtLabel ?? 'akun bisnis ini'}',
          iconColor: const Color(0xFFF59A23),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED: Main Form Card
  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // SHARED: Main Form Card (Modern, Tactile, Identical to Onboarding)
  // ---------------------------------------------------------------------------
  Widget _buildMainFormCard(
    BuildContext context,
    Business business,
    ConciergeThemeTokens? tokens,
    ColorScheme scheme,
  ) {
    final currentSlug = _slugController.text.trim().isNotEmpty
        ? _slugController.text.trim()
        : (business.slug ?? 'toko-anda');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4E4E7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Nama Toko / Usaha ──
            Text(
              'Nama Toko / Usaha *',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF18181B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Nama utama yang muncul di kasir, struk belanja, dan katalog online.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF71717A),
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

            // ── 2. Live Interactive Digital Store Link Preview ──
            _buildDigitalStoreLinkCard(currentSlug),
            const SizedBox(height: 20),

            // ── 3. Nomor WhatsApp Kasir / Toko ──
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

            // ── 4. Email Pemilik / Bisnis ──
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
              textInputAction: TextInputAction.next,
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
              validator: (value) {
                final email = (value ?? '').trim();
                if (email.isEmpty) return null;
                final isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
                if (!isValid) return 'Format email belum valid';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── 5. Jenis / Kategori Usaha ──
            Text(
              'Jenis / Kategori Usaha *',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF18181B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Menyesuaikan modul kasir, katalog produk, dan alur pemesanan toko.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF71717A),
              ),
            ),
            const SizedBox(height: 8),
            _isLoadingTemplates
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A00)),
                    ),
                  )
                : DropdownButtonFormField<String>(
                    value: _selectedBusinessType,
                    isExpanded: true,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF18181B),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Pilih jenis usaha...',
                      prefixIcon: const Icon(
                        Icons.category_rounded,
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
                    items: _templates.map((t) {
                      return DropdownMenuItem<String>(
                        value: t.code,
                        child: Text(t.name),
                      );
                    }).toList(),
                    onChanged: _isSubmitting
                        ? null
                        : (val) {
                            if (val != null) {
                              setState(() => _selectedBusinessType = val);
                            }
                          },
                    validator: (value) =>
                        value == null ? 'Jenis usaha wajib dipilih' : null,
                  ),
            const SizedBox(height: 20),

            // ── 6. Alamat Lengkap Toko / Usaha ──
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

            // ── 7. Lokasi GPS & Geofencing (Inline Search & Chips) ──
            Text(
              'Titik Koordinat & Geofencing',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF18181B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Kunci titik Google Maps agar pelanggan bisa menemukan outlet Anda dan radius absen kasir akurat.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF71717A),
              ),
            ),
            const SizedBox(height: 8),
            _buildGeofenceCard(context, scheme),
            const SizedBox(height: 20),

            // ── 8. Nama Pemilik (Owner) ──
            Text(
              'Nama Pemilik Toko (Owner)',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF18181B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Nama pemilik akun utama yang mengelola toko dan kasir.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF71717A),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ownerNameController,
              textInputAction: TextInputAction.done,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF18181B),
              ),
              decoration: InputDecoration(
                hintText: 'Contoh: Ahmad Sudirman',
                prefixIcon: const Icon(
                  Icons.person_outline_rounded,
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
            const SizedBox(height: 28),

            // ── 9. CTA Button Simpan Perubahan ──
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _isSubmitting ? null : () => _save(business),
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
                    if (_isSubmitting) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Menyimpan Profil Toko...',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ] else ...[
                      const Icon(Icons.check_circle_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Simpan Perubahan Toko',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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
              // Salin Link
              InkWell(
                onTap: () {
                  final fullUrl = 'https://pos.mudahkan.online/s/$slug';
                  Clipboard.setData(ClipboardData(text: fullUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF16A34A),
                      content: Text('Link berhasil disalin: $fullUrl'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.copy_rounded,
                        size: 13,
                        color: Color(0xFFFF7A00),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Salin Link',
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
              const SizedBox(width: 8),
              // Ubah Link toggle
              InkWell(
                onTap: () {
                  setState(() {
                    _isCustomizingSlug = !_isCustomizingSlug;
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

  Widget _buildGeofenceCard(BuildContext context, ColorScheme scheme) {
    final hasCoords = _latitude != null && _longitude != null;
    const radiusOptions = [1000, 3000, 5000, 10000, 20000];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasCoords ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasCoords ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
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
                  color: hasCoords ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasCoords ? Icons.check_circle_rounded : Icons.search_rounded,
                  size: 16,
                  color: hasCoords ? const Color(0xFF15803D) : const Color(0xFFF97316),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasCoords
                          ? 'Titik Lokasi Toko Aktif'
                          : 'Cari & Kunci Lokasi Toko (Google Maps)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: hasCoords
                            ? const Color(0xFF15803D)
                            : const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Untuk web online, delivery, dan batas absensi',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasCoords ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _isGeofenceActive ? 'Geofence Aktif' : 'Geofence Off',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: hasCoords ? const Color(0xFF15803D) : const Color(0xFFC2410C),
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
              color: const Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              hintText: 'Ketik nama jalan / tempat / kota di sini...',
              hintStyle: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFFF97316),
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
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF97316)),
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
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFF97316),
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
                    color: Color(0xFFF1F5F9),
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
                                color: Color(0xFFF97316),
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
                                      color: const Color(0xFF1E293B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (place.subtitle.isNotEmpty)
                                    Text(
                                      place.subtitle,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: const Color(0xFF64748B),
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
                              color: Color(0xFF94A3B8),
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
                onPressed: _isDetectingGps ? null : _detectCurrentGps,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _isDetectingGps
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFF97316),
                        ),
                      )
                    : const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF15803D)),
                label: Text(
                  _isDetectingGps ? 'Mencari GPS...' : 'Kunci GPS Saat Ini',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (hasCoords) ...[
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

          // 4. STATUS KOORDINAT TERKUNCI (Jika ada)
          if (hasCoords) ...[
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
                  color: const Color(0xFF1E293B),
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
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: _isGeofenceActive,
                      activeColor: const Color(0xFFF97316),
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
                selectedColor: const Color(0xFFF97316),
                backgroundColor: Colors.white,
                labelStyle: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFFF97316)
                      : const Color(0xFFE2E8F0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TipTile extends StatelessWidget {
  const _TipTile({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.primary.withValues(alpha: 0.7)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.54),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({this.ownerName, this.businessUpdatedAt, this.business});

  final String? ownerName;
  final String? businessUpdatedAt;
  final Business? business;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = theme.extension<ConciergeThemeTokens>();

    final isPro = business?.isPro ?? false;
    final isLifetime = business?.isLifetime ?? false;
    final isExpired = business?.isExpired ?? false;
    final remainingDays = business?.remainingDays;

    String statusText;
    IconData statusIcon = Icons.verified_rounded;
    Color statusIconColor = scheme.primary;

    if (isLifetime) {
      statusText = '👑 Pro Lifetime (Aktif)';
      statusIcon = Icons.workspace_premium_rounded;
      statusIconColor = const Color(0xFFF59E0B);
    } else if (isPro && !isExpired) {
      statusText = '✨ Pro ($remainingDays Hari Tersisa)';
      statusIcon = Icons.verified_rounded;
      statusIconColor = const Color(0xFF10B981);
    } else if (isExpired) {
      statusText = '⚠️ Paket Pro Kedaluwarsa';
      statusIcon = Icons.warning_amber_rounded;
      statusIconColor = const Color(0xFFEF4444);
    } else {
      statusText = '🌱 Paket Free (Gratis)';
      statusIcon = Icons.storefront_rounded;
      statusIconColor = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: (tokens?.tintedShadow ?? Colors.black12),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SETTINGS',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.secondary,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Informasi Bisnis',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Kelola identitas utama bisnis Anda untuk sinkronisasi data di seluruh outlet dan modul POS.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.60),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 26),
          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF465F88),
                  Color(0xFF2C1507),
                  Color(0xFFFF8C00),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.4, 1.0],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -20,
                  right: -20,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: statusIconColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            statusIcon,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'STATUS LANGGANAN',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                statusText,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (ownerName != null || businessUpdatedAt != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 14,
                  color: scheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Update terakhir ${businessUpdatedAt ?? 'baru saja'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.5),
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
}


class _InfoNoticeCard extends StatelessWidget {
  const _InfoNoticeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                    height: 1.3,
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

class _TimezoneOption {
  const _TimezoneOption({required this.value, required this.label});

  final String value;
  final String label;
}

const List<_TimezoneOption> _timezoneOptions = [
  _TimezoneOption(
    value: 'Asia/Jakarta',
    label: '(GMT+07:00) Jakarta, Indonesia',
  ),
  _TimezoneOption(
    value: 'Asia/Makassar',
    label: '(GMT+08:00) Makassar, Indonesia',
  ),
  _TimezoneOption(
    value: 'Asia/Jayapura',
    label: '(GMT+09:00) Jayapura, Indonesia',
  ),
];

String? _nullable(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

extension on Business {
  String? get updatedAtLabel {
    if (updatedAt == null) {
      return null;
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    final local = updatedAt!.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}
