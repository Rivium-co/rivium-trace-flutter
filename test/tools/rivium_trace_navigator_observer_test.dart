import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_trace_flutter_sdk/rivium_trace_flutter_sdk.dart';

void main() {
  group('RiviumTraceNavigatorObserver', () {
    setUp(() {
      RiviumTraceNavigatorObserver.reset();
      RiviumTraceNavigatorObserver.clearManualRoute();
      RiviumTraceBreadcrumbs.clear();
    });

    test('currentRoute is null initially', () {
      expect(RiviumTraceNavigatorObserver.currentRoute, isNull);
    });

    test('previousRoute is null initially', () {
      expect(RiviumTraceNavigatorObserver.previousRoute, isNull);
    });

    test('setCurrentRoute sets manual route', () {
      RiviumTraceNavigatorObserver.setCurrentRoute('/profile');
      expect(RiviumTraceNavigatorObserver.currentRoute, '/profile');
    });

    test('clearManualRoute falls back to automatic', () {
      RiviumTraceNavigatorObserver.setCurrentRoute('/manual');
      expect(RiviumTraceNavigatorObserver.currentRoute, '/manual');

      RiviumTraceNavigatorObserver.clearManualRoute();
      // Falls back to null since no automatic route has been set
      expect(RiviumTraceNavigatorObserver.currentRoute, isNull);
    });

    test('timeOnCurrentRoute is null when no route', () {
      expect(RiviumTraceNavigatorObserver.timeOnCurrentRoute, isNull);
    });

    test('getNavigationContext returns context map', () {
      final context = RiviumTraceNavigatorObserver.getNavigationContext();

      expect(context, isA<Map<String, dynamic>>());
      expect(context.containsKey('current_route'), isTrue);
      expect(context.containsKey('previous_route'), isTrue);
      expect(context.containsKey('time_on_route_seconds'), isTrue);
      expect(context.containsKey('route_history'), isTrue);
    });

    test('reset clears automatic navigation state', () {
      RiviumTraceNavigatorObserver.reset();

      expect(RiviumTraceNavigatorObserver.previousRoute, isNull);
      final context = RiviumTraceNavigatorObserver.getNavigationContext();
      expect((context['route_history'] as List), isEmpty);
    });

    testWidgets('didPush updates current route', (tester) async {
      final observer = RiviumTraceNavigatorObserver();

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: const Scaffold(body: Text('Home')),
          routes: {
            '/second': (_) => const Scaffold(body: Text('Second')),
          },
        ),
      );

      // Initial route push
      expect(RiviumTraceNavigatorObserver.currentRoute, '/');

      // Navigate to second page
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/second');
      await tester.pumpAndSettle();

      expect(RiviumTraceNavigatorObserver.currentRoute, '/second');
      expect(RiviumTraceNavigatorObserver.previousRoute, '/');
    });

    testWidgets('didPop updates route on back navigation', (tester) async {
      final observer = RiviumTraceNavigatorObserver();

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: const Scaffold(body: Text('Home')),
          routes: {
            '/second': (_) => const Scaffold(body: Text('Second')),
          },
        ),
      );

      // Navigate forward
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/second');
      await tester.pumpAndSettle();
      expect(RiviumTraceNavigatorObserver.currentRoute, '/second');

      // Navigate back
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      expect(RiviumTraceNavigatorObserver.currentRoute, '/');
    });

    testWidgets('adds navigation breadcrumbs on route change', (tester) async {
      final observer = RiviumTraceNavigatorObserver();
      RiviumTraceBreadcrumbs.clear();

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: const Scaffold(body: Text('Home')),
          routes: {
            '/second': (_) => const Scaffold(body: Text('Second')),
          },
        ),
      );

      // Navigate to second page
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/second');
      await tester.pumpAndSettle();

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      // Should have at least the initial route entry and the navigation
      expect(crumbs.isNotEmpty, isTrue);
    });

    test('manual route takes precedence over automatic', () {
      RiviumTraceNavigatorObserver.setCurrentRoute('/manual-override');
      // Even if automatic would say something else, manual wins
      expect(RiviumTraceNavigatorObserver.currentRoute, '/manual-override');
    });
  });
}
