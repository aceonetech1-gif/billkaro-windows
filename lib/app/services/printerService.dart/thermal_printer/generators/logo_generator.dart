import 'package:billkaro/app/services/Network/urls.dart';
import 'package:billkaro/app/services/printerService.dart/thermal_printer/helpers/thermal_paper_size.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// Business logo for the top of printed bills.
///
/// Downloads the outlet logo once (cached in memory), then converts it to a
/// centered, dithered GS v 0 raster for thermal printers or a PNG for PDF.
/// Every failure returns empty/null so a missing logo never blocks printing.
class LogoGenerator {
  static const Duration _downloadTimeout = Duration(seconds: 6);

  static final Map<String, Uint8List> _downloadCache = {};
  static final Map<String, List<int>> _rasterCache = {};
  static final Map<String, Uint8List> _pngCache = {};

  /// Downloads (or returns cached) logo bytes for a stored logo path/URL.
  static Future<Uint8List?> fetchLogoBytes(String? storedLogo) async {
    final url = resolvedMediaUrl(storedLogo);
    if (url.isEmpty) return null;

    final cached = _downloadCache[url];
    if (cached != null) return cached;

    try {
      final res = await http.get(Uri.parse(url)).timeout(_downloadTimeout);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        debugPrint('Logo download failed (${res.statusCode}): $url');
        return null;
      }
      _downloadCache[url] = res.bodyBytes;
      return res.bodyBytes;
    } catch (e) {
      debugPrint('Logo download error: $e');
      return null;
    }
  }

  /// ESC/POS bytes (center + GS v 0 raster + newline) for the logo.
  static Future<List<int>> generateRaster(
    String? storedLogo, {
    ThermalPaperSize paperSize = ThermalPaperSize.mm58,
  }) async {
    final url = resolvedMediaUrl(storedLogo);
    if (url.isEmpty) return [];

    final cacheKey = '$url@${paperSize.storageKey}';
    final cached = _rasterCache[cacheKey];
    if (cached != null) return cached;

    final bytes = await fetchLogoBytes(storedLogo);
    if (bytes == null) return [];

    try {
      final raster = await compute(
        _buildRaster,
        (
          bytes: bytes,
          maxWidth: paperSize.logoMaxWidthDots,
          maxHeight: paperSize.logoMaxHeightDots,
        ),
      );
      if (raster.isNotEmpty) _rasterCache[cacheKey] = raster;
      return raster;
    } catch (e) {
      debugPrint('Logo raster error: $e');
      return [];
    }
  }

  /// PNG bytes (logo flattened on white) for PDF bill printing.
  static Future<Uint8List?> generatePng(String? storedLogo) async {
    final url = resolvedMediaUrl(storedLogo);
    if (url.isEmpty) return null;

    final cached = _pngCache[url];
    if (cached != null) return cached;

    final bytes = await fetchLogoBytes(storedLogo);
    if (bytes == null) return null;

    try {
      final png = await compute(_buildPng, bytes);
      if (png != null) _pngCache[url] = png;
      return png;
    } catch (e) {
      debugPrint('Logo PNG error: $e');
      return null;
    }
  }

  /// Decodes the logo onto white paper and crops its blank border, so padding
  /// inside the image file doesn't print as empty space.
  static img.Image? _decodeOnWhite(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width == 0 || decoded.height == 0) {
      return null;
    }
    final flat = img.Image(width: decoded.width, height: decoded.height);
    img.fill(flat, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(flat, decoded);
    return img.trim(flat, mode: img.TrimMode.topLeftColor);
  }

  static Uint8List? _buildPng(Uint8List bytes) {
    final logo = _decodeOnWhite(bytes);
    if (logo == null) return null;
    return Uint8List.fromList(img.encodePng(logo));
  }

  static List<int> _buildRaster(
    ({Uint8List bytes, int maxWidth, int maxHeight}) args,
  ) {
    final decoded = _decodeOnWhite(args.bytes);
    if (decoded == null) return [];

    // Fit (upscaling small logos) inside the box, keep aspect ratio, width
    // multiple of 8 for packing.
    final scale = [
      args.maxWidth / decoded.width,
      args.maxHeight / decoded.height,
    ].reduce((a, b) => a < b ? a : b);
    var width = (decoded.width * scale).round().clamp(8, args.maxWidth);
    width -= width % 8;
    final height = (decoded.height * width / decoded.width).round().clamp(
      1,
      args.maxHeight,
    );

    final resized = img.copyResize(
      decoded,
      width: width,
      height: height,
      interpolation: img.Interpolation.average,
    );

    // Grayscale (transparency was already flattened onto white).
    final gray = Float64List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = resized.getPixel(x, y);
        final max = p.maxChannelValue.toDouble();
        gray[y * width + x] =
            (0.299 * p.r + 0.587 * p.g + 0.114 * p.b) / max * 255;
      }
    }

    // Floyd–Steinberg dithering keeps gradients/colors readable in 1-bit.
    final widthBytes = width ~/ 8;
    final packed = Uint8List(widthBytes * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = y * width + x;
        final old = gray[i];
        final isBlack = old < 128;
        final err = old - (isBlack ? 0 : 255);
        if (isBlack) packed[y * widthBytes + (x >> 3)] |= 0x80 >> (x & 7);
        if (x + 1 < width) gray[i + 1] += err * 7 / 16;
        if (y + 1 < height) {
          if (x > 0) gray[i + width - 1] += err * 3 / 16;
          gray[i + width] += err * 5 / 16;
          if (x + 1 < width) gray[i + width + 1] += err * 1 / 16;
        }
      }
    }

    return [
      // Center alignment
      0x1B, 0x61, 0x01,
      // GS v 0 m=0 (normal density, 1:1 dots)
      0x1D, 0x76, 0x30, 0x00,
      widthBytes & 0xFF,
      (widthBytes >> 8) & 0xFF,
      height & 0xFF,
      (height >> 8) & 0xFF,
      ...packed,
      // No trailing LF: GS v 0 already advances past the image, and an extra
      // line feed prints a blank row under the logo.
    ];
  }
}
