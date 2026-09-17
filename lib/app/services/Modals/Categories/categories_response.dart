import 'package:json_annotation/json_annotation.dart';

part 'categories_response.g.dart';

@JsonSerializable()
class CategoryResponse {
  final String status;

  @JsonKey(name: 'data')
  final List<CategoryData> categories;

  CategoryResponse({required this.status, required this.categories});

  factory CategoryResponse.fromJson(Map<String, dynamic> json) =>
      _$CategoryResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CategoryResponseToJson(this);
}

@JsonSerializable()
class CategoryData {
  final String id; // UUID → String
  final String userId; // Added because API returns it
  final String outletId;
  final String categoryName;
  final String imageURL; // Optional field for category image URL
  @JsonKey(defaultValue: true)
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  CategoryData({
    required this.id,
    required this.userId,
    required this.outletId,
    required this.categoryName,
    required this.imageURL,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory CategoryData.fromJson(Map<String, dynamic> json) =>
      _$CategoryDataFromJson(json);

  Map<String, dynamic> toJson() => _$CategoryDataToJson(this);

  CategoryData copyWith({
    String? id,
    String? userId,
    String? outletId,
    String? categoryName,
    String? imageURL,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryData(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      outletId: outletId ?? this.outletId,
      categoryName: categoryName ?? this.categoryName,
      imageURL: imageURL ?? this.imageURL,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
