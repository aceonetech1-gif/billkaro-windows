import 'dart:io';
import 'dart:ui' as ui;

import 'package:billkaro/app/services/download/file_download_service.dart';
import 'package:billkaro/config/config.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Renders a table QR menu card as a high-resolution PNG and saves it.
class TableQrImage {
  TableQrImage._();

  static const double _width = 2000;
  static const double _padding = 160;
  static const double _qrSize = _width - 2 * _padding;

  /// Builds a 2000px wide PNG: business name, table name, QR and a hint.
  static Future<Uint8List> render({
    required String businessName,
    required String tableDisplayName,
    required String menuUrl,
  }) async {
    final title = _text(businessName, 96, Colors.black87, FontWeight.w600);
    final table = _text(tableDisplayName, 140, AppColor.primary, FontWeight.w800);
    final hint = _text('Scan to view menu', 72, Colors.black54, FontWeight.w500);

    final height = _padding +
        title.height +
        24 +
        table.height +
        80 +
        _qrSize +
        80 +
        hint.height +
        _padding;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _width, height),
      Paint()..color = Colors.white,
    );

    var y = _padding;
    y = _drawCentered(canvas, title, y) + 24;
    y = _drawCentered(canvas, table, y) + 80;

    canvas.save();
    canvas.translate(_padding, y);
    QrPainter(
      data: menuUrl,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      gapless: true,
    ).paint(canvas, const Size.square(_qrSize));
    canvas.restore();
    y += _qrSize + 80;

    _drawCentered(canvas, hint, y);

    final image = await recorder
        .endRecording()
        .toImage(_width.toInt(), height.ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  /// Renders the QR card and saves it to the downloads folder.
  static Future<File?> download({
    required String businessName,
    required String tableDisplayName,
    required String menuUrl,
  }) async {
    final bytes = await render(
      businessName: businessName,
      tableDisplayName: tableDisplayName,
      menuUrl: menuUrl,
    );
    return FileDownloadService.instance.saveBytes(
      bytes: bytes,
      fileName: 'QR Menu - $tableDisplayName.png',
      notificationTitle: 'QR code downloaded',
    );
  }

  static TextPainter _text(
    String text,
    double fontSize,
    Color color,
    FontWeight weight,
  ) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, color: color, fontWeight: weight),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _width - 2 * _padding);
  }

  /// Paints [painter] horizontally centered at [y]; returns the bottom edge.
  static double _drawCentered(Canvas canvas, TextPainter painter, double y) {
    painter.paint(canvas, Offset((_width - painter.width) / 2, y));
    return y + painter.height;
  }
}

/// Button that downloads a table's QR card as a high-resolution PNG.
class DownloadTableQrButton extends StatefulWidget {
  const DownloadTableQrButton({
    super.key,
    required this.businessName,
    required this.tableDisplayName,
    required this.menuUrl,
  });

  final String businessName;
  final String tableDisplayName;
  final String menuUrl;

  @override
  State<DownloadTableQrButton> createState() => _DownloadTableQrButtonState();
}

class _DownloadTableQrButtonState extends State<DownloadTableQrButton> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    String message;
    try {
      final file = await TableQrImage.download(
        businessName: widget.businessName,
        tableDisplayName: widget.tableDisplayName,
        menuUrl: widget.menuUrl,
      );
      message = file == null
          ? 'Could not download QR code'
          : 'QR code saved to ${file.path}';
    } catch (_) {
      message = 'Could not download QR code';
    }
    if (!mounted) return;
    setState(() => _downloading = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _downloading ? null : _download,
        icon: _downloading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_outlined),
        label: const Text('Download QR (HD)'),
      ),
    );
  }
}
