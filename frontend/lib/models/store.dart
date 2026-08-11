class Store {
  final String id;
  final String name;
  final String? logoUrl;
  final Map<String, dynamic>? departmentOrder;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Store({
    required this.id,
    required this.name,
    this.logoUrl,
    this.departmentOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logo_url'] as String?,
      departmentOrder: json['department_order'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'logo_url': logoUrl,
        'department_order': departmentOrder,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}

class StoreDepartment {
  final String id;
  final String storeId;
  final String name;
  final int sortOrder;

  StoreDepartment({
    required this.id,
    required this.storeId,
    required this.name,
    required this.sortOrder,
  });

  factory StoreDepartment.fromJson(Map<String, dynamic> json) {
    return StoreDepartment(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}
