import 'package:intl/intl.dart';

class CurrencyUtils {
  static String formatRp(double amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }
}
