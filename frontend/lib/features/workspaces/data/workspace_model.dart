class WorkspaceModel {
  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;

  WorkspaceModel({
    required this.id,
    required this.name,
    required this.ownerId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to SQLite Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'owner_id': ownerId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Create from SQLite Map
  factory WorkspaceModel.fromMap(Map<String, dynamic> map) {
    return WorkspaceModel(
      id: map['id'] as String,
      name: map['name'] as String,
      ownerId: map['owner_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // Convert to C# JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ownerId': ownerId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from C# JSON
  factory WorkspaceModel.fromJson(Map<String, dynamic> json) {
    return WorkspaceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  WorkspaceModel copyWith({
    String? id,
    String? name,
    String? ownerId,
    DateTime? createdAt,
  }) {
    return WorkspaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
