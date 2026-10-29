import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class RupiahInputHelper {
  RupiahInputHelper._();

  static final NumberFormat _numberFormat = NumberFormat.decimalPattern(
    'id_ID',
  );

  static String digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static int parseToInt(String value) {
    final normalized = digitsOnly(value);
    return int.tryParse(normalized) ?? 0;
  }

  static double parseToDouble(String value) {
    return parseToInt(value).toDouble();
  }

  static String format(num? value) {
    final normalizedValue = value == null ? 0 : value.round();
    return _numberFormat.format(normalizedValue);
  }

  static String formatWithPrefix(num? value) {
    return 'Rp ${format(value)}';
  }
}

class RupiahTextInputFormatter extends TextInputFormatter {
  const RupiahTextInputFormatter({this.allowEmpty = false});

  final bool allowEmpty;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = RupiahInputHelper.digitsOnly(newValue.text);
    if (digits.isEmpty) {
      final text = allowEmpty ? '' : '0';
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }

    final value = int.tryParse(digits) ?? 0;
    final formatted = RupiahInputHelper.format(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
