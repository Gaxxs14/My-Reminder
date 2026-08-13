class ReminderModel {
  final String id;
  final String title;
  final String? description;
  final String category;
  final DateTime dueDate;
  final String status; // "pending", "completed"
  final bool isSynced;
  final DateTime createdAt;

  // Optional Location fields for Geo-Reminders
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final double? radiusInMeters;

  ReminderModel({
    required this.id,
    required this.title,
    this.description,
    this.category = 'General',
    required this.dueDate,
    this.status = 'pending',
    this.isSynced = false,
    DateTime? createdAt,
    this.latitude,
    this.longitude,
    this.locationName,
    this.radiusInMeters = 150.0,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to SQLite Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'due_date': dueDate.toIso8601String(),
      'status': status,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
      'radius_in_meters': radiusInMeters,
    };
  }

  // Create from SQLite Map
  factory ReminderModel.fromMap(Map<String, dynamic> map) {
    return ReminderModel(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      category: map['category'] as String? ?? 'General',
      dueDate: DateTime.parse(map['due_date'] as String),
      status: map['status'] as String? ?? 'pending',
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      locationName: map['location_name'] as String?,
      radiusInMeters: map['radius_in_meters'] as double?,
    );
  }

  // Convert to C# JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'dueDate': dueDate.toIso8601String(),
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'radiusInMeters': radiusInMeters,
    };
  }

  // Create from C# JSON
  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'General',
      dueDate: DateTime.parse(json['dueDate'] as String),
      status: json['status'] as String? ?? 'pending',
      isSynced: true, // If it comes from server, it is synced
      createdAt: DateTime.parse(json['createdAt'] as String),
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      locationName: json['locationName'] as String?,
      radiusInMeters: json['radiusInMeters'] != null ? (json['radiusInMeters'] as num).toDouble() : null,
    );
  }

  ReminderModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    DateTime? dueDate,
    String? status,
    bool? isSynced,
    DateTime? createdAt,
    double? latitude,
    double? longitude,
    String? locationName,
    double? radiusInMeters,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      radiusInMeters: radiusInMeters ?? this.radiusInMeters,
    );
  }
}
