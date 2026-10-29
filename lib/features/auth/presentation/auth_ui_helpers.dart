String normalizeIndonesianPhone(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9+]'), '');

  if (digits.startsWith('+')) {
    return digits;
  }
  if (digits.startsWith('0')) {
    return '+62${digits.substring(1)}';
  }
  if (digits.startsWith('62')) {
    return '+$digits';
  }
  return '+62$digits';
}
