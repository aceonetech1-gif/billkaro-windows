import 'dart:io';
import 'dart:isolate';

import 'package:billkaro/app/services/Modals/inventory/inventory_models.dart';
import 'package:billkaro/app/services/download/download_notification_service.dart';
import 'package:billkaro/app/services/download/file_download_service.dart';
import 'package:billkaro/config/config.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column;

class InventoryStockExportService {
  static const _excelNotificationId =
      DownloadNotificationService.inventoryStockExcelDownloadNotificationId;
  static const _pdfNotificationId =
      DownloadNotificationService.inventoryStockPdfDownloadNotificationId;

  static Future<void> exportExcel({
    required List<RawMaterialData> materials,
    required String Function(String? supplierId) supplierName,
    required String filterSummary,
    String? outletName,
    required double totalValue,
  }) async {
    try {
      if (materials.isEmpty) {
        showError(description: 'No stock data to export');
        return;
      }

      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt < 33) {
          await Permission.storage.request();
        }
      }

      await DownloadNotificationService.instance.notifyProgress(
        notificationId: _excelNotificationId,
        title: 'Excel downloading',
        body: 'Preparing inventory stock report…',
      );

      final payload = _buildPayload(
        materials: materials,
        supplierName: supplierName,
        filterSummary: filterSummary,
        outletName: outletName,
        totalValue: totalValue,
      );

      final bytes = await Isolate.run(() => _buildExcelBytes(payload));

      final fileName =
          'inventory-stock-${DateFormat('yyyy-MM-dd-HHmmss').format(DateTime.now())}.xlsx';
      final file = await FileDownloadService.instance.saveBytes(
        bytes: bytes,
        fileName: fileName,
        notificationId: _excelNotificationId,
        notificationTitle: 'Inventory stock downloaded',
      );

      if (file == null) {
        await DownloadNotificationService.instance.notifyFailed(
          notificationId: _excelNotificationId,
          title: 'Download failed',
          body: 'Failed to export inventory stock',
        );
        showError(description: 'Failed to export inventory stock');
      }
    } catch (e) {
      await DownloadNotificationService.instance.notifyFailed(
        notificationId: _excelNotificationId,
        title: 'Download failed',
        body: 'Failed to export Excel',
      );
      showError(description: 'Failed to export inventory stock: $e');
      debugPrint('❌ Inventory stock Excel export error: $e');
    }
  }

  static Future<void> exportPdf({
    required List<RawMaterialData> materials,
    required String Function(String? supplierId) supplierName,
    required String filterSummary,
    String? outletName,
    required double totalValue,
  }) async {
    try {
      if (materials.isEmpty) {
        showError(description: 'No stock data to export');
        return;
      }

      await DownloadNotificationService.instance.notifyProgress(
        notificationId: _pdfNotificationId,
        title: 'PDF downloading',
        body: 'Preparing inventory stock report…',
      );

      final payload = _buildPayload(
        materials: materials,
        supplierName: supplierName,
        filterSummary: filterSummary,
        outletName: outletName,
        totalValue: totalValue,
      );

      final bytes = await Isolate.run(() => _buildPdfBytes(payload));

      final fileName =
          'inventory-stock-${DateFormat('yyyy-MM-dd-HHmmss').format(DateTime.now())}.pdf';
      final file = await FileDownloadService.instance.saveBytes(
        bytes: bytes,
        fileName: fileName,
        notificationId: _pdfNotificationId,
        notificationTitle: 'Inventory stock downloaded',
      );

      if (file == null) {
        await DownloadNotificationService.instance.notifyFailed(
          notificationId: _pdfNotificationId,
          title: 'Download failed',
          body: 'Failed to export inventory stock',
        );
        showError(description: 'Failed to export inventory stock');
      }
    } catch (e) {
      await DownloadNotificationService.instance.notifyFailed(
        notificationId: _pdfNotificationId,
        title: 'Download failed',
        body: 'Failed to export PDF',
      );
      showError(description: 'Failed to export inventory stock: $e');
      debugPrint('❌ Inventory stock PDF export error: $e');
    }
  }

  static Map<String, dynamic> _buildPayload({
    required List<RawMaterialData> materials,
    required String Function(String? supplierId) supplierName,
    required String filterSummary,
    String? outletName,
    required double totalValue,
  }) {
    final title = outletName?.trim().isNotEmpty == true
        ? 'Inventory Stock — ${outletName!.trim()}'
        : 'Inventory Stock';

    return {
      'title': title,
      'exportedAt': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
      'filterSummary': filterSummary,
      'totalValue': totalValue,
      'rows': materials
          .map(
            (m) => <String, dynamic>{
              'name': m.name,
              'category': m.category,
              'supplier': supplierName(m.supplierId),
              'sku': m.materialCode,
              'barcode': m.barcode,
              'qty': m.currentStock,
              'unit': m.unit,
              'rate': m.purchasePrice,
              'amount': m.amount,
              'tax': m.taxRate,
              'total': m.total,
              'status': m.status,
            },
          )
          .toList(),
    };
  }

  static Uint8List _buildExcelBytes(Map<String, dynamic> payload) {
    final rows = (payload['rows'] as List).cast<Map<String, dynamic>>();
    final workbook = Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'Inventory Stock';

    final headerStyle = workbook.styles.add('header');
    headerStyle
      ..bold = true
      ..backColor = '#4472C4'
      ..fontColor = '#FFFFFF'
      ..hAlign = HAlignType.center;

    sheet.getRangeByName('A1:L1').merge();
    sheet.getRangeByName('A1').setText(payload['title'] as String);
    sheet.getRangeByName('A1').cellStyle
      ..bold = true
      ..fontSize = 16
      ..hAlign = HAlignType.center;

    sheet.getRangeByName('A2:L2').merge();
    sheet.getRangeByName('A2').setText(
      'Exported: ${payload['exportedAt']} | Filters: ${payload['filterSummary']}',
    );
    sheet.getRangeByName('A2').cellStyle.italic = true;

    const headers = [
      'Material',
      'Category',
      'Supplier',
      'SKU',
      'Barcode',
      'Quantity',
      'UOM',
      'Rate (Rs)',
      'Amount (Rs)',
      'Tax (%)',
      'Total (Rs)',
      'Status',
    ];

    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(4, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle = headerStyle;
    }

    var rowIndex = 5;
    for (final m in rows) {
      sheet.getRangeByIndex(rowIndex, 1).setText('${m['name'] ?? ''}');
      sheet.getRangeByIndex(rowIndex, 2).setText('${m['category'] ?? ''}');
      sheet.getRangeByIndex(rowIndex, 3).setText('${m['supplier'] ?? ''}');
      sheet.getRangeByIndex(rowIndex, 4).setText('${m['sku'] ?? ''}');
      sheet.getRangeByIndex(rowIndex, 5).setText('${m['barcode'] ?? ''}');
      sheet.getRangeByIndex(rowIndex, 6).setNumber((m['qty'] as num).toDouble());
      sheet.getRangeByIndex(rowIndex, 7).setText('${m['unit'] ?? ''}');
      sheet.getRangeByIndex(rowIndex, 8).setNumber((m['rate'] as num).toDouble());
      sheet
          .getRangeByIndex(rowIndex, 9)
          .setNumber((m['amount'] as num).toDouble());
      sheet.getRangeByIndex(rowIndex, 10).setNumber((m['tax'] as num).toDouble());
      sheet
          .getRangeByIndex(rowIndex, 11)
          .setNumber((m['total'] as num).toDouble());
      sheet.getRangeByIndex(rowIndex, 12).setText('${m['status'] ?? ''}');
      sheet.getRangeByIndex(rowIndex, 8).numberFormat = '"Rs" #,##0.00';
      sheet.getRangeByIndex(rowIndex, 9).numberFormat = '"Rs" #,##0.00';
      sheet.getRangeByIndex(rowIndex, 11).numberFormat = '"Rs" #,##0.00';
      if ((rowIndex - 5).isOdd) {
        sheet.getRangeByIndex(rowIndex, 1, rowIndex, 12).cellStyle.backColor =
            '#F2F2F2';
      }
      rowIndex++;
    }

    final summaryRow = rowIndex + 1;
    sheet.getRangeByIndex(summaryRow, 1).setText('Total materials:');
    sheet.getRangeByIndex(summaryRow, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(summaryRow, 2).setNumber(rows.length.toDouble());
    sheet.getRangeByIndex(summaryRow, 2).cellStyle.bold = true;
    sheet.getRangeByIndex(summaryRow, 10).setText('Stock value:');
    sheet.getRangeByIndex(summaryRow, 10).cellStyle.bold = true;
    sheet
        .getRangeByIndex(summaryRow, 11)
        .setNumber((payload['totalValue'] as num).toDouble());
    sheet.getRangeByIndex(summaryRow, 11).numberFormat = '"Rs" #,##0.00';
    sheet.getRangeByIndex(summaryRow, 11).cellStyle
      ..bold = true
      ..backColor = '#FFEB9C';

    for (var i = 1; i <= 12; i++) {
      sheet.autoFitColumn(i);
    }

    final bytes = workbook.saveAsStream();
    workbook.dispose();
    return Uint8List.fromList(bytes);
  }

  static Future<Uint8List> _buildPdfBytes(Map<String, dynamic> payload) async {
    final rows = (payload['rows'] as List).cast<Map<String, dynamic>>();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        maxPages: 200,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (context.pageNumber == 1) ...[
              pw.Center(
                child: pw.Text(
                  payload['title'] as String,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Exported: ${payload['exportedAt']}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                'Filters: ${payload['filterSummary']}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 8),
            ],
            _pdfHeaderRow(),
            pw.SizedBox(height: 4),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          ...rows.map(_pdfDataRow),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total materials: ${rows.length}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              pw.Text(
                'Stock value: Rs ${_fmt((payload['totalValue'] as num).toDouble())}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  static pw.Widget _pdfHeaderRow() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      color: PdfColors.grey300,
      child: pw.Row(
        children: [
          pw.Expanded(flex: 3, child: pw.Text('Material', style: _hStyle)),
          pw.Expanded(flex: 2, child: pw.Text('Category', style: _hStyle)),
          pw.Expanded(flex: 2, child: pw.Text('Supplier', style: _hStyle)),
          pw.Expanded(flex: 2, child: pw.Text('SKU', style: _hStyle)),
          pw.Expanded(child: pw.Text('Qty', style: _hStyle)),
          pw.Expanded(child: pw.Text('UOM', style: _hStyle)),
          pw.Expanded(child: pw.Text('Rate', style: _hStyle)),
          pw.Expanded(child: pw.Text('Amount', style: _hStyle)),
          pw.Expanded(child: pw.Text('Tax', style: _hStyle)),
          pw.Expanded(child: pw.Text('Total', style: _hStyle)),
          pw.Expanded(flex: 2, child: pw.Text('Status', style: _hStyle)),
        ],
      ),
    );
  }

  static pw.Widget _pdfDataRow(Map<String, dynamic> m) {
    final tax = (m['tax'] as num).toDouble();
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text('${m['name'] ?? ''}', style: _cStyle),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(_dash(m['category']), style: _cStyle),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(_dash(m['supplier']), style: _cStyle),
          ),
          pw.Expanded(flex: 2, child: pw.Text(_dash(m['sku']), style: _cStyle)),
          pw.Expanded(
            child: pw.Text(
              _qtyLabel((m['qty'] as num).toDouble()),
              style: _cStyle,
            ),
          ),
          pw.Expanded(child: pw.Text('${m['unit'] ?? ''}', style: _cStyle)),
          pw.Expanded(
            child: pw.Text(
              'Rs ${_fmt((m['rate'] as num).toDouble())}',
              style: _cStyle,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              'Rs ${_fmt((m['amount'] as num).toDouble())}',
              style: _cStyle,
            ),
          ),
          pw.Expanded(
            child: pw.Text(tax > 0 ? '${_fmt(tax)}%' : '--', style: _cStyle),
          ),
          pw.Expanded(
            child: pw.Text(
              'Rs ${_fmt((m['total'] as num).toDouble())}',
              style: _cStyle,
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text('${m['status'] ?? ''}', style: _cStyle),
          ),
        ],
      ),
    );
  }

  static final _hStyle = pw.TextStyle(
    fontSize: 8,
    fontWeight: pw.FontWeight.bold,
  );
  static const _cStyle = pw.TextStyle(fontSize: 7.5);

  static String _dash(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty ? '--' : text;
  }

  static String _qtyLabel(double qty) {
    return qty == qty.roundToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
  }

  static String _fmt(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }
}
