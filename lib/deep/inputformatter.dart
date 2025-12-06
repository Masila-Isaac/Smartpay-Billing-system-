import 'package:flutter/services.dart';

class InputFormatters {
  // Phone number formatter (digits only)
  static TextInputFormatter get phoneFormatter =>
      FilteringTextInputFormatter.digitsOnly;

  // ID number formatter (digits only)
  static TextInputFormatter get idFormatter =>
      FilteringTextInputFormatter.digitsOnly;

  // Name formatter (letters and spaces only)
  static TextInputFormatter get nameFormatter =>
      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'));

  // Meter/Account number formatter (alphanumeric)
  static TextInputFormatter get alphanumericFormatter =>
      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]'));

  // Email formatter (no special validation, just basic)
  static TextInputFormatter get emailFormatter =>
      FilteringTextInputFormatter.deny(RegExp(r'[ ]'));

  // Amount formatter (decimal numbers)
  static List<TextInputFormatter> get amountFormatters => [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        TextInputFormatter.withFunction((oldValue, newValue) {
          final text = newValue.text;
          if (text.contains('.')) {
            final parts = text.split('.');
            if (parts.length > 2) {
              return oldValue;
            }
            if (parts.length == 2 && parts[1].length > 2) {
              return oldValue;
            }
          }
          return newValue;
        }),
      ];
}
