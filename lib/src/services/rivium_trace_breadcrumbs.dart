// lib/src/services/rivium_trace_breadcrumbs.dart
import '../models/breadcrumb.dart';

/// In-memory breadcrumb tracking service
/// Breadcrumbs are stored in memory only and are included with real-time error reports
class RiviumTraceBreadcrumbs {
  static final List<Breadcrumb> _breadcrumbs = [];
  static int _maxBreadcrumbs = 20;

  /// Set maximum number of breadcrumbs to keep
  static void setMaxBreadcrumbs(int max) {
    _maxBreadcrumbs = max;
    _trimBreadcrumbs();
  }

  /// Add a breadcrumb
  static void add(
    String message, {
    BreadcrumbType type = BreadcrumbType.info,
    Map<String, dynamic>? data,
  }) {
    final breadcrumb = Breadcrumb(
      message: message,
      type: type,
      timestamp: DateTime.now(),
      data: data,
    );

    _breadcrumbs.add(breadcrumb);
    _trimBreadcrumbs();
  }

  /// Add navigation breadcrumb
  static void addNavigation(String from, String to) {
    add(
      'Navigated from $from to $to',
      type: BreadcrumbType.navigation,
      data: {'from': from, 'to': to},
    );
  }

  /// Add user action breadcrumb
  static void addUser(String action, {Map<String, dynamic>? data}) {
    add('User $action', type: BreadcrumbType.user, data: data);
  }

  /// Add HTTP request breadcrumb
  static void addHttp(String method, String url, int? statusCode) {
    add(
      '$method $url ${statusCode != null ? '($statusCode)' : ''}',
      type: BreadcrumbType.http,
      data: {
        'method': method,
        'url': url,
        if (statusCode != null) 'status_code': statusCode,
      },
    );
  }

  /// Add state change breadcrumb
  static void addState(String change, {Map<String, dynamic>? data}) {
    add('State: $change', type: BreadcrumbType.state, data: data);
  }

  /// Add system breadcrumb (SDK lifecycle events)
  static void addSystem(String message, {Map<String, dynamic>? data}) {
    add(message, type: BreadcrumbType.system, data: data);
  }

  /// Add error breadcrumb
  static void addError(String message, {Map<String, dynamic>? data}) {
    add(message, type: BreadcrumbType.error, data: data);
  }

  /// Get all breadcrumbs
  static List<Breadcrumb> getBreadcrumbs() => List.unmodifiable(_breadcrumbs);

  /// Get breadcrumbs as JSON for error reporting
  static List<Map<String, dynamic>> getBreadcrumbsJson() =>
      _breadcrumbs.map((b) => b.toJson()).toList();

  /// Clear all breadcrumbs
  static void clear() {
    _breadcrumbs.clear();
  }

  /// Trim breadcrumbs to max limit
  static void _trimBreadcrumbs() {
    if (_breadcrumbs.length > _maxBreadcrumbs) {
      _breadcrumbs.removeRange(0, _breadcrumbs.length - _maxBreadcrumbs);
    }
  }

  /// Get breadcrumbs as formatted string for debugging
  static String getBreadcrumbsString() {
    return _breadcrumbs
        .map((b) => '${b.timestamp.toIso8601String()}: $b')
        .join('\n');
  }
}
