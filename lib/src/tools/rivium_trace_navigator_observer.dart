import 'package:flutter/material.dart';

import '../../rivium_trace_flutter_sdk.dart';

/// Navigator observer for RiviumTrace to track current route/page
class RiviumTraceNavigatorObserver extends NavigatorObserver {
  static String? _currentRoute;
  static String? _previousRoute;
  static String? _manualRoute; // For manual tracking
  static final Map<String, DateTime> _routeTimestamps = {};

  /// Get the current route name
  static String? get currentRoute => _manualRoute ?? _currentRoute;

  /// Manually set current route (optional for complex routing)
  static void setCurrentRoute(String route) {
    _manualRoute = route;
    _routeTimestamps[route] = DateTime.now();
  }

  /// Clear manual route (falls back to automatic detection)
  static void clearManualRoute() {
    _manualRoute = null;
  }

  /// Get the previous route name
  static String? get previousRoute => _previousRoute;

  /// Get how long user has been on current route
  static Duration? get timeOnCurrentRoute {
    if (_currentRoute == null) return null;
    final startTime = _routeTimestamps[_currentRoute!];
    if (startTime == null) return null;
    return DateTime.now().difference(startTime);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _updateRoute(route, previousRoute);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _updateRoute(previousRoute, route);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _updateRoute(newRoute, oldRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _updateRoute(previousRoute, route);
    super.didRemove(route, previousRoute);
  }

  void _updateRoute(
    Route<dynamic>? currentRoute,
    Route<dynamic>? previousRoute,
  ) {
    // Extract route name with fallbacks
    String? routeName;
    String? routePath;

    if (currentRoute?.settings.name != null) {
      routeName = currentRoute!.settings.name;
    }

    // Try to extract path from arguments or settings
    if (currentRoute?.settings.arguments != null) {
      final args = currentRoute!.settings.arguments;
      if (args is Map && args.containsKey('location')) {
        routePath = args['location'].toString();
      }
    }

    // Fallback to route name or default
    final previousRouteName = _currentRoute;
    _previousRoute = previousRouteName;
    _currentRoute = routeName ?? routePath ?? '/';

    // Add navigation breadcrumb only for actual route changes
    if (previousRouteName != null && previousRouteName != _currentRoute) {
      RiviumTraceBreadcrumbs.addNavigation(
        previousRouteName,
        _currentRoute ?? 'unknown',
      );
    } else if (previousRouteName == null && _currentRoute != null) {
      // Only for the very first route (app startup)
      RiviumTraceBreadcrumbs.add(
        'Entered $_currentRoute',
        type: BreadcrumbType.navigation,
      );
    }

    // Track timestamp for current route
    if (_currentRoute != null) {
      _routeTimestamps[_currentRoute!] = DateTime.now();
    }

    // Clean up old timestamps (keep only last 10 routes)
    if (_routeTimestamps.length > 10) {
      final sortedEntries = _routeTimestamps.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      _routeTimestamps.clear();
      _routeTimestamps.addAll(Map.fromEntries(sortedEntries.take(5)));
    }
  }

  /// Get navigation context for error reporting
  static Map<String, dynamic> getNavigationContext() {
    return {
      'current_route': _currentRoute,
      'previous_route': _previousRoute,
      'time_on_route_seconds': timeOnCurrentRoute?.inSeconds,
      'route_history': _routeTimestamps.keys.toList(),
    };
  }

  /// Reset navigation state (useful for testing)
  static void reset() {
    _currentRoute = null;
    _previousRoute = null;
    _routeTimestamps.clear();
  }
}
