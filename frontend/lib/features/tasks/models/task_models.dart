class TaskCategory {
  final String key;
  final String label;
  final List<String> subCategories;

  const TaskCategory({required this.key, required this.label, required this.subCategories});

  factory TaskCategory.fromEntry(MapEntry<String, dynamic> entry) {
    final map = entry.value as Map<String, dynamic>;
    return TaskCategory(
      key: entry.key,
      label: map['label'] as String? ?? entry.key,
      subCategories: (map['subCategories'] as List?)?.cast<String>() ?? [],
    );
  }
}

class TaskAssignee {
  final String id;
  final String userId;
  final String userName;
  final String? userRole;
  final String? userPhone;

  const TaskAssignee({
    required this.id,
    required this.userId,
    required this.userName,
    this.userRole,
    this.userPhone,
  });

  factory TaskAssignee.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    return TaskAssignee(
      id: json['id'] ?? '',
      userId: user['id'] ?? json['userId'] ?? '',
      userName: user['name'] ?? '',
      userRole: user['role'] as String?,
      userPhone: user['phone'] as String?,
    );
  }
}

class TaskAttachment {
  final String id;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String fileUrl;

  const TaskAttachment({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.fileUrl,
  });

  factory TaskAttachment.fromJson(Map<String, dynamic> json) {
    return TaskAttachment(
      id: json['id'] ?? '',
      fileName: json['fileName'] ?? '',
      fileType: json['fileType'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      fileUrl: json['fileUrl'] ?? '',
    );
  }
}

class TaskComment {
  final String id;
  final String userId;
  final String userName;
  final String body;
  final DateTime createdAt;

  const TaskComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.body,
    required this.createdAt,
  });

  factory TaskComment.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    return TaskComment(
      id: json['id'] ?? '',
      userId: user['id'] ?? json['userId'] ?? '',
      userName: user['name'] ?? '',
      body: json['body'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class TaskModel {
  final String id;
  final String societyId;
  final String createdById;
  final String? creatorName;
  final String? creatorRole;
  final String title;
  final String? description;
  final String category;
  final String? subCategory;
  final String priority;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? completedAt;
  final String? statusNote;
  final DateTime createdAt;
  final List<TaskAssignee> assignees;
  final List<TaskAttachment> attachments;
  final List<TaskComment> comments;
  final int commentCount;

  const TaskModel({
    required this.id,
    required this.societyId,
    required this.createdById,
    this.creatorName,
    this.creatorRole,
    required this.title,
    this.description,
    required this.category,
    this.subCategory,
    required this.priority,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.completedAt,
    this.statusNote,
    required this.createdAt,
    this.assignees = const [],
    this.attachments = const [],
    this.comments = const [],
    this.commentCount = 0,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>?;
    final count = json['_count'] as Map<String, dynamic>?;
    return TaskModel(
      id: json['id'] ?? '',
      societyId: json['societyId'] ?? '',
      createdById: json['createdById'] ?? '',
      creatorName: creator?['name'] as String?,
      creatorRole: creator?['role'] as String?,
      title: json['title'] ?? '',
      description: json['description'] as String?,
      category: json['category'] ?? 'OTHER',
      subCategory: json['subCategory'] as String?,
      priority: json['priority'] ?? 'MEDIUM',
      status: json['status'] ?? 'OPEN',
      startDate: DateTime.tryParse(json['startDate'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate'] ?? '') ?? DateTime.now(),
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt']) : null,
      statusNote: json['statusNote'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      assignees: (json['assignees'] as List?)?.map((e) => TaskAssignee.fromJson(e)).toList() ?? [],
      attachments: (json['attachments'] as List?)?.map((e) => TaskAttachment.fromJson(e)).toList() ?? [],
      comments: (json['comments'] as List?)?.map((e) => TaskComment.fromJson(e)).toList() ?? [],
      commentCount: count?['comments'] as int? ?? (json['comments'] as List?)?.length ?? 0,
    );
  }

  bool get isOverdue =>
      status != 'COMPLETED' && status != 'CANCELLED' && endDate.isBefore(DateTime.now());
}
