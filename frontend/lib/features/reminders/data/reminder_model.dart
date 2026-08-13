import 'dart:convert';

class ReminderModel {
  final String id;
  final String title;
  final String? description;
  final String category;
  final DateTime dueDate;
  final String status; // "pending", "completed"
  final bool isSynced;
  final DateTime createdAt;

  // Geo-Location
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final double? radiusInMeters;

  // Workspace
  final String? workspaceId;

  // Advanced Productivity fields
  final String priority; // 'alta', 'media', 'baja'
  final List<String> subtasks;
  final double? estimatedCost;
  final bool isAlarm;

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
    this.workspaceId,
    this.priority = 'media',
    this.subtasks = const [],
    this.estimatedCost,
    this.isAlarm = false,
  }) : createdAt = createdAt ?? DateTime.now();

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
      'workspace_id': workspaceId,
      'priority': priority,
      'subtasks': jsonEncode(subtasks),
      'estimated_cost': estimatedCost,
      'is_alarm': isAlarm ? 1 : 0,
    };
  }

  factory ReminderModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedSubtasks = [];
    if (map['subtasks'] != null && (map['subtasks'] as String).isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(map['subtasks'] as String);
        parsedSubtasks = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }

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
      workspaceId: map['workspace_id'] as String?,
      priority: map['priority'] as String? ?? 'media',
      subtasks: parsedSubtasks,
      estimatedCost: map['estimated_cost'] as double?,
      isAlarm: (map['is_alarm'] as int? ?? 0) == 1,
    );
  }

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
      'workspaceId': workspaceId,
      'priority': priority,
      'subtasks': subtasks,
      'estimatedCost': estimatedCost,
      'isAlarm': isAlarm,
    };
  }

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedSubtasks = [];
    if (json['subtasks'] != null) {
      if (json['subtasks'] is List) {
        parsedSubtasks = (json['subtasks'] as List).map((e) => e.toString()).toList();
      }
    }

    return ReminderModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'General',
      dueDate: DateTime.parse(json['dueDate'] as String),
      status: json['status'] as String? ?? 'pending',
      isSynced: true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      locationName: json['locationName'] as String?,
      radiusInMeters: json['radiusInMeters'] != null ? (json['radiusInMeters'] as num).toDouble() : null,
      workspaceId: json['workspaceId'] as String?,
      priority: json['priority'] as String? ?? 'media',
      subtasks: parsedSubtasks,
      estimatedCost: json['estimatedCost'] != null ? (json['estimatedCost'] as num).toDouble() : null,
      isAlarm: json['isAlarm'] as bool? ?? false,
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
    String? workspaceId,
    String? priority,
    List<String>? subtasks,
    double? estimatedCost,
    bool? isAlarm,
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
      workspaceId: workspaceId ?? this.workspaceId,
      priority: priority ?? this.priority,
      subtasks: subtasks ?? this.subtasks,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      isAlarm: isAlarm ?? this.isAlarm,
    );
  }
}
