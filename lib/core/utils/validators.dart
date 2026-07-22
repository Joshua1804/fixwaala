class Validators {
  Validators._();

  static String? phone(String? value) {
    if (value == null || value.isEmpty) return 'Phone number required';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return 'Enter a valid phone number';
    return null;
  }

  static String? otp(String? value, {int length = 6}) {
    if (value == null || value.length != length) {
      return 'Enter the $length-digit OTP';
    }
    if (!RegExp(r'^\d+$').hasMatch(value)) return 'OTP must be numeric';
    return null;
  }

  static String? aadhaar(String? value) {
    if (value == null) return 'Aadhaar required';
    final digits = value.replaceAll(' ', '');
    if (digits.length != 12 || !RegExp(r'^\d+$').hasMatch(digits)) {
      return 'Aadhaar must be 12 digits';
    }
    return null;
  }

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return null; // email is optional
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }
}
