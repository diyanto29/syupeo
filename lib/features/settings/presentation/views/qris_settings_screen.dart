import 'dart:io';
import 'package:dpos/core/services/qris_dynamic_generator.dart';
import 'package:dpos/core/services/qris_image_decoder_helper.dart';
import 'package:dpos/core/widgets/barcode_scanner_sheet.dart';
import 'package:dpos/core/widgets/app_tablet_nav.dart';
import 'package:dpos/features/settings/data/qris_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrisSettingsScreen extends ConsumerStatefulWidget {
  const QrisSettingsScreen({super.key});

  @override
  ConsumerState<QrisSettingsScreen> createState() => _QrisSettingsScreenState();
}

class _QrisSettingsScreenState extends ConsumerState<QrisSettingsScreen> {
  final _picker = ImagePicker();
  final _scannerController = MobileScannerController();
  final _merchantNameController = TextEditingController();
  final _nmidController = TextEditingController();
  final _qrisPayloadController = TextEditingController();
  File? _selectedImageFile;
  bool _removeExistingImage = false;
  bool _printOnReceipt = false;
  bool _enableDynamicQris = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(qrisSettingsProvider).value;
    if (settings != null) {
      _merchantNameController.text = settings.merchantName ?? '';
      _nmidController.text = settings.nmid ?? '';
      _qrisPayloadController.text = settings.qrisPayload ?? '';
      _printOnReceipt = settings.printOnReceipt;
      _enableDynamicQris = settings.enableDynamicQris;
    }
  }

  @override
  void dispose() {
    _merchantNameController.dispose();
    _nmidController.dispose();
    _qrisPayloadController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  /// Pilih foto QRIS toko dari galeri HP atau kamera, sekaligus otomatis mendeteksi barcode QR-nya
  Future<void> _pickImage(ImageSource source) async {
    try {
      // Gunakan resolusi asli foto tanpa kompresi lossy agar garis barcode QR tetap tajam
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;

      final imageFile = File(picked.path);
      setState(() {
        _selectedImageFile = imageFile;
        _removeExistingImage = false;
      });

      // Analisis QR barcode dari foto galeri dengan multi-strategi crop & contrast
      final detectedCode = await QrisImageDecoderHelper.decodeFromImageFile(
        imageFile,
      );

      if (detectedCode != null && detectedCode.isNotEmpty) {
        setState(() {
          _qrisPayloadController.text = detectedCode;
          _enableDynamicQris = true;
          final extractedName = QrisDynamicGenerator.extractMerchantName(
            detectedCode,
          );
          if (extractedName != null &&
              extractedName.isNotEmpty &&
              _merchantNameController.text.trim().isEmpty) {
            _merchantNameController.text = extractedName;
          }
        });

        if (!mounted) return;
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'QRIS Dinamis Aktif! Barcode berhasil dibaca dari galeri'
                    '${_merchantNameController.text.isNotEmpty ? " (${_merchantNameController.text})" : ""}.',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Foto berhasil dipilih. Namun barcode belum terbaca otomatis. Coba scan kertas QRIS dengan tombol "Scan Kamera".',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memilih gambar: $e')));
    }
  }

  /// Scan barcode QRIS langsung menggunakan kamera
  Future<void> _scanQrisPayload() async {
    final scannedCode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const BarcodeScannerSheet(
        title: 'Scan QRIS Toko',
        subtitle: 'Arahkan kamera ke kode QRIS statis toko Anda',
      ),
    );

    if (scannedCode != null && scannedCode.trim().isNotEmpty && mounted) {
      final code = scannedCode.trim();
      setState(() {
        _qrisPayloadController.text = code;
        _enableDynamicQris = true;
        if (_merchantNameController.text.trim().isEmpty) {
          final extractedName = QrisDynamicGenerator.extractMerchantName(code);
          if (extractedName != null && extractedName.isNotEmpty) {
            _merchantNameController.text = extractedName;
          }
        }
      });

      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kode QRIS berhasil dideteksi! Fitur QRIS Dinamis siap digunakan'
                  '${_merchantNameController.text.isNotEmpty ? " (${_merchantNameController.text})" : ""}.',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _clearQris() {
    setState(() {
      _selectedImageFile = null;
      _removeExistingImage = true;
      _qrisPayloadController.clear();
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final payloadText = _qrisPayloadController.text.trim();
      await ref
          .read(qrisSettingsProvider.notifier)
          .updateSettings(
            merchantName: _merchantNameController.text.trim(),
            nmid: _nmidController.text.trim(),
            printOnReceipt: _printOnReceipt,
            newImageFile: _selectedImageFile,
            removeImage: _removeExistingImage,
            qrisPayload: payloadText.isEmpty ? null : payloadText,
            clearQrisPayload: payloadText.isEmpty,
            enableDynamicQris: _enableDynamicQris,
          );

      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Pengaturan QRIS berhasil disimpan.'),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncSettings = ref.watch(qrisSettingsProvider);

    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppOwnerDrawer(),
      appBar: isTablet
          ? const AppTabletHeader(
              title: Text('Pengaturan QRIS Toko'),
              badge: AppTabletBadge(label: 'Syupeo'),
            )
          : AppBar(
              title: Text(
                'Pengaturan QRIS Toko',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              centerTitle: true,
            ),
      body: asyncSettings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (savedSettings) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF047857)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QRIS Toko & Dinamis',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Upload foto dari galeri atau scan kamera. Kasir dapat menampilkan barcode QRIS dengan nominal belanja terkunci otomatis.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Unified Card: QRIS Preview & Setup
              _buildUnifiedQrisCard(savedSettings),

              const SizedBox(height: 20),

              // Pengaturan Fitur Transaksi & Struk Card
              _buildOptionsCard(),

              const SizedBox(height: 20),

              // Informasi Toko Card (Nama & NMID)
              _buildStoreInfoCard(),

              const SizedBox(height: 16),

              // Expandable: Rincian Teknis Kode Payload (EMVCo)
              _buildTechnicalPayloadAccordion(),
            ],
          );
        },
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(
                _isSaving ? 'Menyimpan...' : 'Simpan Pengaturan QRIS',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedQrisCard(QrisSettings saved) {
    final hasImage =
        _selectedImageFile != null ||
        (!_removeExistingImage && saved.hasQrisImage);
    final hasPayload = _qrisPayloadController.text.trim().isNotEmpty;
    final isConfigured = hasImage || hasPayload;

    if (!isConfigured) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_photo_alternate_rounded,
                color: Color(0xFF059669),
                size: 38,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Belum Ada QRIS Toko',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pilih foto/screenshot QRIS dari galeri HP Anda atau scan langsung kertas QRIS toko Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Pilih dari Galeri HP'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _scanQrisPayload,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('Scan Kamera'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Tampilan jika QRIS sudah terpasang
    Widget previewWidget;
    if (hasImage) {
      previewWidget = _selectedImageFile != null
          ? Image.file(
              _selectedImageFile!,
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            )
          : Image.file(
              File(saved.imagePath!),
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            );
    } else {
      previewWidget = QrImageView(
        data: _qrisPayloadController.text.trim(),
        version: QrVersions.auto,
        size: 200,
        backgroundColor: Colors.white,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Barcode QRIS Toko',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasPayload
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasPayload
                        ? const Color(0xFFA7F3D0)
                        : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasPayload ? Icons.bolt_rounded : Icons.image_rounded,
                      size: 14,
                      color: hasPayload
                          ? const Color(0xFF059669)
                          : const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasPayload ? 'Dinamis Aktif' : 'Gambar Toko',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: hasPayload
                            ? const Color(0xFF047857)
                            : const Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: previewWidget,
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 16),
                label: const Text('Ganti dari Galeri'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _scanQrisPayload,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                label: const Text('Scan Kamera'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: _clearQris,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
                tooltip: 'Hapus QRIS',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsCard() {
    final hasPayload = _qrisPayloadController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Opsi Fitur Transaksi',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),

          // Switch 1: QRIS Dinamis
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _enableDynamicQris && hasPayload,
            activeColor: const Color(0xFF059669),
            onChanged: hasPayload
                ? (val) => setState(() => _enableDynamicQris = val)
                : null,
            title: Row(
              children: [
                const Text(
                  'QRIS Dinamis Otomatis',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              hasPayload
                  ? 'Nominal tagihan kasir otomatis terkunci di HP pembeli saat scan.'
                  : 'Pilih foto QRIS dari galeri atau scan kamera untuk mengaktifkan.',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ),

          const Divider(color: Color(0xFFF1F5F9), height: 20),

          // Switch 2: Cetak di Struk Thermal
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _printOnReceipt,
            activeColor: const Color(0xFF059669),
            onChanged: (val) => setState(() => _printOnReceipt = val),
            title: const Text(
              'Cetak QRIS di Struk Kasir',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: const Text(
              'Cetak barcode QRIS di kertas nota kasir thermal setelah checkout.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Identitas Toko',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _merchantNameController,
            decoration: InputDecoration(
              labelText: 'Nama Merchant / Toko',
              hintText: 'Contoh: TOKO MANGGA JAYA',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nmidController,
            decoration: InputDecoration(
              labelText: 'NMID / Kode Toko (Opsional)',
              hintText: 'Contoh: ID1020030040',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalPayloadAccordion() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            'Rincian Kode Payload QRIS (Lanjutan)',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            TextField(
              controller: _qrisPayloadController,
              maxLines: 3,
              style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Payload Data QRIS (EMVCo)',
                hintText: '000201010211...',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: _qrisPayloadController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () =>
                            setState(() => _qrisPayloadController.clear()),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
