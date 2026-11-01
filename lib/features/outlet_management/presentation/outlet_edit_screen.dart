import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dpos/core/domain/outlet_models.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/services/location_search_service.dart';
import 'package:dpos/core/widgets/app_tablet_nav.dart';
import 'package:dpos/features/auth/data/auth_repository.dart';
import 'package:dpos/features/outlet_management/presentation/outlet_management_screen.dart';

class OutletEditScreen extends ConsumerStatefulWidget {
  const OutletEditScreen({
    required this.outlet,
    super.key,
  });

  final Outlet outlet;

  @override
  ConsumerState<OutletEditScreen> createState() => _OutletEditScreenState();
}

class _OutletEditScreenState extends ConsumerState<OutletEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  final _locationSearchController = TextEditingController();

  double? _latitude;
  double? _longitude;
  int _geofenceRadius = 5000;
  bool _isGeofenceActive = true;
  late bool _isActive;
  bool _setAsCurrent = false;

  bool _isSearchingLocation = false;
  bool _isDetectingGps = false;
  bool _isSubmitting = false;
  List<LocationPlaceItem> _locationSearchResults = [];
  Timer? _locationDebounceTimer;

  @override
  void initState() {
    super.initState();
    final outlet = widget.outlet;
    _nameController = TextEditingController(text: outlet.name);
    _codeController = TextEditingController(text: outlet.code ?? '');
    _addressController = TextEditingController(text: outlet.address ?? '');

    // Bersihkan prefix nomor telepon
    var cleanPhone = (outlet.phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('62')) {
      cleanPhone = cleanPhone.substring(2);
    } else if (cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1);
    }
    _phoneController = TextEditingController(text: cleanPhone);

    _latitude = outlet.latitude;
    _longitude = outlet.longitude;
    _geofenceRadius = outlet.geofenceRadius ?? 5000;
    _isGeofenceActive = outlet.isGeofenceActive;
    _isActive = outlet.isActive;

    final currentOutlet = ref.read(homeBootstrapProvider).valueOrNull?.currentOutlet;
    _setAsCurrent = currentOutlet?.id == outlet.id;
  }

  @override
  void dispose() {
    _locationDebounceTimer?.cancel();
    _nameController.dispose();
    _codeController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _locationSearchController.dispose();
    super.dispose();
  }

  void _onLocationSearchChanged(String query) {
    _locationDebounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 3) {
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
          content: Text('Titik cabang outlet berhasil dikunci dari Google Maps!'),
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
      debugPrint('[OutletEditScreen] Gagal buka maps: $e');
    }
  }

  Future<void> _save() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final repository = ref.read(authRepositoryProvider);

      String? cleanPhone;
      final rawDigits = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
      if (rawDigits.isNotEmpty) {
        cleanPhone = '+62$rawDigits';
      }

      final savedOutlet = await repository.updateOutlet(
        outletId: widget.outlet.id,
        businessId: widget.outlet.businessId,
        name: _nameController.text.trim(),
        code: _codeController.text.trim().isEmpty ? null : _codeController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        phone: cleanPhone,
        latitude: _latitude,
        longitude: _longitude,
        geofenceRadius: _geofenceRadius,
        isGeofenceActive: _isGeofenceActive,
        timezone: widget.outlet.timezone,
        isActive: _isActive,
      );

      if (_setAsCurrent) {
        await repository.setCurrentOutletId(savedOutlet.id);
      }

      ref.invalidate(homeBootstrapProvider);
      ref.invalidate(outletManagementOutletsProvider(widget.outlet.businessId));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF16A34A),
          content: Text('Data cabang outlet & koordinat GPS berhasil disimpan!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          content: Text('Gagal menyimpan outlet: $error'),
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
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 760;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: isTablet
          ? AppTabletHeader(
              title: const Text('Edit Cabang Outlet'),
              badge: const AppTabletBadge(label: 'Syupeo'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _save,
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
                    label: Text(_isSubmitting ? 'Menyimpan...' : 'Simpan Cabang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0070FC),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : AppBar(
              title: Text(
                'Edit Cabang: ${widget.outlet.name}',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              centerTitle: true,
              actions: [
                TextButton(
                  onPressed: _isSubmitting ? null : _save,
                  child: Text(
                    _isSubmitting ? 'Menyimpan...' : 'Simpan',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0070FC),
                    ),
                  ),
                ),
              ],
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Container
                    Container(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Nama Cabang
                          Text(
                            'Nama Cabang Outlet *',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF18181B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Nama spesifik cabang ini yang tercetak di struk kasir.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF71717A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF18181B),
                            ),
                            decoration: _buildInputDecoration(
                              hintText: 'Misal: Cabang Pasar Baru, Outlet Tebet',
                              icon: Icons.storefront_rounded,
                            ),
                            validator: (val) {
                              if ((val ?? '').trim().isEmpty) {
                                return 'Nama cabang outlet wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // 2. Kode Cabang
                          Text(
                            'Kode Cabang (Opsional)',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF18181B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _codeController,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-\s]')),
                            ],
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF18181B),
                            ),
                            decoration: _buildInputDecoration(
                              hintText: 'Misal: CBG-01, TBT-02',
                              icon: Icons.tag_rounded,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 3. Nomor WhatsApp Cabang
                          Text(
                            'Nomor WhatsApp Kasir / Cabang',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF18181B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Untuk mengirim struk belanja digital ke WhatsApp pelanggan dari cabang ini.',
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
                                  color: Color(0xFF0070FC),
                                  width: 1.8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 4. Alamat Lengkap Cabang
                          Text(
                            'Alamat Lengkap Cabang *',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF18181B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Alamat fisik spesifik cabang toko ini.',
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
                                  'Contoh: Jl. Mangga Raya No. 15, RT 03/RW 05, Cilodong, Depok',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFFA1A1AA),
                              ),
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(bottom: 24),
                                child: Icon(
                                  Icons.location_on_rounded,
                                  color: Color(0xFF0070FC),
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
                                  color: Color(0xFF0070FC),
                                  width: 1.8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 5. Titik Koordinat & Geofencing Cabang
                          Text(
                            'Titik Koordinat & Geofencing Cabang',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF18181B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kunci titik Google Maps cabang ini agar absensi kasir radius geofence akurat.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF71717A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildGeofenceCard(context),
                          const SizedBox(height: 20),

                          // 6. Pengaturan Operasional Cabang
                          SwitchListTile.adaptive(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: _isActive,
                            title: Text(
                              'Status Cabang Aktif',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF18181B),
                              ),
                            ),
                            subtitle: Text(
                              'Cabang yang aktif dapat dipilih untuk transaksi kasir.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF71717A),
                              ),
                            ),
                            onChanged: (val) => setState(() {
                              _isActive = val;
                              if (!_isActive) _setAsCurrent = false;
                            }),
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          SwitchListTile.adaptive(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: _setAsCurrent,
                            title: Text(
                              'Gunakan Langsung di Perangkat Ini',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF18181B),
                              ),
                            ),
                            subtitle: Text(
                              'Otomatis beralih ke cabang ini setelah disimpan.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF71717A),
                              ),
                            ),
                            onChanged: _isActive
                                ? (val) => setState(() => _setAsCurrent = val)
                                : null,
                          ),
                          const SizedBox(height: 28),

                          // 7. Tombol CTA Simpan Perubahan Cabang
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton(
                              onPressed: _isSubmitting ? null : _save,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0070FC),
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
                                      'Menyimpan Cabang...',
                                      style: GoogleFonts.manrope(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ] else ...[
                                    const Icon(Icons.check_circle_rounded, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Simpan Perubahan Cabang',
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeofenceCard(BuildContext context) {
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
          // Header Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: hasCoords ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasCoords ? Icons.my_location_rounded : Icons.location_off_rounded,
                  color: hasCoords ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasCoords ? 'Titik Cabang Terkunci' : 'Belum Ada Titik Lokasi',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: hasCoords ? const Color(0xFF166534) : const Color(0xFF334155),
                      ),
                    ),
                    if (hasCoords)
                      Text(
                        '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF15803D),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (hasCoords)
                IconButton(
                  tooltip: 'Lihat di Google Maps',
                  icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF16A34A)),
                  onPressed: _openInMaps,
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Google Places Autocomplete Search Box
          TextFormField(
            controller: _locationSearchController,
            onChanged: _onLocationSearchChanged,
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF18181B)),
            decoration: InputDecoration(
              hintText: 'Cari nama jalan, mall, atau gedung cabang...',
              hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFA1A1AA)),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF0070FC)),
              suffixIcon: _isSearchingLocation
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0070FC)),
                        ),
                      ),
                    )
                  : (_locationSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _locationSearchController.clear();
                            setState(() => _locationSearchResults = []);
                          },
                        )
                      : null),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0070FC), width: 1.5),
              ),
            ),
          ),

          // Autocomplete Results Dropdown List
          if (_locationSearchResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _locationSearchResults.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final place = _locationSearchResults[idx];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_rounded, size: 18, color: Color(0xFF0070FC)),
                    title: Text(
                      place.title,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      place.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                    onTap: () => _onSelectLocationPlace(place),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Action: Kunci GPS Saat Ini
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isDetectingGps ? null : _detectCurrentGps,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0070FC),
                side: const BorderSide(color: Color(0xFF0070FC)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: _isDetectingGps
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0070FC)),
                      ),
                    )
                  : const Icon(Icons.my_location_rounded, size: 16),
              label: Text(
                _isDetectingGps ? 'Mengambil GPS Cabang...' : 'Kunci GPS Cabang Ini Sekarang',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          if (hasCoords) ...[
            const SizedBox(height: 14),
            Text(
              'Radius Toleransi Absensi Kasir Cabang:',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: radiusOptions.map((radius) {
                final isSelected = _geofenceRadius == radius;
                final label = radius >= 1000 ? '${radius ~/ 1000} km' : '${radius}m';
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  selectedColor: const Color(0xFF0070FC),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _geofenceRadius = radius);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _isGeofenceActive,
              title: Text(
                'Wajibkan Absensi di Radius Ini',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF18181B),
                ),
              ),
              subtitle: Text(
                'Kasir hanya dapat buka kasir jika berada di sekitar cabang.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF71717A),
                ),
              ),
              onChanged: (val) => setState(() => _isGeofenceActive = val),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xFFA1A1AA),
      ),
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF0070FC),
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
          color: Color(0xFF0070FC),
          width: 1.8,
        ),
      ),
    );
  }
}
