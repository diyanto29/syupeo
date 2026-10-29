import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/features/transaction/data/receipt_service.dart';

class TableQrGeneratorDialog extends StatefulWidget {
  const TableQrGeneratorDialog({
    super.key,
    required this.outletId,
    required this.outletName,
  });

  final String outletId;
  final String outletName;

  @override
  State<TableQrGeneratorDialog> createState() => _TableQrGeneratorDialogState();
}

class _TableQrGeneratorDialogState extends State<TableQrGeneratorDialog> {
  final _tableController = TextEditingController();
  String _generatedUrl = '';

  // Base URL for ordering - should be configurable in production
  // For now we use a placeholder or detect it if possible
  final String _baseUrl = 'https://pos.mudahkan.online';

  void _generate() {
    final table = _tableController.text.trim();
    if (table.isEmpty) return;

    setState(() {
      _generatedUrl = '$_baseUrl/order/${widget.outletId}/$table';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'QR Self-Order',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat QR Code untuk meja di ${widget.outletName}',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _tableController,
              decoration: InputDecoration(
                labelText: 'Nomor Meja',
                hintText: 'Contoh: 12 atau B-01',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() => _generatedUrl = ''),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _generate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Generate QR Code'),
              ),
            ),
            if (_generatedUrl.isNotEmpty) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: QrImageView(
                  data: _generatedUrl,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _generatedUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Link disalin ke clipboard'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Salin'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, _) => OutlinedButton.icon(
                        onPressed: () async {
                          final success = await ref
                              .read(receiptServiceProvider)
                              .printTableQr(
                                url: _generatedUrl,
                                outletName: widget.outletName,
                                tableNumber: _tableController.text,
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'Berhasil mencetak'
                                      : 'Gagal mencetak',
                                ),
                                backgroundColor: success
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: const Text('Cetak'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Share.share(
                          'Scan QR ini untuk memesan di ${widget.outletName} (Meja ${_tableController.text}):\n$_generatedUrl',
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF98B35),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Tutup',
                style: GoogleFonts.manrope(color: theme.colorScheme.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
