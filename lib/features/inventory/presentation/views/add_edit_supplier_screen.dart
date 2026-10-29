import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/core/widgets/app_form_field.dart';
import 'package:dpos/features/inventory/domain/inventory_models.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/inventory/presentation/views/supplier_list_screen.dart';

class AddEditSupplierScreen extends ConsumerStatefulWidget {
  const AddEditSupplierScreen({super.key, this.supplier});

  final Supplier? supplier;

  @override
  ConsumerState<AddEditSupplierScreen> createState() =>
      _AddEditSupplierScreenState();
}

class _AddEditSupplierScreenState extends ConsumerState<AddEditSupplierScreen> {
  late final TextEditingController nameController;
  late final TextEditingController contactController;
  late final TextEditingController phoneController;
  late final TextEditingController emailController;
  late final TextEditingController addressController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.supplier?.name);
    contactController = TextEditingController(
      text: widget.supplier?.contactName,
    );
    phoneController = TextEditingController(text: widget.supplier?.phone);
    emailController = TextEditingController(text: widget.supplier?.email);
    addressController = TextEditingController(text: widget.supplier?.address);
  }

  @override
  void dispose() {
    nameController.dispose();
    contactController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama supplier wajib diisi')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final bootstrap = ref.read(homeBootstrapProvider).value;
      final businessId = bootstrap?.business?.id;
      if (businessId == null) throw Exception('Business ID not found');

      final supplier =
          widget.supplier?.copyWith(
            name: nameController.text.trim(),
            contactName: contactController.text.trim(),
            phone: phoneController.text.trim(),
            email: emailController.text.trim(),
            address: addressController.text.trim(),
          ) ??
          Supplier(
            id: '',
            businessId: businessId,
            name: nameController.text.trim(),
            contactName: contactController.text.trim(),
            phone: phoneController.text.trim(),
            email: emailController.text.trim(),
            address: addressController.text.trim(),
          );

      await ref.read(supplierListProvider.notifier).upsertSupplier(supplier);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.supplier == null
                  ? 'Supplier berhasil ditambahkan'
                  : 'Supplier berhasil diperbarui',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        log(e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.supplier == null ? 'Tambah Supplier' : 'Edit Supplier',
        ),
        actions: [
          if (!isSaving)
            TextButton(
              onPressed: _save,
              child: const Text(
                'SIMPAN',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                theme,
                'Informasi Utama',
                Icons.business_rounded,
              ),
              const SizedBox(height: 16),
              _buildCard(
                scheme,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: nameController,
                      label: 'Nama Perusahaan/Supplier',
                      hint: 'Contoh: PT. Sumber Makmur',
                      icon: Icons.store_rounded,
                      required: true,
                    ),
                    const Divider(height: 32),
                    _buildTextField(
                      controller: contactController,
                      label: 'Nama Kontak Person',
                      hint: 'Nama orang yang bisa dihubungi',
                      icon: Icons.person_outline_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildSectionHeader(
                theme,
                'Kontak & Alamat',
                Icons.contact_phone_rounded,
              ),
              const SizedBox(height: 16),
              _buildCard(
                scheme,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: phoneController,
                      label: 'Nomor Telepon',
                      hint: '0812xxxx',
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                    const Divider(height: 32),
                    _buildTextField(
                      controller: emailController,
                      label: 'Alamat Email',
                      hint: 'supplier@email.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const Divider(height: 32),
                    _buildTextField(
                      controller: addressController,
                      label: 'Alamat Lengkap',
                      hint: 'Jalan, Kota, Kode Pos',
                      icon: Icons.location_on_outlined,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.supplier == null
                              ? 'Tambahkan Supplier'
                              : 'Simpan Perubahan',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(ColorScheme scheme, {required Widget child}) {
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return AppTextInput(
      controller: controller,
      label: label,
      isRequired: required,
      hintText: hint,
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }
}
