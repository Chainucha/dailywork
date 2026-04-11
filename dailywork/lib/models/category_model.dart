class CategoryModel {
  final String id;
  final String name;
  final String iconName; // maps to a Material icon name

  const CategoryModel({
    required this.id,
    required this.name,
    required this.iconName,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
    id: json['id'] as String,
    name: json['name'] as String,
    iconName: json['icon_name'] as String,
  );
}
