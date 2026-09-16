class CartLineDisplay {
  const CartLineDisplay({
    required this.lineKey,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.gst = 0,
    this.withTax = false,
    this.remark = '',
    this.imageUrl = '',
    this.isPromo = false,
    this.offerName,
    this.offerDetail,
    this.pendingKot = 0,
    this.comboIncludes,
  });

  final String lineKey;
  final String name;
  final double unitPrice;
  final int quantity;
  /// Item GST rate percent (e.g. 5 for 5%).
  final double gst;
  final bool withTax;
  final String remark;
  final String imageUrl;
  final bool isPromo;
  final String? offerName;
  final String? offerDetail;
  final int pendingKot;
  final String? comboIncludes;

  double get lineTotal => unitPrice * quantity;

  bool get hasGst => !isPromo && withTax && gst > 0;

  /// Tax amount for this line: price × qty × gst%.
  double get gstAmount => hasGst ? lineTotal * gst / 100.0 : 0.0;

  /// Line amount including GST.
  double get lineTotalWithGst => lineTotal + gstAmount;

  String get gstLabel {
    if (!hasGst) return '';
    final rate = gst == gst.roundToDouble()
        ? '${gst.toInt()}%'
        : '${gst.toStringAsFixed(1)}%';
    return 'GST $rate · ₹${gstAmount.toStringAsFixed(2)}';
  }

  bool get hasOfferInfo =>
      isPromo && ((offerName?.isNotEmpty ?? false) || (offerDetail?.isNotEmpty ?? false));
}
