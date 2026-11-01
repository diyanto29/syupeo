import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dpos/core/theme/app_theme.dart';
import 'package:dpos/core/services/wilayah_service.dart';
import 'package:dpos/core/widgets/syupeo_shimmer.dart';

class WilayahPickerSheet extends StatefulWidget {
  const WilayahPickerSheet({super.key});

  static Future<WilayahSelection?> show(BuildContext context) {
    return showModalBottomSheet<WilayahSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const WilayahPickerSheet(),
    );
  }

  @override
  State<WilayahPickerSheet> createState() => _WilayahPickerSheetState();
}

class _WilayahPickerSheetState extends State<WilayahPickerSheet> {
  int _currentLevel = 0; // 0 = Provinsi, 1 = Kota/Kab, 2 = Kecamatan, 3 = Kelurahan
  final TextEditingController _searchController = TextEditingController();

  WilayahItem? _selectedProvince;
  WilayahItem? _selectedRegency;
  WilayahItem? _selectedDistrict;
  WilayahItem? _selectedVillage;

  List<WilayahItem> _currentItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    setState(() {
      _isLoading = true;
      _currentLevel = 0;
      _searchController.clear();
    });
    final items = await WilayahService.instance.getProvinces();
    if (mounted) {
      setState(() {
        _currentItems = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRegencies(WilayahItem province) async {
    setState(() {
      _selectedProvince = province;
      _selectedRegency = null;
      _selectedDistrict = null;
      _selectedVillage = null;
      _isLoading = true;
      _currentLevel = 1;
      _searchController.clear();
    });
    final items = await WilayahService.instance.getRegencies(province.code);
    if (mounted) {
      setState(() {
        _currentItems = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDistricts(WilayahItem regency) async {
    setState(() {
      _selectedRegency = regency;
      _selectedDistrict = null;
      _selectedVillage = null;
      _isLoading = true;
      _currentLevel = 2;
      _searchController.clear();
    });
    final items = await WilayahService.instance.getDistricts(regency.code);
    if (mounted) {
      setState(() {
        _currentItems = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadVillages(WilayahItem district) async {
    setState(() {
      _selectedDistrict = district;
      _selectedVillage = null;
      _isLoading = true;
      _currentLevel = 3;
      _searchController.clear();
    });
    final items = await WilayahService.instance.getVillages(district.code);
    if (mounted) {
      setState(() {
        _currentItems = items;
        _isLoading = false;
      });
    }
  }

  void _finish() {
    Navigator.of(context).pop(
      WilayahSelection(
        province: _selectedProvince,
        regency: _selectedRegency,
        district: _selectedDistrict,
        village: _selectedVillage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _currentItems
        : _currentItems
            .where((item) => item.name.toLowerCase().contains(query))
            .toList();

    final titles = ['Pilih Provinsi', 'Pilih Kota / Kabupaten', 'Pilih Kecamatan', 'Pilih Kelurahan / Desa'];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (_currentLevel > 0)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      if (_currentLevel == 3 && _selectedRegency != null) {
                        _loadDistricts(_selectedRegency!);
                      } else if (_currentLevel == 2 && _selectedProvince != null) {
                        _loadRegencies(_selectedProvince!);
                      } else {
                        _loadProvinces();
                      }
                    },
                  ),
                if (_currentLevel > 0) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titles[_currentLevel],
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text,
                    ),
                  ),
                ),
                if (_selectedRegency != null)
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Selesai',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Breadcrumbs
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              [
                _selectedProvince?.name ?? 'Provinsi',
                if (_selectedRegency != null) _selectedRegency!.name,
                if (_selectedDistrict != null) _selectedDistrict!.name,
                if (_selectedVillage != null) _selectedVillage!.name,
              ].join(' › '),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari ${titles[_currentLevel].replaceAll("Pilih ", "")}...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),

          // Content list
          Expanded(
            child: _isLoading
                ? ListView.separated(
                    itemCount: 6,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x0F000000)),
                    itemBuilder: (_, __) => const WilayahTileSkeleton(),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Tidak ada data ditemukan',
                          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x0F000000)),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return ListTile(
                            dense: true,
                            title: Text(
                              item.name,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.text,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textMuted),
                            onTap: () {
                              if (_currentLevel == 0) {
                                _loadRegencies(item);
                              } else if (_currentLevel == 1) {
                                _loadDistricts(item);
                              } else if (_currentLevel == 2) {
                                _loadVillages(item);
                              } else {
                                setState(() => _selectedVillage = item);
                                _finish();
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

