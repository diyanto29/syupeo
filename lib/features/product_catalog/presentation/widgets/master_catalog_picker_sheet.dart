import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dpos/core/theme/app_theme.dart';
import 'package:dpos/core/widgets/barcode_scanner_sheet.dart';
import 'package:dpos/features/product_catalog/data/master_catalog_repository.dart';
import 'package:dpos/features/product_catalog/domain/master_catalog_item.dart';
import 'package:dpos/features/product_catalog/presentation/widgets/add_product_form_components.dart';

class MasterCatalogPickerSheet extends ConsumerStatefulWidget {
  const MasterCatalogPickerSheet({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<MasterCatalogPickerSheet> createState() =>
      _MasterCatalogPickerSheetState();
}

class _MasterCatalogPickerSheetState
    extends ConsumerState<MasterCatalogPickerSheet> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  final List<MasterCatalogItem> _items = [];
  String _searchQuery = '';
  Object? _error;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _exactBarcodeMatched = false;
  int _generalOffset = 0;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _searchController.text = widget.initialQuery!.trim();
      _searchQuery = widget.initialQuery!.trim();
    }
    _scrollController.addListener(_handleScroll);
    scheduleMicrotask(() => _loadSamples(reset: true));
  }

  Future<void> _scanBarcodeForSearch() async {
    HapticFeedback.lightImpact();
    final String? code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BarcodeScannerSheet(
        title: 'Scan Barcode Master Catalog',
      ),
    );

    if (code != null && code.trim().isNotEmpty && mounted) {
      _searchController.text = code.trim();
      _debounce?.cancel();
      setState(() => _searchQuery = code.trim());
      _loadSamples(reset: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) {
        return;
      }
      setState(() => _searchQuery = value.trim());
      _loadSamples(reset: true);
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _loadSamples();
    }
  }

  Future<void> _loadSamples({bool reset = false}) async {
    if (_isLoadingMore) {
      return;
    }

    final requestVersion = ++_requestVersion;
    final startingOffset = reset ? 0 : _generalOffset;

    setState(() {
      _error = null;
      if (reset) {
        _isInitialLoading = true;
        _items.clear();
        _hasMore = true;
        _generalOffset = 0;
        _exactBarcodeMatched = false;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final page = await ref
          .read(masterCatalogRepositoryProvider)
          .searchSamples(_searchQuery, generalOffset: startingOffset);

      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      final mergedItems = reset
          ? page.items
          : _mergeWithoutDuplicates(_items, page.items);

      setState(() {
        _items
          ..clear()
          ..addAll(mergedItems);
        _generalOffset = page.nextGeneralOffset;
        _hasMore = page.hasMore;
        _exactBarcodeMatched = reset && page.exactBarcodeMatched;
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _error = error;
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  List<MasterCatalogItem> _mergeWithoutDuplicates(
    List<MasterCatalogItem> existing,
    List<MasterCatalogItem> incoming,
  ) {
    final existingIds = existing.map((item) => item.id).toSet();
    return [
      ...existing,
      ...incoming.where((item) => !existingIds.contains(item.id)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
          child: SizedBox(
            height: 560,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Master Catalog Syupeo',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cari berdasarkan nama, barcode, brand, atau kategori.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(fontSize: 14),
                  onChanged: (value) {
                    setState(() {});
                    _handleSearchChanged(value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Cari nama, barcode, atau brand...',
                    filled: true,
                    fillColor: AppTheme.surfaceSubtle,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _handleSearchChanged('');
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        IconButton(
                          tooltip: 'Scan Barcode',
                          onPressed: _scanBarcodeForSearch,
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_exactBarcodeMatched) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Text(
                      'Exact barcode match ditaruh paling atas.',
                      style: GoogleFonts.inter(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Expanded(child: _buildResults()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Gagal memuat master catalog: $_error',
              style: GoogleFonts.inter(color: AppTheme.danger),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _loadSamples(reset: true),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return EmptyMasterCatalogState(query: _searchQuery);
    }

    final itemCount = _items.length + (_isLoadingMore || _hasMore ? 1 : 0);
    return ListView.separated(
      controller: _scrollController,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator()
                  : Text(
                      'Scroll lagi untuk memuat sample berikutnya',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
            ),
          );
        }

        final item = _items[index];
        return Material(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop(item);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: const Icon(
                      Icons.content_copy_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text,
                          ),
                        ),
                        if (item.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (item.barcode != null &&
                                item.barcode!.trim().isNotEmpty)
                              InfoChip(label: 'Barcode ${item.barcode}'),
                            if (item.basePrice > 0)
                              InfoChip(
                                label: 'Modal Rp ${item.basePrice.round()}',
                              ),
                            if (item.sellingPrice > 0)
                              InfoChip(
                                label: 'Jual Rp ${item.sellingPrice.round()}',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class EmptyMasterCatalogState extends StatelessWidget {
  const EmptyMasterCatalogState({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 48,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            query.isEmpty
                ? 'Belum ada sample yang tampil.'
                : 'Sample tidak ditemukan.',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            query.isEmpty
                ? 'Coba cari produk berdasarkan nama atau barcode.'
                : 'Coba kata kunci lain atau barcode yang lebih spesifik.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
