import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/utils/rupiah_input_helper.dart';
import 'package:dpos/features/customer_debt/data/customer_debt_repository.dart';
import 'package:dpos/features/customer_debt/domain/customer_debt_models.dart';
import 'package:dpos/features/customer_debt/state/customer_debt_providers.dart';

class CustomerFormScreen extends StatelessWidget {
  final Customer? initialCustomer;

  const CustomerFormScreen({super.key, this.initialCustomer});

  /// Navigasi cerdas:
  /// - Mobile & Tablet (< 1024px): Buka sebagai Halaman Baru (Full Page)
  /// - Desktop (>= 1024px): Buka sebagai Modal Dialog Popup
  static Future<Customer?> open(
    BuildContext context, {
    Customer? initialCustomer,
  }) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;

    if (isDesktop) {
      return showDialog<Customer>(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: CustomerFormContent(
                initialCustomer: initialCustomer,
                isDialog: true,
              ),
            ),
          ),
        ),
      );
    } else {
      return Navigator.of(context).push<Customer>(
        MaterialPageRoute(
          builder: (_) => CustomerFormScreen(initialCustomer: initialCustomer),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = initialCustomer != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          isEdit ? 'Edit Data Pelanggan' : 'Tambah Pelanggan Baru',
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: CustomerFormContent(
                initialCustomer: initialCustomer,
                isDialog: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomerFormContent extends ConsumerStatefulWidget {
  final Customer? initialCustomer;
  final bool isDialog;

  const CustomerFormContent({
    super.key,
    this.initialCustomer,
    required this.isDialog,
  });

  @override
  ConsumerState<CustomerFormContent> createState() => _CustomerFormContentState();
}

class _CustomerFormContentState extends ConsumerState<CustomerFormContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _limitController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;

  final _contactPicker = FlutterNativeContactPicker();
  bool _isLoading = false;
  bool _isPickingContact = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initialCustomer;
    _nameController = TextEditingController(text: c?.name ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _limitController = TextEditingController(
      text: c != null && c.creditLimit > 0 ? RupiahInputHelper.format(c.creditLimit) : '',
    );
    _addressController = TextEditingController(text: c?.address ?? '');
    _notesController = TextEditingController(text: c?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _limitController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickFromContacts() async {
    setState(() => _isPickingContact = true);
    try {
      final Contact? contact = await _contactPicker.selectContact();
      if (contact != null) {
        // Auto-fill nama jika nama masih kosong
        if (_nameController.text.trim().isEmpty && contact.fullName != null) {
          _nameController.text = contact.fullName!.trim();
        }

        // Ambil nomor HP dari kontak
        if (contact.phoneNumbers != null && contact.phoneNumbers!.isNotEmpty) {
          var clean = contact.phoneNumbers!.first.replaceAll(RegExp(r'\D'), '');
          if (clean.startsWith('62')) {
            clean = '0${clean.substring(2)}';
          }
          _phoneController.text = clean;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kontak "${contact.fullName ?? "Pelanggan"}" berhasil dipilih.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak dapat membuka kontak: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingContact = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final bootstrap = ref.read(homeBootstrapProvider).value;
    final businessId = bootstrap?.business?.id;
    if (businessId == null) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(customerDebtRepositoryProvider);
      final limit = RupiahInputHelper.parseToDouble(_limitController.text);

      Customer result;
      if (widget.initialCustomer != null) {
        result = await repo.updateCustomer(
          customerId: widget.initialCustomer!.id,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          creditLimit: limit,
          notes: _notesController.text.trim(),
        );
      } else {
        result = await repo.createCustomer(
          businessId: businessId,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          creditLimit: limit,
          notes: _notesController.text.trim(),
        );
      }

      ref.invalidate(customersProvider);

      if (mounted) {
        Navigator.pop(context, result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.initialCustomer != null
                  ? 'Data pelanggan berhasil diperbarui.'
                  : 'Pelanggan "${result.name}" berhasil ditambahkan.',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialCustomer != null;

    return Container(
      decoration: widget.isDialog
          ? null
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
      padding: widget.isDialog ? EdgeInsets.zero : const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header jika di dalam modal dialog
            if (widget.isDialog) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Color(0xFF059669),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Pelanggan' : 'Tambah Pelanggan Baru',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Catat pelanggan & nomor WA untuk kasbon',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 20),
            ],

            // ── NAMA PELANGGAN ──────────────────────────────────────────
            Text(
              'Nama Lengkap / Panggilan *',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Nama pelanggan wajib diisi';
                }
                return null;
              },
              decoration: _inputDecoration('Contoh: Bu Rini / Mas Budi'),
            ),
            const SizedBox(height: 18),

            // ── NOMOR WHATSAPP + PILIH DARI KONTAK ──────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nomor WhatsApp *',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isPickingContact ? null : _pickFromContacts,
                  icon: _isPickingContact
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.contacts_rounded, size: 16),
                  label: const Text('Pilih dari Kontak HP'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF059669),
                    visualDensity: VisualDensity.compact,
                    textStyle: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Nomor WhatsApp wajib diisi untuk kirim tagihan kasbon';
                }
                final clean = val.replaceAll(RegExp(r'\D'), '');
                if (clean.length < 9) {
                  return 'Nomor HP tidak valid (minimal 9 digit)';
                }
                return null;
              },
              decoration: _inputDecoration(
                'Contoh: 081234567890',
                suffix: IconButton(
                  icon: const Icon(Icons.perm_contact_calendar_outlined, color: Color(0xFF059669)),
                  tooltip: 'Pilih dari Kontak HP',
                  onPressed: _isPickingContact ? null : _pickFromContacts,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ── PLAFON KASBON ───────────────────────────────────────────
            Text(
              'Batas Plafon Kasbon (Opsional)',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Maksimal total kasbon yang boleh diambil. Kosongkan jika tanpa batas.',
              style: GoogleFonts.manrope(fontSize: 11, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _limitController,
              keyboardType: TextInputType.number,
              inputFormatters: const [
                RupiahTextInputFormatter(allowEmpty: true),
              ],
              decoration: _inputDecoration('Contoh: 500.000', prefix: 'Rp '),
            ),
            const SizedBox(height: 18),

            // ── ALAMAT ──────────────────────────────────────────────────
            Text(
              'Alamat / Patokan Rumah (Opsional)',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _addressController,
              decoration: _inputDecoration('Misal: Jl. Melati No. 12, samping pos ronda'),
            ),
            const SizedBox(height: 18),

            // ── CATATAN ─────────────────────────────────────────────────
            Text(
              'Catatan Tambahan (Opsional)',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: _inputDecoration('Misal: Langganan tetap, bayar setiap tanggal 25'),
            ),
            const SizedBox(height: 28),

            // ── BUTTONS ─────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      'Batal',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            isEdit ? 'Simpan Perubahan' : 'Simpan Pelanggan',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            if (isEdit) ...[
              const SizedBox(height: 20),
              Center(
                child: TextButton.icon(
                  onPressed: _isLoading ? null : _deleteCustomer,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                  label: Text(
                    'Hapus Data Pelanggan Ini',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCustomer() async {
    final customer = widget.initialCustomer;
    if (customer == null) return;

    if (customer.hasDebt) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
              const SizedBox(width: 10),
              Text(
                'Tidak Dapat Dihapus',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          content: Text(
            'Pelanggan "${customer.name}" masih memiliki sisa kasbon sebesar ${RupiahInputHelper.formatWithPrefix(customer.currentDebt)}.\n\nMohon lunasi kasbon terlebih dahulu sebelum menghapus data pelanggan.',
            style: GoogleFonts.manrope(fontSize: 13, height: 1.4, color: const Color(0xFF475569)),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus Pelanggan?',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus data pelanggan "${customer.name}" (${customer.phone}) dari kontak toko?',
          style: GoogleFonts.manrope(fontSize: 13, height: 1.4, color: const Color(0xFF475569)),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final repo = ref.read(customerDebtRepositoryProvider);
        await repo.deleteCustomer(customer.id);
        ref.invalidate(customersProvider);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pelanggan "${customer.name}" berhasil dihapus.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus pelanggan: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _inputDecoration(String hint, {String? prefix, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefix,
      suffixIcon: suffix,
      hintStyle: GoogleFonts.manrope(fontSize: 13, color: const Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
      ),
    );
  }
}
