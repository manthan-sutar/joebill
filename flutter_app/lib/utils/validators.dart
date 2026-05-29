bool isValidIndianPhone(String? phone) {
  if (phone == null || phone.trim().isEmpty) return true;
  final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
  return digits.length == 10;
}

String? phoneValidationMessage(String? phone) {
  if (phone == null || phone.trim().isEmpty) return null;
  if (!isValidIndianPhone(phone)) return 'Enter a valid 10-digit phone number';
  return null;
}
