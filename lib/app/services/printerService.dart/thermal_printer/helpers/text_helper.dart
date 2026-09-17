class TextHelper {
  static String padRight(String text, int width) {
    if (width <= 0) return '';
    if (text.length > width) return text.substring(0, width);
    return text.padRight(width);
  }

  /// Pads left. If too long, keeps the rightmost characters (safe for amounts).
  static String padLeft(String text, int width) {
    if (width <= 0) return '';
    if (text.length > width) {
      return text.substring(text.length - width);
    }
    return text.padLeft(width);
  }

  static String formatRow(String left, String right, int width) {
    if (width <= 0) return '';
    // Clamp sides so the row never exceeds [width] (avoids wrap → misalignment).
    var l = left;
    var r = right;
    if (l.length + r.length > width) {
      final rightBudget = (width / 2).floor().clamp(0, width);
      final leftBudget = (width - rightBudget).clamp(0, width);
      if (r.length > rightBudget) r = r.substring(r.length - rightBudget);
      if (l.length > leftBudget) l = l.substring(0, leftBudget);
    }
    final gap = width - l.length - r.length;
    return l + ' ' * gap + r;
  }

  /// Label on the left, money on the far right (same edge as item Amount column).
  static String moneyRow({
    required String label,
    required String amount,
    required int totalWidth,
    required int amountWidth,
  }) {
    final aw = amountWidth.clamp(1, totalWidth);
    final lw = totalWidth - aw;
    return padRight(label, lw) + padLeft(amount, aw);
  }

  /// Fixed-width invoice table row. Item left; Qty/Price/GST/Amount right-aligned.
  static String invoiceTableRow({
    required String item,
    required String qty,
    required String price,
    required String gst,
    required String amount,
    required int itemW,
    required int qtyW,
    required int priceW,
    required int gstW,
    required int amountW,
  }) {
    return padRight(item, itemW) +
        padLeft(qty, qtyW) +
        padLeft(price, priceW) +
        padLeft(gst, gstW) +
        padLeft(amount, amountW);
  }

  /// Matches [ThermalKOTReceipt]: name left, qty right on one row.
  static List<String> kotNameQtyLines(
    String itemName,
    int quantity,
    int receiptWidth,
  ) {
    final qty = 'x$quantity';
    final firstLineNameMax = receiptWidth - qty.length;
    if (firstLineNameMax < 1) {
      return [formatRow(itemName, qty, receiptWidth)];
    }
    if (itemName.length <= firstLineNameMax) {
      return [formatRow(itemName, qty, receiptWidth)];
    }

    final lines = <String>[
      formatRow(itemName.substring(0, firstLineNameMax), qty, receiptWidth),
    ];
    var pos = firstLineNameMax;
    while (pos < itemName.length) {
      final end = (pos + receiptWidth).clamp(0, itemName.length);
      lines.add(itemName.substring(pos, end));
      pos = end;
    }
    return lines;
  }

  static String kotCategoryRemarkLine({String? category, String? remark}) {
    final cat = category?.trim() ?? '';
    final rem = remark?.trim() ?? '';
    return [
      if (cat.isNotEmpty) '($cat)',
      if (rem.isNotEmpty) '* $rem',
    ].join(' ');
  }

  /// Category and/or remark on lines below the item (indented).
  static List<String> kotSublineLines({
    required String? category,
    required String? remark,
    required int receiptWidth,
    String indent = '  ',
  }) {
    final lines = <String>[];
    final cat = category?.trim() ?? '';
    final rem = remark?.trim() ?? '';
    if (cat.isNotEmpty) {
      lines.addAll(_wrapIndented('($cat)', receiptWidth, indent));
    }
    if (rem.isNotEmpty) {
      lines.addAll(_wrapIndented('* $rem', receiptWidth, indent));
    }
    return lines;
  }

  static List<String> _wrapIndented(
    String text,
    int receiptWidth,
    String indent,
  ) {
    final lines = <String>[];
    var pos = 0;
    var first = true;
    while (pos < text.length) {
      final budget = first ? receiptWidth - indent.length : receiptWidth;
      if (budget < 1) break;
      final end = (pos + budget).clamp(0, text.length);
      lines.add(
        first ? '$indent${text.substring(pos, end)}' : text.substring(pos, end),
      );
      pos = end;
      first = false;
    }
    return lines;
  }
}
