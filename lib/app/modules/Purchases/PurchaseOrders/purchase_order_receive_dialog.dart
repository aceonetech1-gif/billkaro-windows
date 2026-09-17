import 'package:billkaro/app/modules/Purchases/PurchaseOrders/purchase_order_controller.dart';
import 'package:billkaro/app/services/Modals/inventory/inventory_models.dart';
import 'package:billkaro/config/config.dart';

/// Dialog to receive full or partial quantities against a purchase order.
Future<void> showReceivePurchaseOrderDialog(
  PurchaseOrderController controller,
  PurchaseOrderData po,
) async {
  final pendingLines = po.items
      .where((line) => line.quantity - line.receivedQuantity > 1e-9)
      .toList();
  if (pendingLines.isEmpty) {
    showError(description: 'Nothing left to receive on this purchase order');
    return;
  }

  final loc = AppLocalizations.of(Get.context!)!;
  final qtyCtrls = <String, TextEditingController>{
    for (final line in pendingLines)
      line.id: TextEditingController(
        text: _fmtQty(line.quantity - line.receivedQuantity),
      ),
  };

  try {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('Receive ${po.orderNumber}'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final line in pendingLines) ...[
                  _ReceiveLineRow(
                    name: line.rawMaterialName.isNotEmpty
                        ? line.rawMaterialName
                        : line.description,
                    unit: line.unit,
                    ordered: line.quantity,
                    alreadyReceived: line.receivedQuantity,
                    pending: line.quantity - line.receivedQuantity,
                    qtyCtrl: qtyCtrls[line.id]!,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              for (final line in pendingLines) {
                final pending = line.quantity - line.receivedQuantity;
                final qty = double.tryParse(qtyCtrls[line.id]!.text.trim());
                if (qty == null || qty < 0) {
                  showError(description: 'Enter a valid receive quantity');
                  return;
                }
                if (qty > pending + 1e-9) {
                  showError(
                    description: 'Cannot receive more than pending quantity',
                  );
                  return;
                }
              }
              Get.back(result: true);
            },
            child: Text(loc.mark_received),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    if (confirmed != true) return;

    final items = <Map<String, dynamic>>[];
    for (final line in pendingLines) {
      final qty = double.tryParse(qtyCtrls[line.id]!.text.trim()) ?? 0;
      if (qty > 0) {
        items.add({
          'purchaseOrderItemId': line.id,
          'quantity': qty,
        });
      }
    }
    if (items.isEmpty) {
      showError(description: 'Enter at least one quantity to receive');
      return;
    }

    final ok = await controller.receivePurchaseOrder(po.id, items: items);
    if (ok) {
      showSuccess(description: 'Stock updated');
    }
  } finally {
    for (final c in qtyCtrls.values) {
      c.dispose();
    }
  }
}

String _fmtQty(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

class _ReceiveLineRow extends StatelessWidget {
  const _ReceiveLineRow({
    required this.name,
    required this.unit,
    required this.ordered,
    required this.alreadyReceived,
    required this.pending,
    required this.qtyCtrl,
  });

  final String name;
  final String unit;
  final double ordered;
  final double alreadyReceived;
  final double pending;
  final TextEditingController qtyCtrl;

  @override
  Widget build(BuildContext context) {
    final unitLabel = unit.trim().isEmpty ? '' : ' $unit';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            'Ordered: ${_fmtQty(ordered)}$unitLabel'
            '  ·  Received: ${_fmtQty(alreadyReceived)}$unitLabel'
            '  ·  Pending: ${_fmtQty(pending)}$unitLabel',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Receive now',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
