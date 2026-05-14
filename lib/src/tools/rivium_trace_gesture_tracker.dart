import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/rivium_trace_breadcrumbs.dart';
import '../models/breadcrumb.dart';
import 'rivium_trace_navigator_observer.dart';

/// Auto-captures user gestures (taps, long-presses) as breadcrumbs.
///
/// Works on every Flutter target (web, android, ios, macos, windows, linux)
/// because it sits on the framework's `GestureBinding` rather than touching
/// platform code.
///
/// Why this matters: in `--release` builds (especially Flutter web), stack
/// traces often point into framework or unmapped JS frames. Knowing which
/// widget the user tapped right before the error usually tells the developer
/// where to look without needing a perfect stack trace.
///
/// Enable once at startup:
///
/// ```dart
/// RiviumTrace.enableGestureBreadcrumbs();
/// ```
class RiviumTraceGestureTracker {
  static bool _enabled = false;
  static DateTime? _lastTapAt;
  static const _dedupWindow = Duration(milliseconds: 250);

  /// Install global pointer-event tracking. Idempotent.
  ///
  /// `WidgetsFlutterBinding.ensureInitialized()` must have been called first;
  /// gesture tracking attaches to the live binding instance.
  static void enable() {
    if (_enabled) return;

    final binding = WidgetsBinding.instance;
    binding.pointerRouter.addGlobalRoute(_handlePointerEvent);

    _enabled = true;
  }

  /// Remove the global pointer hook.
  static void disable() {
    if (!_enabled) return;
    WidgetsBinding.instance.pointerRouter.removeGlobalRoute(
      _handlePointerEvent,
    );
    _enabled = false;
  }

  static void _handlePointerEvent(PointerEvent event) {
    // React on pointer-DOWN, not pointer-up. The reason: synchronous
    // onPressed handlers can throw inside the gesture pipeline, which
    // interrupts the same dispatch cycle as the pointer-up event — the
    // breadcrumb would never get logged for the tap that *caused* the
    // error. Pointer-down fires before the gesture recognizer hands off
    // to onPressed, so the breadcrumb is in place before the throw.
    if (event is! PointerDownEvent) return;

    // Touch + mouse on web fire multiple pointer-downs for a single tap.
    // Drop near-duplicates inside a short window so we don't double-log.
    final now = DateTime.now();
    if (_lastTapAt != null && now.difference(_lastTapAt!) < _dedupWindow) {
      return;
    }
    _lastTapAt = now;

    try {
      final widgetInfo = _identifyTappedWidget(event.position);
      RiviumTraceBreadcrumbs.add(
        widgetInfo.summary,
        type: BreadcrumbType.user,
        data: {
          'action': 'tap',
          if (widgetInfo.widgetType != null)
            'widget': widgetInfo.widgetType,
          if (widgetInfo.label != null) 'label': widgetInfo.label,
          if (widgetInfo.keyValue != null) 'key': widgetInfo.keyValue,
          if (widgetInfo.path != null) 'path': widgetInfo.path,
          if (RiviumTraceNavigatorObserver.currentRoute != null)
            'route': RiviumTraceNavigatorObserver.currentRoute,
          'position': {
            'x': event.position.dx.round(),
            'y': event.position.dy.round(),
          },
        },
      );
    } catch (_) {
      // Never let breadcrumb capture interfere with the app — silent fallback.
    }
  }

  /// Walk the render tree at the tapped location and pick the most specific
  /// interactive widget. Strategy:
  ///   1. Hit-test at the position.
  ///   2. For each render object on the path, walk its element + ancestors,
  ///      collecting every widget the classifier recognizes.
  ///   3. Return the highest-priority match. Buttons (ElevatedButton,
  ///      IconButton, etc.) outrank InkWell, which outranks GestureDetector.
  ///
  /// Why ancestors matter: ElevatedButton wraps an internal GestureDetector
  /// in its own subtree. Hit-testing lands on the GestureDetector first
  /// because it's the deepest render object with a hit-test. The
  /// ElevatedButton is its ancestor — so we have to walk up to find it.
  static _TappedWidgetInfo _identifyTappedWidget(Offset position) {
    final binding = WidgetsBinding.instance;
    final renderView = binding.renderViews.isNotEmpty
        ? binding.renderViews.first
        : null;
    if (renderView == null) {
      return _TappedWidgetInfo.unknown();
    }

    final hitTestResult = HitTestResult();
    renderView.hitTest(hitTestResult, position: position);

    Element? bestElement;
    String? bestType;
    int bestPriority = -1;

    void consider(Element element) {
      final result = _classifyInteractive(element.widget);
      if (result == null) return;
      if (result.priority > bestPriority) {
        bestPriority = result.priority;
        bestType = result.name;
        bestElement = element;
      }
    }

    for (final entry in hitTestResult.path) {
      final target = entry.target;
      if (target is! RenderObject) continue;

      final element = _findElementForRenderObject(target);
      if (element == null) continue;

      // Check the hit element itself, then walk up to the screen root
      // looking for higher-specificity widgets (button > InkWell > etc.).
      consider(element);
      element.visitAncestorElements((ancestor) {
        consider(ancestor);
        // Stop climbing once we hit a route boundary so we don't walk
        // outside the current screen.
        return ancestor.widget is! ModalRoute && ancestor.widget is! Navigator;
      });
    }

    if (bestElement == null || bestType == null) {
      return _TappedWidgetInfo.unknown();
    }

    final label = _extractLabel(bestElement!);
    final keyValue = _extractKey(bestElement!.widget);
    final path = _buildWidgetPath(bestElement!);

    return _TappedWidgetInfo(
      widgetType: bestType,
      label: label,
      keyValue: keyValue,
      path: path,
      summary: _summarize(bestType, label, keyValue),
    );
  }

  /// Map a RenderObject back to its Element by walking the focused tree.
  /// `WidgetsBinding.focusManager` would be cleaner but doesn't expose this.
  static Element? _findElementForRenderObject(RenderObject target) {
    Element? found;
    void visit(Element element) {
      if (found != null) return;
      if (element.renderObject == target) {
        found = element;
        return;
      }
      element.visitChildren(visit);
    }

    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return null;
    root.visitChildren(visit);
    return found;
  }

  /// Recognize widgets that represent a user action and assign a priority.
  /// Higher priority = more specific = preferred when multiple widgets match
  /// at the same tap location (e.g. ElevatedButton wraps an internal
  /// GestureDetector — we want the button name, not the detector).
  static _ClassifyResult? _classifyInteractive(Widget widget) {
    // Priority 30 — concrete buttons / form controls. Most specific.
    if (widget is ElevatedButton) return const _ClassifyResult('ElevatedButton', 30);
    if (widget is TextButton) return const _ClassifyResult('TextButton', 30);
    if (widget is OutlinedButton) return const _ClassifyResult('OutlinedButton', 30);
    if (widget is FilledButton) return const _ClassifyResult('FilledButton', 30);
    if (widget is IconButton) return const _ClassifyResult('IconButton', 30);
    if (widget is FloatingActionButton) return const _ClassifyResult('FloatingActionButton', 30);
    if (widget is CupertinoButton) return const _ClassifyResult('CupertinoButton', 30);
    if (widget is Switch) return const _ClassifyResult('Switch', 30);
    if (widget is Checkbox) return const _ClassifyResult('Checkbox', 30);
    if (widget is Radio) return const _ClassifyResult('Radio', 30);
    if (widget is Slider) return const _ClassifyResult('Slider', 30);
    if (widget is PopupMenuButton) return const _ClassifyResult('PopupMenuButton', 30);
    if (widget is DropdownButton) return const _ClassifyResult('DropdownButton', 30);

    // Priority 20 — Material ripple wrappers. Useful but less specific than
    // a named button widget.
    if (widget is InkWell) return const _ClassifyResult('InkWell', 20);
    if (widget is InkResponse) return const _ClassifyResult('InkResponse', 20);

    // Priority 10 — bare GestureDetector. Last-resort match because every
    // tappable Flutter widget tends to have one in its subtree.
    if (widget is GestureDetector) return const _ClassifyResult('GestureDetector', 10);
    return null;
  }

  /// Pull human-readable text from the widget subtree. Prefers `Text`,
  /// `Semantics.label`, then `Tooltip.message` — falls back to null.
  static String? _extractLabel(Element interactiveElement) {
    String? label;
    void search(Element element) {
      if (label != null) return;

      final widget = element.widget;
      if (widget is Text && widget.data != null && widget.data!.isNotEmpty) {
        label = widget.data;
        return;
      }
      if (widget is Semantics &&
          widget.properties.label != null &&
          widget.properties.label!.isNotEmpty) {
        label = widget.properties.label;
        return;
      }
      if (widget is Tooltip && widget.message != null) {
        label = widget.message;
        return;
      }
      if (widget is Icon && widget.semanticLabel != null) {
        label = widget.semanticLabel;
        return;
      }

      element.visitChildren(search);
    }

    interactiveElement.visitChildren(search);
    if (label != null && label!.length > 80) {
      label = '${label!.substring(0, 77)}...';
    }
    return label;
  }

  /// Surface developer-supplied keys (`Key('checkout-button')`) when present.
  static String? _extractKey(Widget widget) {
    final key = widget.key;
    if (key is ValueKey) {
      final value = key.value;
      if (value != null) return value.toString();
    }
    return null;
  }

  /// Build a coarse widget-tree path so devs can locate the tap in code.
  /// Walks up from the interactive widget collecting common screen markers.
  /// Capped at 4 levels to keep breadcrumb data small.
  static String? _buildWidgetPath(Element interactiveElement) {
    final markers = <String>[];
    Element current = interactiveElement;
    Element? next;
    int depth = 0;

    while (depth < 30 && markers.length < 4) {
      final type = current.widget.runtimeType.toString();
      if (_isPathMarker(type)) {
        markers.add(type);
      }
      next = null;
      current.visitAncestorElements((ancestor) {
        next = ancestor;
        return false;
      });
      if (next == null) break;
      current = next!;
      depth++;
    }

    if (markers.isEmpty) return null;
    return markers.reversed.join(' > ');
  }

  static bool _isPathMarker(String typeName) {
    // Screen-ish containers worth showing in the path. Skipping leaf widgets
    // and infrastructure (RenderObjectToWidgetAdapter, _MaterialInterior etc.)
    return typeName.endsWith('Page') ||
        typeName.endsWith('Screen') ||
        typeName.endsWith('View') ||
        typeName == 'Scaffold' ||
        typeName == 'Dialog' ||
        typeName == 'BottomSheet' ||
        typeName == 'Drawer' ||
        typeName == 'AppBar';
  }

  static String _summarize(
    String? widgetType,
    String? label,
    String? keyValue,
  ) {
    final id = label ?? keyValue;
    if (id != null && id.isNotEmpty) {
      return 'Tap on $widgetType: "$id"';
    }
    return 'Tap on $widgetType';
  }

  @visibleForTesting
  static bool get isEnabled => _enabled;
}

class _ClassifyResult {
  final String name;
  final int priority;
  const _ClassifyResult(this.name, this.priority);
}

class _TappedWidgetInfo {
  final String? widgetType;
  final String? label;
  final String? keyValue;
  final String? path;
  final String summary;

  const _TappedWidgetInfo({
    required this.summary,
    this.widgetType,
    this.label,
    this.keyValue,
    this.path,
  });

  factory _TappedWidgetInfo.unknown() =>
      const _TappedWidgetInfo(summary: 'Tap on unknown widget');
}
