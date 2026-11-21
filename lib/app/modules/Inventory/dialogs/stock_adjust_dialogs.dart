part of 'inventory_dialogs.dart';

/// Sets stock to the counted quantity by posting the difference as an
/// ADJUSTMENT_IN / ADJUSTMENT_OUT transaction (physical stock audit).
Future<void> _applyPhysicalCount(
  InventoryController c,
  RawMaterialData material,
  double? counted,
  String note, {
  required void Function(bool) setSubmitting,
}) async {
  if (counted == null || counted < 0) {
    showError(description: 'Enter the counted quantity (0 or more)');
    return;
  }
  // Use the latest loaded stock; the dialog's snapshot may be stale.
  final live =
      c.rawMaterials.firstWhereOrNull((m) => m.id == material.id) ?? material;
  final diff = counted - live.currentStock;
  if (diff.abs() < 1e-9) {
    Get.back();
    showSuccess(description: 'Stock already matches the count');
    return;
  }
  setSubmitting(true);
  final ok = await c.adjustStock(
    rawMaterialId: material.id,
    type: diff > 0 ? 'ADJUSTMENT_IN' : 'ADJUSTMENT_OUT',
    quantity: diff.abs(),
    notes:
        'Physical count: ${live.currentStock} → $counted ${material.unit}'
        '${note.isEmpty ? '' : ' | $note'}',
  );
  setSubmitting(false);
  if (!ok) return;
  Get.back();
  showSuccess(description: 'Stock set to $counted ${material.unit}');
}

Future<void> showStockAdjustDialog(
  InventoryController c,
  RawMaterialData material,
) async {
  final loc = AppLocalizations.of(Get.context!)!;
  final qtyCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  var type = 'ADJUSTMENT_IN';
  var submitting = false;

  await Get.dialog(
    AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(loc.adjust_stock_title(material.name)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc.current_stock_label(
                '${material.currentStock}',
                material.unit,
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            AppDropdownFormField2<String>(
              value: type,
              decoration: InputDecoration(
                labelText: loc.transaction_type,
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownItem(value: 'ADJUSTMENT_IN', child: Text(loc.stock_in)),
                DropdownItem(
                  value: 'ADJUSTMENT_OUT',
                  child: Text(loc.stock_out),
                ),
                DropdownItem(value: 'WASTAGE', child: Text(loc.wastage)),
                // Physical count: enter what is on the shelf; the difference
                // is posted as an adjustment (closing-stock audit).
                const DropdownItem(
                  value: 'PHYSICAL_COUNT',
                  child: Text('Physical count (set exact stock)'),
                ),
                DropdownItem(
                  value: 'RETURN',
                  child: Text(loc.return_to_supplier),
                ),
              ],
              onChanged: (v) => type = v ?? 'ADJUSTMENT_IN',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: loc.quantity_with_unit_label(material.unit),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: InputDecoration(
                labelText: loc.notes_label,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: Text(loc.cancel)),
        ElevatedButton(
          onPressed: () async {
            if (!StaffAccess.ensure(StaffAccess.canAdjustStock)) return;
            if (submitting) return;
            final qty = double.tryParse(
              qtyCtrl.text.trim().replaceAll(',', '.'),
            );
            if (type == 'PHYSICAL_COUNT') {
              await _applyPhysicalCount(
                c,
                material,
                qty,
                notesCtrl.text.trim(),
                setSubmitting: (v) => submitting = v,
              );
              return;
            }
            if (qty == null || qty <= 0) {
              showError(description: 'Enter a valid quantity greater than 0');
              return;
            }
            if (type != 'ADJUSTMENT_IN' &&
                qty > material.currentStock + 1e-9) {
              showError(
                description:
                    'Cannot remove more than the current stock '
                    '(${material.currentStock} ${material.unit})',
              );
              return;
            }
            submitting = true;
            final ok = await c.adjustStock(
              rawMaterialId: material.id,
              type: type,
              quantity: qty,
              notes: notesCtrl.text.trim(),
            );
            submitting = false;
            if (!ok) return;
            Get.back();
            showSuccess(description: 'Stock updated');
          },
          child: Text(loc.update_stock),
        ),
      ],
    ),
  );
  // Delay dispose until after the dialog's pop animation.
  Future.delayed(const Duration(milliseconds: 300), () {
    qtyCtrl.dispose();
    notesCtrl.dispose();
  });
}
