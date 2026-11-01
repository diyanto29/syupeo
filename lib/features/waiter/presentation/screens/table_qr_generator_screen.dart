import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/features/transaction/data/receipt_service.dart';

class TableQrGeneratorScreen extends ConsumerStatefulWidget {
  const TableQrGeneratorScreen({
    super.key,
    required this.outletId,
    required this.outletName,
    this.padding,
  });

  final String outletId;
  final String outletName;
  final EdgeInsetsGeometry? padding;

  @override
  ConsumerState<TableQrGeneratorScreen> createState() =>
      _TableQrGeneratorScreenState();
}

class _TableQrGeneratorScreenState
    extends ConsumerState<TableQrGeneratorScreen> {
  final _tableController = TextEditingController();
  String _generatedUrl = '';
  final String _baseUrl = 'https://syupeo-admin.mudahkan.online';

  void _generate() {
    final table = _tableController.text.trim();
    if (table.isEmpty) return;

    setState(() {
      _generatedUrl = '$_baseUrl/order/${widget.outletId}/$table';
    });

    // Unfocus keyboard
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: widget.padding ?? const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme, scheme),
          const SizedBox(height: 20),
          _buildInputCard(theme, scheme),
          if (_generatedUrl.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildQrDisplayCard(theme, scheme),
            const SizedBox(height: 24),
            _buildActionsRow(theme, scheme),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QR Self-Order',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Buat QR Code untuk meja di ${widget.outletName}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildInputCard(ThemeData theme, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informasi Meja',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tableController,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            decoration: InputDecoration(
              labelText: 'Nomor Meja',
              hintText: 'Contoh: 12 atau B-01',
              filled: true,
              fillColor: scheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() => _generatedUrl = ''),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.qr_code_rounded),
              label: const Text('Generate QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrDisplayCard(ThemeData theme, ColorScheme scheme) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            QrImageView(
              data: _generatedUrl,
              version: QrVersions.auto,
              size: 240.0,
              gapless: false,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF1E293B),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'MEJA: ${_tableController.text}',
              style: GoogleFonts.manrope(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1E293B),
              ),
            ),
            Text(
              widget.outletName,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsRow(ThemeData theme, ColorScheme scheme) {
    return Row(
      children: [
        _buildActionButton(
          label: 'Salin',
          icon: Icons.copy_rounded,
          color: scheme.secondary,
          onTap: () {
            Clipboard.setData(ClipboardData(text: _generatedUrl));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Link disalin ke clipboard')),
            );
          },
        ),
        const SizedBox(width: 12),
        _buildActionButton(
          label: 'Cetak',
          icon: Icons.print_rounded,
          color: scheme.primary,
          onTap: () async {
            final success = await ref
                .read(receiptServiceProvider)
                .printTableQr(
                  url: _generatedUrl,
                  outletName: widget.outletName,
                  tableNumber: _tableController.text,
                );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success ? 'Berhasil mencetak' : 'Gagal mencetak',
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            }
          },
        ),
        const SizedBox(width: 12),
        _buildActionButton(
          label: 'Share',
          icon: Icons.share_rounded,
          color: const Color(0xFFF98B35),
          onTap: () {
            Share.share(
              'Scan QR ini untuk memesan di ${widget.outletName} (Meja ${_tableController.text}):\n$_generatedUrl',
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
