import 'package:flutter/material.dart';
import 'package:dpos/features/customer_debt/domain/customer_debt_models.dart';
import 'package:dpos/features/customer_debt/presentation/customer_form_screen.dart';

/// Backward-compatible dialog wrapper that renders CustomerFormContent
class AddCustomerDialog extends StatelessWidget {
  final Customer? initialCustomer;

  const AddCustomerDialog({super.key, this.initialCustomer});

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
    );
  }
}
