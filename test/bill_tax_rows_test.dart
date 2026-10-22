import 'package:billkaro/utils/bill_tax_rows.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no tax gives no rows', () {
    expect(billTaxRows(lines: const [], totalTax: 0, split: true), isEmpty);
  });

  test('split off gives a single Tax (GST) row', () {
    final rows = billTaxRows(
      lines: const [(amount: 200, rate: 5)],
      totalTax: 10,
      split: false,
    );
    expect(rows, [(label: 'Tax (GST)', amount: 10.0)]);
  });

  test('splits each rate into CGST and SGST halves', () {
    final rows = billTaxRows(
      lines: const [
        (amount: 100, rate: 5),
        (amount: 100, rate: 5),
        (amount: 50, rate: 18),
        (amount: 30, rate: 0),
      ],
      totalTax: 19,
      split: true,
    );
    expect(rows, [
      (label: 'CGST @2.5%', amount: 5.0),
      (label: 'SGST @2.5%', amount: 5.0),
      (label: 'CGST @9%', amount: 4.5),
      (label: 'SGST @9%', amount: 4.5),
    ]);
  });

  test('odd paisa: CGST + SGST still equals the rate tax', () {
    // 5% of 10.10 = 0.505 -> 0.51 tax; halves 0.26 + 0.25.
    final rows = billTaxRows(
      lines: const [(amount: 10.10, rate: 5)],
      totalTax: 0.505,
      split: true,
    );
    expect(rows[0].amount + rows[1].amount, closeTo(0.51, 1e-9));
  });
}
