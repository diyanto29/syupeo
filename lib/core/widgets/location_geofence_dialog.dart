import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/google_maps_config.dart';
import '../services/location_search_service.dart';

class LocationGeofenceResult {
  final String? address;
  final double latitude;
  final double longitude;
  final int geofenceRadius; // meter
  final bool isGeofenceActive;

  const LocationGeofenceResult({
    this.address,
    required this.latitude,
    required this.longitude,
    required this.geofenceRadius,
    required this.isGeofenceActive,
  });
}

class LocationGeofenceDialog extends StatefulWidget {
  final String? initialAddress;
  final double? initialLatitude;
  final double? initialLongitude;
  final int initialRadius;
  final bool initialIsActive;

  const LocationGeofenceDialog({
    super.key,
    this.initialAddress,
    this.initialLatitude,
    this.initialLongitude,
    this.initialRadius = 5000,
    this.initialIsActive = true,
  });

  static Future<LocationGeofenceResult?> show(
    BuildContext context, {
    String? initialAddress,
    double? initialLatitude,
    double? initialLongitude,
    int initialRadius = 5000,
    bool initialIsActive = true,
  }) {
    return showModalBottomSheet<LocationGeofenceResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationGeofenceDialog(
        initialAddress: initialAddress,
        initialLatitude: initialLatitude,
        initialLongitude: initialLongitude,
        initialRadius: initialRadius,
        initialIsActive: initialIsActive,
      ),
    );
  }

  @override
  State<LocationGeofenceDialog> createState() => _LocationGeofenceDialogState();
}

class _LocationGeofenceDialogState extends State<LocationGeofenceDialog> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isSearching = false;
  bool _isDetectingGps = false;
  List<LocationPlaceItem> _searchResults = [];

  String? _selectedAddress;
  double? _selectedLat;
  double? _selectedLng;
  late int _radiusMeters;
  late bool _isGeofenceActive;

  final List<int> _radiusOptions = const [
    500, // 500 m
    1000, // 1 km
    3000, // 3 km
    5000, // 5 km
    10000, // 10 km
    20000, // 20 km
    35000, // 35 km
  ];

  @override
  void initState() {
    super.initState();
    _selectedAddress = widget.initialAddress;
    _selectedLat = widget.initialLatitude;
    _selectedLng = widget.initialLongitude;
    _radiusMeters = widget.initialRadius;
    _isGeofenceActive = widget.initialIsActive;

    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _searchController.text = widget.initialAddress!;
    }

    // Auto-detect last known position for search proximity bias
    if (_selectedLat == null || _selectedLng == null) {
      _initProximityBias();
    }
  }

  Future<void> _initProximityBias() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null && mounted && _selectedLat == null) {
        setState(() {
          _selectedLat = pos.latitude;
          _selectedLng = pos.longitude;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    final results = await LocationSearchService.instance.searchPlaces(
      query,
      userLat: _selectedLat,
      userLng: _selectedLng,
    );
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
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
              content: Text('Izin lokasi ditolak permanen di pengaturan HP.'),
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

      final address = await LocationSearchService.instance.reverseGeocode(
        pos.latitude,
        pos.longitude,
      );

      if (mounted) {
        setState(() {
          _selectedLat = pos.latitude;
          _selectedLng = pos.longitude;
          if (address != null && address.isNotEmpty) {
            _selectedAddress = address;
            _searchController.text = address;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF16A34A),
            content: Text('GPS Terkunci ke posisi saat ini!'),
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

  Future<void> _selectPlace(LocationPlaceItem item) async {
    setState(() => _isSearching = true);
    final detailed = await LocationSearchService.instance.getPlaceDetails(item);
    if (mounted) {
      final finalItem = detailed ?? item;
      setState(() {
        _selectedAddress = finalItem.displayName;
        _selectedLat = finalItem.latitude;
        _selectedLng = finalItem.longitude;
        _searchResults = [];
        _searchController.text = finalItem.title;
        _isSearching = false;
      });
    }
  }

  String _formatRadius(int meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      return km == km.roundToDouble()
          ? '${km.toInt()} km'
          : '${km.toStringAsFixed(1)} km';
    }
    return '$meters m';
  }

  void _submitSelection() {
    if (_selectedLat == null || _selectedLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih lokasi tempat atau kunci titik GPS terlebih dahulu.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      LocationGeofenceResult(
        address: _selectedAddress,
        latitude: _selectedLat!,
        longitude: _selectedLng!,
        geofenceRadius: _radiusMeters,
        isGeofenceActive: _isGeofenceActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final hasCoords = _selectedLat != null && _selectedLng != null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4E4E7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.radar_rounded,
                      color: Color(0xFF0070FC),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pencarian Lokasi & Geofencing',
                          style: GoogleFonts.manrope(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF18181B),
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              'Kunci titik toko & jangkauan online',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF71717A),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: GoogleMapsConfig.hasApiKey
                                    ? const Color(0xFFEFF6FF)
                                    : const Color(0xFFF4F4F5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                GoogleMapsConfig.hasApiKey ? 'Google Maps' : 'Proximity Bias',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: GoogleMapsConfig.hasApiKey
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF71717A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF71717A)),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF4F4F5)),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Input Box
                    Text(
                      'Cari Nama Tempat / Alamat / Gedung',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF18181B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            textInputAction: TextInputAction.search,
                            onFieldSubmitted: _performSearch,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Misal: Grand Indonesia, Jl. Margonda...',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFFA1A1AA),
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: Color(0xFF0070FC),
                                size: 20,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchResults = []);
                                      },
                                    )
                                  : null,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFFAFAFA),
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
                                  color: Color(0xFF0070FC),
                                  width: 1.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _isDetectingGps ? null : _detectCurrentGps,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFF7ED),
                            foregroundColor: const Color(0xFF0070FC),
                            side: const BorderSide(color: Color(0xFFFFD8A8)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isDetectingGps
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF0070FC),
                                  ),
                                )
                              : const Icon(Icons.my_location_rounded, size: 20),
                        ),
                      ],
                    ),

                    // Search Results List
                    if (_isSearching) ...[
                      const SizedBox(height: 14),
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0070FC)),
                            ),
                          ),
                        ),
                      ),
                    ] else if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE4E4E7)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: Color(0xFFF4F4F5)),
                          itemBuilder: (context, idx) {
                            final item = _searchResults[idx];
                            return ListTile(
                              leading: const Icon(
                                Icons.place_rounded,
                                color: Color(0xFF0070FC),
                                size: 20,
                              ),
                              title: Text(
                                item.title,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                item.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF71717A),
                                ),
                              ),
                              onTap: () => _selectPlace(item),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Selected Location Status Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: hasCoords
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasCoords
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFE4E4E7),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                hasCoords
                                    ? Icons.check_circle_rounded
                                    : Icons.info_outline_rounded,
                                size: 18,
                                color: hasCoords
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFF71717A),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  hasCoords
                                      ? 'Titik Koordinat Toko Terkunci'
                                      : 'Belum Ada Titik Lokasi Terpilih',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: hasCoords
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFF18181B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (hasCoords) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Lat: ${_selectedLat!.toStringAsFixed(6)}, Lng: ${_selectedLng!.toStringAsFixed(6)}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF166534),
                              ),
                            ),
                            if (_selectedAddress != null && _selectedAddress!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _selectedAddress!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Geofencing Radius Section
                    Row(
                      children: [
                        const Icon(
                          Icons.radar_rounded,
                          size: 18,
                          color: Color(0xFF0070FC),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Radius Geofencing Toko Online',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF18181B),
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: _isGeofenceActive,
                          activeColor: const Color(0xFF0070FC),
                          onChanged: (val) {
                            setState(() => _isGeofenceActive = val);
                          },
                        ),
                      ],
                    ),
                    Text(
                      'Menentukan batas radius pengantaran delivery pesanan online dan batas kehadiran kasir.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF71717A),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _radiusOptions.map((meters) {
                        final isSelected = _radiusMeters == meters;
                        return ChoiceChip(
                          label: Text(
                            _formatRadius(meters),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF0070FC)
                                  : const Color(0xFF52525B),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFFFFF7ED),
                          backgroundColor: const Color(0xFFFAFAFA),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF0070FC)
                                : const Color(0xFFE4E4E7),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _radiusMeters = meters);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Submit Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _submitSelection,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0070FC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Terapkan Titik & Geofence',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
