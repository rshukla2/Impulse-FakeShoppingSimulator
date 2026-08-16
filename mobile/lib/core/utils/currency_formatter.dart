import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double amount, String currency, String symbol) {
    final curr = currency.toUpperCase();

    if (curr == 'INR') {
      // Indian numbering format (e.g. ₹4,149 or ₹48,291)
      final intAmount = amount.round();
      final s = intAmount.toString();
      if (s.length > 3) {
        final lastThree = s.substring(s.length - 3);
        var remaining = s.substring(0, s.length - 3);
        var formattedRemaining = '';
        while (remaining.length > 2) {
          formattedRemaining =
              ',${remaining.substring(remaining.length - 2)}$formattedRemaining';
          remaining = remaining.substring(0, remaining.length - 2);
        }
        formattedRemaining = remaining + formattedRemaining;
        return '$symbol$formattedRemaining,$lastThree';
      }
      return '$symbol$intAmount';
    } else if (curr == 'JPY') {
      final formatter = NumberFormat('#,##0', 'ja_JP');
      return '$symbol${formatter.format(amount.round())}';
    } else if (curr == 'GBP') {
      final formatter = NumberFormat('#,##0.00', 'en_GB');
      return '$symbol${formatter.format(amount)}';
    } else if (curr == 'EUR') {
      final formatter = NumberFormat('#,##0.00', 'de_DE');
      return '$symbol${formatter.format(amount)}';
    } else {
      // Default USD / other currencies
      final formatter = NumberFormat('#,##0.00', 'en_US');
      return '$symbol${formatter.format(amount)}';
    }
  }
}
