class PrintBuilder {
  final List<int> bytes = [];
  static const int paperWidth = 48;

  /// Receipt row width for monospace ESC/POS text.
  /// - 58mm (2"): 32 chars
  /// - 80mm (3"): 48 chars
  /// - 104mm (4"): 64 chars
  final int receiptWidth;
  final int _lineWidth;
  final int _printAreaDots;

  // ESC/POS Commands
  static const _ESC = 0x1B;
  static const _GS = 0x1D;
  static const _LF = 0x0A;

  PrintBuilder({
    int receiptWidth = 32,
    int printAreaDots = 384,
    bool useCompactFont = false,
  }) : receiptWidth = receiptWidth,
       _lineWidth = receiptWidth,
       _printAreaDots = printAreaDots.clamp(128, 1024) {
    bytes.addAll([_ESC, 0x40]); // ESC @ initialize
    // Motion unit ≈ 1/203 inch (dot) so GS W/L use printer dots.
    bytes.addAll([_GS, 0x50, 0x00, 0x00]); // GS P — default motion units
    // Expand printable width (critical for 104mm — without this many heads
    // stay at 80mm/48 chars and wrap our 64-char rows).
    bytes.addAll([_GS, 0x4C, 0x00, 0x00]); // GS L left margin = 0
    bytes.addAll([
      _GS,
      0x57,
      _printAreaDots & 0xFF,
      (_printAreaDots >> 8) & 0xFF,
    ]); // GS W print area width
    // Font B (~9-dot) packs 64 chars into an 80mm buffer — prevents the wrap
    // seen on 4" rolls when the head still defaults to 576 dots.
    bytes.addAll([_ESC, 0x4D, useCompactFont ? 0x01 : 0x00]); // ESC M
    bytes.addAll([_ESC, 0x21, 0x00]); // ESC ! 0 — normal size
    bytes.addAll([_ESC, 0x61, 0x00]); // ESC a 0 — left align
  }

  PrintBuilder text(String text) {
    bytes.addAll(text.codeUnits);
    return this;
  }

  PrintBuilder bold(String text) {
    bytes.addAll([_ESC, 0x45, 0x01]); // Bold on
    bytes.addAll(text.codeUnits);
    bytes.addAll([_ESC, 0x45, 0x00]); // Bold off
    return this;
  }

  PrintBuilder boldDoubleHeight(String text) {
    bytes.addAll([_ESC, 0x45, 0x01]); // Bold on
    bytes.addAll([_ESC, 0x21, 0x10]); // Double height only
    bytes.addAll(text.codeUnits);
    bytes.addAll([_ESC, 0x21, 0x00]); // Normal size
    bytes.addAll([_ESC, 0x45, 0x00]); // Bold off
    return this;
  }

  PrintBuilder boldNormal(String text) {
    bytes.addAll([_ESC, 0x21, 0x00]);
    if (text.isNotEmpty) bytes.addAll(text.codeUnits);
    return this;
  }

  PrintBuilder left() {
    bytes.addAll([_ESC, 0x61, 0x00]);
    return this;
  }

  PrintBuilder center() {
    bytes.addAll([_ESC, 0x61, 0x01]);
    return this;
  }

  PrintBuilder right() {
    bytes.addAll([_ESC, 0x61, 0x02]);
    return this;
  }

  /// Single horizontal rule (never a double wrap-line).
  PrintBuilder line() {
    bytes.addAll([_ESC, 0x61, 0x00]); // left — never center a full-width rule
    // width-1 avoids the classic thermal "extra wrap row" on a full line.
    final n = (_lineWidth > 1) ? _lineWidth - 1 : _lineWidth;
    bytes.addAll(List.filled(n, 0x2D));
    bytes.add(_LF);
    return this;
  }

  PrintBuilder feed(int lines) {
    for (int i = 0; i < lines; i++) bytes.add(_LF);
    return this;
  }

  PrintBuilder cut() {
    bytes.addAll([_GS, 0x56, 0x00]);
    return this;
  }
}
