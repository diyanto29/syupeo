import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dpos/core/theme/app_theme.dart';
import 'package:dpos/core/utils/rupiah_input_helper.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';

class PackageComponentDraft {
  PackageComponentDraft({
    required this.localId,
    this.id,
    required this.componentMenuItemId,
    required this.componentName,
    required this.componentPrice,
    int initialQuantity = 1,
  }) : quantityController = TextEditingController(text: '$initialQuantity');

  final String localId;
  final String? id;
  final String componentMenuItemId;
  final String componentName;
  final double componentPrice;
  final TextEditingController quantityController;

  void dispose() {
    quantityController.dispose();
  }
}

class PackageComponentEditorCard extends StatelessWidget {
  const PackageComponentEditorCard({
    super.key,
    required this.index,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final PackageComponentDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
            child: Text(
              '$index',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.componentName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  RupiahInputHelper.format(draft.componentPrice),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextFormField(
              controller: draft.quantityController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                labelText: 'Qty',
                isDense: true,
                filled: true,
                fillColor: AppTheme.surfaceSubtle,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              onRemove();
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: AppTheme.danger,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class SelectPackageComponentSheet extends StatefulWidget {
  const SelectPackageComponentSheet({
    super.key,
    required this.items,
    required this.alreadySelectedIds,
  });

  final List<MenuItem> items;
  final Set<String> alreadySelectedIds;

  @override
  State<SelectPackageComponentSheet> createState() =>
      _SelectPackageComponentSheetState();
}

class _SelectPackageComponentSheetState
    extends State<SelectPackageComponentSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = widget.items.where((item) {
      if (_query.isEmpty) return true;
      return item.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Pilih Komponen Paket',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.text,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Cari nama produk...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: AppTheme.surfaceSubtle,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
            ),
            onChanged: (val) => setState(() => _query = val.trim()),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 350),
            child: filteredItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Tidak ada produk ditemukan.',
                        style: GoogleFonts.inter(color: AppTheme.textMuted),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final isSelected =
                          widget.alreadySelectedIds.contains(item.id);

                      return ListTile(
                        title: Text(
                          item.name,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppTheme.textMuted.withValues(alpha: 0.5)
                                : AppTheme.text,
                          ),
                        ),
                        subtitle: Text(
                          RupiahInputHelper.format(item.price),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppTheme.textMuted.withValues(alpha: 0.4)
                                : AppTheme.primary,
                          ),
                        ),
                        trailing: isSelected
                            ? Text(
                                'Sudah Ada',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textMuted,
                                ),
                              )
                            : const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary),
                        enabled: !isSelected,
                        onTap: isSelected
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                Navigator.of(context).pop(item);
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
