import 'package:intl/intl.dart';

final _currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
final _timeFmt = DateFormat('hh:mm a');
final _dateFmt = DateFormat('dd MMM yyyy');
final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

String formatCurrency(double amount) => _currencyFmt.format(amount);
String formatTime(DateTime dt) => _timeFmt.format(dt.toLocal());
String formatDate(DateTime dt) => _dateFmt.format(dt.toLocal());
String formatDateTime(DateTime dt) => _dateTimeFmt.format(dt.toLocal());

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m}m ${s}s';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}

String categoryLabel(String cat) {
  switch (cat) {
    case 'beverage': return 'Beverage';
    case 'drink': return 'Drink';
    case 'food': return 'Food';
    case 'game': return 'Game';
    default: return cat;
  }
}
