class HabitModel {
  final String id;
  final String name;
  final String frequency; // "daily", "weekly"
  final int streak;
  final DateTime? lastCompleted;
  final int points;
  final bool isSynced;
  final DateTime createdAt;

  HabitModel({
    required this.id,
    required this.name,
    this.frequency = 'daily',
    this.streak = 0,
    this.lastCompleted,
    this.points = 0,
    this.isSynced = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to SQLite Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'frequency': frequency,
      'streak': streak,
      'last_completed': lastCompleted?.toIso8601String(),
      'points': points,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Create from SQLite Map
  factory HabitModel.fromMap(Map<String, dynamic> map) {
    return HabitModel(
      id: map['id'] as String,
      name: map['name'] as String,
      frequency: map['frequency'] as String? ?? 'daily',
      streak: map['streak'] as int? ?? 0,
      lastCompleted: map['last_completed'] != null
          ? DateTime.parse(map['last_completed'] as String)
          : null,
      points: map['points'] as int? ?? 0,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // Convert to C# JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'frequency': frequency,
      'streak': streak,
      'lastCompleted': lastCompleted?.toIso8601String(),
      'points': points,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from C# JSON
  factory HabitModel.fromJson(Map<String, dynamic> json) {
    return HabitModel(
      id: json['id'] as String,
      name: json['name'] as String,
      frequency: json['frequency'] as String? ?? 'daily',
      streak: json['streak'] as int? ?? 0,
      lastCompleted: json['lastCompleted'] != null
          ? DateTime.parse(json['lastCompleted'] as String)
          : null,
      points: json['points'] as int? ?? 0,
      isSynced: true, // Synced because it comes from server
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  HabitModel copyWith({
    String? id,
    String? name,
    String? frequency,
    int? streak,
    DateTime? lastCompleted,
    int? points,
    bool? isSynced,
    DateTime? createdAt,
  }) {
    return HabitModel(
      id: id ?? this.id,
      name: name ?? this.name,
      frequency: frequency ?? this.frequency,
      streak: streak ?? this.streak,
      lastCompleted: lastCompleted ?? this.lastCompleted,
      points: points ?? this.points,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
