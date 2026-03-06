/// Breadcrumb types for categorizing user actions
enum BreadcrumbType { navigation, user, http, state, error, info, system }

/// Individual breadcrumb representing a user action or event
class Breadcrumb {
  final String message;
  final BreadcrumbType type;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  const Breadcrumb({
    required this.message,
    required this.type,
    required this.timestamp,
    this.data,
  });

  Map<String, dynamic> toJson() => {
    'message': message,
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
    if (data != null) 'data': data,
  };

  factory Breadcrumb.fromJson(Map<String, dynamic> json) {
    return Breadcrumb(
      message: json['message'] as String,
      type: BreadcrumbType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => BreadcrumbType.info,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() => '[$type] $message';
}
