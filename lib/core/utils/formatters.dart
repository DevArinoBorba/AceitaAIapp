// Formatadores pt-BR sem dependência de `intl` (menos atrito de versão).
// Trocar por `intl` quando entrarem outros idiomas.

String brl(double value) => 'R\$ ${_number(value, 2)}';

String brlCompact(double value) => 'R\$ ${_number(value, 0)}';

String _number(double value, int decimals) {
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    final remaining = intPart.length - i;
    final isDigit = intPart[i].codeUnitAt(0) >= 48 && intPart[i].codeUnitAt(0) <= 57;
    if (isDigit && i > 0 && remaining % 3 == 0) buffer.write('.');
    buffer.write(intPart[i]);
  }
  if (decimals == 0) return buffer.toString();
  return '${buffer.toString()},${parts[1]}';
}

String kmLabel(double value) => '${_number(value, 1)} km';

String timeLabel(int minutes) {
  if (minutes <= 0) return '--';
  if (minutes < 60) return '${minutes}min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '${hours}h' : '${hours}h${rest.toString().padLeft(2, '0')}';
}

String pctLabel(double value) => '${_number(value, 0)}%';

String decimal(double value, [int decimals = 1]) => _number(value, decimals);

String shortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month $hour:$minute';
}

String weekdayShort(DateTime date) {
  const names = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
  return names[(date.weekday - 1).clamp(0, 6)];
}
