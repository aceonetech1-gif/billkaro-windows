import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

/// Thermal roll widths supported in printer settings.
enum ThermalPaperSize {
  /// 2 inch (58 mm)
  mm58,

  /// 3 inch (80 mm)
  mm80;

  static ThermalPaperSize fromStorageKey(String? key) {
    switch (key) {
      case '80':
      // Legacy 4" (104 mm) setting falls back to 3" now that 4" is removed.
      case '104':
        return ThermalPaperSize.mm80;
      case '58':
      default:
        return ThermalPaperSize.mm58;
    }
  }
}

extension ThermalPaperSizeX on ThermalPaperSize {
  /// Monospace character width used by [PrintBuilder] and receipt layout.
  /// Font A (~12 dots/char).
  int get receiptWidthChars {
    switch (this) {
      case ThermalPaperSize.mm58:
        return 32; // 384 / 12
      case ThermalPaperSize.mm80:
        return 48; // 576 / 12
    }
  }

  /// Approximate printable width in dots (203 dpi). Kept for API compatibility.
  int get printAreaDots {
    switch (this) {
      case ThermalPaperSize.mm58:
        return 384;
      case ThermalPaperSize.mm80:
        return 576;
    }
  }

  /// ESC/POS paper profile.
  PaperSize get escPosPaperSize {
    switch (this) {
      case ThermalPaperSize.mm58:
        return PaperSize.mm58;
      case ThermalPaperSize.mm80:
        return PaperSize.mm80;
    }
  }

  String get storageKey {
    switch (this) {
      case ThermalPaperSize.mm58:
        return '58';
      case ThermalPaperSize.mm80:
        return '80';
    }
  }

  ({int w, int item, int qty, int price, int gst, int amount})
  invoiceColumns() {
    final w = receiptWidthChars;
    // Sums must equal [w] exactly — any overflow wraps and breaks alignment.
    if (w >= 48) {
      // 18+5+8+5+12 = 48
      return (w: w, item: 18, qty: 5, price: 8, gst: 5, amount: 12);
    }
    // 10+4+6+4+8 = 32
    return (w: w, item: 10, qty: 4, price: 6, gst: 4, amount: 8);
  }

  /// Dots per QR module (solid black/white squares). Larger = clearer scan.
  int get qrModuleDots {
    switch (this) {
      case ThermalPaperSize.mm58:
        return 5;
      case ThermalPaperSize.mm80:
        return 6;
    }
  }

  /// Max QR bitmap width so the code fits the printable area with side margin.
  int get qrMaxDots {
    switch (this) {
      case ThermalPaperSize.mm58:
        return 220; // 58mm ≈ 384 dots
      case ThermalPaperSize.mm80:
        return 300; // 80mm ≈ 576 dots
    }
  }

  /// Target QR bitmap width in printer dots (snapped to whole modules later).
  int get qrBitmapSize => qrMaxDots;

  /// Max logo raster width (dots) at the top of bills; multiple of 8.
  int get logoMaxWidthDots {
    switch (this) {
      case ThermalPaperSize.mm58:
        return 368; // 58mm ≈ 384 dots
      case ThermalPaperSize.mm80:
        return 552; // 80mm ≈ 576 dots
    }
  }

  /// Max logo raster height (dots) so tall logos do not waste paper.
  int get logoMaxHeightDots {
    switch (this) {
      case ThermalPaperSize.mm58:
        return 280;
      case ThermalPaperSize.mm80:
        return 360;
    }
  }

  /// Native ESC/POS QR module size (1–16; capped for cheap clone printers).
  int get escPosQrModuleSize {
    switch (this) {
      case ThermalPaperSize.mm58:
        return 4;
      case ThermalPaperSize.mm80:
        return 5;
    }
  }

  /// Effective printable PDF page width for Windows/driver printing.
  double get pdfPageWidthMm {
    switch (this) {
      case ThermalPaperSize.mm58:
        return 54;
      case ThermalPaperSize.mm80:
        return 76;
    }
  }

  /// On-page QR display size for PDF receipts.
  double get pdfQrDisplayMm {
    switch (this) {
      case ThermalPaperSize.mm58:
        return 24;
      case ThermalPaperSize.mm80:
        return 30;
    }
  }
}
