import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dpos/core/theme/app_theme.dart';
import 'package:dpos/core/widgets/app_form_field.dart';

class VariantDraft {
  VariantDraft({
    required this.localId,
    this.variantId,
    required String name,
    required String priceText,
    required String sku,
    required String barcode,
    required this.stockAvailable,
    this.useMainPrice = false,
  }) : nameController = TextEditingController(text: name),
       priceController = TextEditingController(text: priceText),
       skuController = TextEditingController(text: sku),
       barcodeController = TextEditingController(text: barcode);

  final String localId;
  final String? variantId;
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController skuController;
  final TextEditingController barcodeController;
  bool stockAvailable;
  bool useMainPrice;

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    skuController.dispose();
    barcodeController.dispose();
  }
}

class VariantEditorCard extends StatelessWidget {
  const VariantEditorCard({
    super.key,
    required this.index,
    required this.draft,
    required this.onChanged,
    required this.onToggleMainPrice,
    this.onScanBarcode,
    this.onRemove,
  });

  final int index;
  final VariantDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onToggleMainPrice;
  final VoidCallback? onScanBarcode;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  'Varian $index',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onRemove?.call();
                  },
                  tooltip: 'Hapus varian',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.danger,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          AppTextInput(
            label: 'Nama Varian',
            isRequired: true,
            controller: draft.nameController,
            textInputAction: TextInputAction.next,
            hintText: 'e.g. 1/2 Kg, 1/4 Kg, 250 gr, Eceran',
            onChanged: (_) => onChanged(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama varian wajib diisi.';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final preset in const [
                '1/4 Kg',
                '1/2 Kg',
                '1 Kg',
                '250 gr',
                '500 gr',
                'Eceran',
              ])
                ActionChip(
                  label: Text(
                    preset,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: draft.nameController.text.trim() == preset
                          ? AppTheme.primary
                          : AppTheme.textBody,
                    ),
                  ),
                  backgroundColor: draft.nameController.text.trim() == preset
                      ? AppTheme.primary.withValues(alpha: 0.12)
                      : AppTheme.surfaceSubtle,
                  side: BorderSide(
                    color: draft.nameController.text.trim() == preset
                        ? AppTheme.primary
                        : AppTheme.border,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    draft.nameController.text = preset;
                    onChanged();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          AppCurrencyInput(
            label: 'Harga Varian',
            isRequired: true,
            topTrailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sama Harga Utama',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: draft.useMainPrice,
                    onChanged: (v) {
                      HapticFeedback.lightImpact();
                      onToggleMainPrice();
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            controller: draft.priceController,
            enabled: !draft.useMainPrice,
            prefixBadge: 'IDR',
            onChanged: (_) => onChanged(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Harga varian wajib diisi.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextInput(
                  label: 'SKU (Opsional)',
                  controller: draft.skuController,
                  textInputAction: TextInputAction.next,
                  hintText: 'SKU varian',
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppTextInput(
                  label: 'Barcode (Opsional)',
                  controller: draft.barcodeController,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  hintText: 'Barcode varian',
                  onChanged: (_) => onChanged(),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Color(0xFFF98B35),
                      size: 20,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onScanBarcode?.call();
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Variant Available',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: draft.stockAvailable,
                  onChanged: (value) {
                    HapticFeedback.lightImpact();
                    draft.stockAvailable = value;
                    onChanged();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
