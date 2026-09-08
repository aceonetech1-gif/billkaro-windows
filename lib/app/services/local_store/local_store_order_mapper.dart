import 'package:billkaro/app/services/Modals/orders/orders/orderResponse.dart';
import 'package:billkaro/app/services/Modals/orders/split_payment.dart';

/// Builds an [OrderModel] from a LAN create/update body (staff → host).
OrderModel orderModelFromLanBody(
  Map<String, dynamic> body, {
  required String id,
  required String outletId,
  required String localStatus,
  String? createdAtOverride,
}) {
  // Prefer full OrderModel-shaped payloads from staff tills.
  try {
    final merged = Map<String, dynamic>.from(body);
    merged['id'] = id;
    merged['outletId'] = merged['outletId']?.toString().isNotEmpty == true
        ? merged['outletId']
        : outletId;
    merged['status'] = localStatus;
    if (createdAtOverride != null && createdAtOverride.isNotEmpty) {
      merged['createdAt'] = createdAtOverride;
    }
    merged['updatedAt'] = DateTime.now().toIso8601String();
    if ((merged['createdAt']?.toString() ?? '').isEmpty) {
      merged['createdAt'] = merged['updatedAt'];
    }
    return OrderModel.fromJson(merged);
  } catch (_) {
    // Fall through to manual mapping.
  }

  final rawItems = body['items'];
  final items = <OrderItem>[];
  if (rawItems is List) {
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      items.add(
        OrderItem(
          itemId: map['itemId']?.toString() ?? '',
          itemName: map['itemName']?.toString() ?? '',
          category: map['category']?.toString() ?? '',
          quantity: int.tryParse(map['quantity']?.toString() ?? '') ?? 1,
          salePrice: double.tryParse(map['salePrice']?.toString() ?? '') ?? 0,
          gst: double.tryParse(map['gst']?.toString() ?? '') ?? 0,
          kotSentQuantity:
              int.tryParse(map['kotSentQuantity']?.toString() ?? '') ?? 0,
          itemRemark: map['itemRemark']?.toString(),
          variantId: map['variantId']?.toString(),
          variantName: map['variantName']?.toString(),
          variantSku: map['variantSku']?.toString(),
        ),
      );
    }
  }

  List<SplitPayment>? splits;
  final rawSplits = body['splitPayments'] ?? body['split_payments'];
  if (rawSplits is List) {
    splits = rawSplits
        .whereType<Map>()
        .map((e) => SplitPayment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  final now = DateTime.now().toIso8601String();
  return OrderModel(
    id: id,
    createdAt: createdAtOverride?.isNotEmpty == true ? createdAtOverride! : now,
    updatedAt: now,
    billNumber: body['billNumber']?.toString() ?? '',
    userId: body['userId']?.toString() ?? '',
    outletId: (body['outletId']?.toString().isNotEmpty == true)
        ? body['outletId'].toString()
        : outletId,
    tableNumber: body['tableNumber']?.toString(),
    customerName: body['customerName']?.toString(),
    phoneNumber: body['phoneNumber']?.toString(),
    subtotal: double.tryParse(body['subtotal']?.toString() ?? '') ?? 0,
    totalTax: double.tryParse(body['totalTax']?.toString() ?? '') ?? 0,
    discount: double.tryParse(body['discount']?.toString() ?? '') ?? 0,
    discountType: body['discountType']?.toString(),
    discountValue: double.tryParse(body['discountValue']?.toString() ?? ''),
    serviceCharge:
        double.tryParse(body['serviceCharge']?.toString() ?? '') ?? 0,
    totalAmount: double.tryParse(body['totalAmount']?.toString() ?? '') ?? 0,
    paymentReceivedIn: body['paymentReceivedIn']?.toString(),
    splitPayments: splits,
    status: localStatus,
    orderFrom: body['orderFrom']?.toString() ?? '',
    items: items,
    specialInstructions: body['specialInstructions']?.toString(),
  );
}
