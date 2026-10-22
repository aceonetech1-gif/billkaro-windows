/// Tax lines for a bill's totals section.
///
/// With [split] on, intra-state GST is shown as CGST + SGST (half the rate
/// each), one pair per GST rate on the bill. Otherwise a single "Tax (GST)"
/// line. Empty when nothing is taxed.
///
/// Each pair is rounded so CGST + SGST equals that rate's tax exactly.
List<({String label, double amount})> billTaxRows({
  required Iterable<({double amount, double rate})> lines,
  required double totalTax,
  required bool split,
}) {
  if (totalTax <= 0) return const [];
  if (!split) return [(label: 'Tax (GST)', amount: totalTax)];

  final taxableByRate = <double, double>{};
  for (final line in lines) {
    if (line.rate <= 0) continue;
    taxableByRate.update(
      line.rate,
      (sum) => sum + line.amount,
      ifAbsent: () => line.amount,
    );
  }

  final rates = taxableByRate.keys.toList()..sort();
  return [
    for (final rate in rates) ..._splitRows(rate, taxableByRate[rate]!),
  ];
}

List<({String label, double amount})> _splitRows(double rate, double taxable) {
  final tax = _round2(taxable * rate / 100);
  final cgst = _round2(tax / 2);
  final half = _percentLabel(rate / 2);
  return [
    (label: 'CGST @$half', amount: cgst),
    (label: 'SGST @$half', amount: _round2(tax - cgst)),
  ];
}

double _round2(double value) => (value * 100).roundToDouble() / 100;

/// 2.5 -> "2.5%", 9.0 -> "9%".
String _percentLabel(double value) =>
    '${value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')}%';
