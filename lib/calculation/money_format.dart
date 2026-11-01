String formatCents(int cents, {bool withSymbol = true}) {
  final int absolute = cents.abs();
  final String whole = _groupDigits((absolute ~/ 100).toString());
  final String fraction = (absolute % 100).toString().padLeft(2, '0');
  final String sign = cents < 0 ? '-' : '';
  final String symbol = withSymbol ? '¥' : '';
  return '$sign$symbol$whole.$fraction';
}

String formatEditableCents(int cents) {
  final int whole = cents ~/ 100;
  final int fraction = cents % 100;
  if (fraction == 0) {
    return whole.toString();
  }
  final String fractionText = fraction
      .toString()
      .padLeft(2, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return '$whole.$fractionText';
}

String formatRate(int basisPoints) {
  final int whole = basisPoints ~/ 100;
  final int fraction = basisPoints % 100;
  if (fraction == 0) {
    return '$whole%';
  }
  final String decimals = fraction
      .toString()
      .padLeft(2, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return '$whole.$decimals%';
}

int? parseAmountCents(String raw) {
  final String cleaned = raw
      .trim()
      .replaceAll(',', '')
      .replaceAll('¥', '')
      .replaceAll('￥', '')
      .replaceAll('%', '');
  if (cleaned.isEmpty ||
      cleaned == '.' ||
      !RegExp(r'^\d*(\.\d{0,2})?$').hasMatch(cleaned)) {
    return null;
  }

  final List<String> parts = cleaned.split('.');
  final String wholeText = parts.first.isEmpty ? '0' : parts.first;
  final int? whole = int.tryParse(wholeText);
  if (whole == null) {
    return null;
  }
  final String fractionText = (parts.length > 1 ? parts[1] : '').padRight(
    2,
    '0',
  );
  final int fraction = fractionText.isEmpty ? 0 : int.parse(fractionText);
  return whole * 100 + fraction;
}

int? parseRateBasisPoints(String raw) {
  return parseAmountCents(raw);
}

String _groupDigits(String digits) {
  if (digits.length <= 3) {
    return digits;
  }
  final List<String> groups = <String>[];
  String remaining = digits;
  while (remaining.length > 3) {
    groups.insert(0, remaining.substring(remaining.length - 3));
    remaining = remaining.substring(0, remaining.length - 3);
  }
  groups.insert(0, remaining);
  return groups.join(',');
}
