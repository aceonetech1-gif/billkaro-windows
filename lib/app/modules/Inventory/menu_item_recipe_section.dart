import 'package:billkaro/app/Widgets/app_dropdowns.dart';
import 'package:billkaro/app/modules/Inventory/inventory_controller.dart';
import 'package:billkaro/app/services/Modals/inventory/inventory_models.dart';
import 'package:billkaro/config/config.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';

/// Links inventory stock (raw material) or an existing recipe to a menu item.
class MenuItemRecipeSection extends StatefulWidget {
  final String itemId;
  final String linkedRawMaterialId;
  final String linkedRecipeItemId;
  final ValueChanged<String> onLinkedRawMaterialChanged;
  final ValueChanged<String> onLinkedRecipeChanged;

  const MenuItemRecipeSection({
    super.key,
    required this.itemId,
    required this.linkedRawMaterialId,
    required this.linkedRecipeItemId,
    required this.onLinkedRawMaterialChanged,
    required this.onLinkedRecipeChanged,
  });

  @override
  State<MenuItemRecipeSection> createState() => _MenuItemRecipeSectionState();
}

class _MenuItemRecipeSectionState extends State<MenuItemRecipeSection> {
  late final InventoryController _inventory;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _inventory = Get.isRegistered<InventoryController>()
        ? Get.find<InventoryController>()
        : Get.put(InventoryController());
    _inventory.loadRecipeData();
    _expanded = _hasLink;
  }

  bool get _hasLink =>
      widget.linkedRawMaterialId.trim().isNotEmpty ||
      widget.linkedRecipeItemId.trim().isNotEmpty;

  @override
  void didUpdateWidget(covariant MenuItemRecipeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_hasLink && !_expanded) {
      setState(() => _expanded = true);
    }
  }

  void _collapse() {
    widget.onLinkedRawMaterialChanged('');
    widget.onLinkedRecipeChanged('');
    setState(() => _expanded = false);
  }

  String _stockLabel(RawMaterialData m) {
    final qty = m.currentStock == m.currentStock.roundToDouble()
        ? m.currentStock.toInt().toString()
        : m.currentStock.toString();
    final unit = m.unit.trim().isEmpty ? '' : ' ${m.unit}';
    return '$qty$unit';
  }

  List<({String itemId, String itemName, int ingredientCount})>
  _recipeOptions() {
    final byItem = <String, List<RecipeData>>{};
    for (final r in _inventory.recipes) {
      if (r.itemId.isEmpty) continue;
      if (widget.itemId.isNotEmpty && r.itemId == widget.itemId) continue;
      byItem.putIfAbsent(r.itemId, () => []).add(r);
    }

    final options = byItem.entries.map((e) {
      final name = e.value.first.itemName.trim().isNotEmpty
          ? e.value.first.itemName.trim()
          : _inventory.menuItemName(e.key);
      return (
        itemId: e.key,
        itemName: name.isNotEmpty ? name : e.key,
        ingredientCount: e.value.length,
      );
    }).toList();

    options.sort(
      (a, b) => a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase()),
    );
    return options;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (!_expanded) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => setState(() => _expanded = true),
          icon: Icon(Icons.link, color: AppColor.primary, size: 20),
          label: Text(
            'Link Inventory',
            style: TextStyle(
              color: AppColor.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColor.primary,
            side: BorderSide(color: AppColor.primary.withOpacity(0.55)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    return Obx(() {
      final _ = _inventory.recipes.length + _inventory.rawMaterials.length;
      final materials = _inventory.rawMaterials.toList()
        ..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      final recipeOptions = _recipeOptions();

      final materialId = widget.linkedRawMaterialId.trim();
      final selectedMaterial = materialId.isEmpty
          ? ''
          : (materials.any((m) => m.id == materialId) ? materialId : null);

      final recipeId = widget.linkedRecipeItemId.trim();
      final selectedRecipe = recipeId.isEmpty
          ? '__none__'
          : (recipeOptions.any((o) => o.itemId == recipeId)
                ? recipeId
                : null);
      final linkedLines = recipeId.isEmpty
          ? const <RecipeData>[]
          : _inventory.recipesForItem(recipeId);

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link, size: 18, color: AppColor.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Link Inventory',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _collapse,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    'Remove',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Inventory item',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'For finished goods (e.g. water bottle). Deducts 1 from stock on sale.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            if (materials.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  'No inventory items found. Add stock in Inventory first.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              )
            else
              AppDropdownFormField2<String>(
                isExpanded: true,
                value: selectedMaterial,
                decoration: const InputDecoration(
                  labelText: 'Select inventory item',
                  hintText: 'Choose from inventory',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownItem<String>(
                    value: '',
                    child: Text('None'),
                  ),
                  ...materials.map(
                    (m) => DropdownItem<String>(
                      value: m.id,
                      child: Text(
                        '${m.name} (${_stockLabel(m)})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  final id = (value ?? '').trim();
                  widget.onLinkedRawMaterialChanged(id);
                  if (id.isNotEmpty) {
                    widget.onLinkedRecipeChanged('');
                  }
                },
                iconStyleData: IconStyleData(
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColor.primary,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              loc.recipe_ingredients,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'For dishes (e.g. pizza). Reuse an existing recipe on sale.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            if (recipeOptions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  'No recipes found. Create one in Inventory → Recipes first.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              )
            else ...[
              AppDropdownFormField2<String>(
                isExpanded: true,
                value: selectedRecipe,
                decoration: const InputDecoration(
                  labelText: 'Link recipe from Inventory',
                  hintText: 'Select an existing recipe',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownItem<String>(
                    value: '__none__',
                    child: Text('None'),
                  ),
                  ...recipeOptions.map(
                    (o) => DropdownItem<String>(
                      value: o.itemId,
                      child: Text(
                        '${o.itemName} (${o.ingredientCount})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  final id = (value ?? '').trim();
                  final recipeItemId = id == '__none__' ? '' : id;
                  widget.onLinkedRecipeChanged(recipeItemId);
                  if (recipeItemId.isNotEmpty) {
                    widget.onLinkedRawMaterialChanged('');
                  }
                },
                iconStyleData: IconStyleData(
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColor.primary,
                  ),
                ),
              ),
              if (linkedLines.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...linkedLines.map(
                  (r) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.grain,
                          size: 18,
                          color: Color(0xFFEF8819),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            loc.recipe_uses_material(
                              r.quantity.toString(),
                              r.displayUnit,
                              r.rawMaterialName,
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      );
    });
  }
}
