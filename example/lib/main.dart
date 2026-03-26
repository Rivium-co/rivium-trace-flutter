// example/main.dart
import 'package:flutter/material.dart';
import 'package:rivium_trace_flutter_sdk/rivium_trace_flutter_sdk.dart';

void main() async {
  // ========================================================================
  // RECOMMENDED: Use initWithZone for comprehensive error catching
  // This wraps the app in runZonedGuarded to catch async errors,
  // and automatically handles crash detection on mobile platforms.
  //
  // IMPORTANT: Call initWithZone BEFORE WidgetsFlutterBinding.ensureInitialized()
  // ========================================================================
  await RiviumTrace.initWithZone(
    RiviumTraceConfig(
      apiKey: 'rv_live_1fb14a9cead2a0e9c5767b145d21883a6765e955e230d054',
      apiUrl: 'http://192.168.xxx.xxx:3001', //self host ip
      environment: 'development',
      release: '0.1.0',
      debug: true,
      enabled: true,
      captureUncaughtErrors: true,
      // Sample rate: 1.0 = capture 100% of errors
      // Set to 0.5 for 50%, 0.25 for 25%, etc.
      sampleRate: 1.0,
      // Offline storage: automatically stores errors when offline (mobile only)
      enableOfflineStorage: true,
      maxBreadcrumbs: 30,
    ),
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Set user ID for tracking
      RiviumTrace.setUserId('user123');

      // Set global tags and extra context
      RiviumTrace.setTag('app_variant', 'full');
      RiviumTrace.setExtra('onboarding_completed', true);

      // Enable logging
      RiviumTrace.enableLogging(
        sourceId: 'flutter-demo-app',
        sourceName: 'Flutter Demo App',
      );

      runApp(MyApp());
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RiviumTrace SDK Demo',
      navigatorObservers: [
        // Add RiviumTrace navigator observer for automatic breadcrumbs
        RiviumTraceNavigatorObserver(),
      ],
      home: HomePage(),
      routes: {'/details': (context) => DetailsPage()},
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();

    // Log app start
    RiviumTrace.info('Home page initialized');

    // Send an info message
    RiviumTrace.captureMessage('User opened the app');
  }

  Future<void> _testErrorCapture() async {
    setState(() => _status = 'Capturing error...');

    try {
      throw Exception('This is a test error for RiviumTrace');
    } catch (e, stackTrace) {
      await RiviumTrace.captureException(
        e,
        stackTrace: stackTrace,
        message: 'User triggered test error',
        extra: {'user_action': 'test_error_button'},
      );

      setState(() => _status = 'Error captured!');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error captured and sent to RiviumTrace'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ========================================================================
  // Intentional Crash - Test uncaught exception handling
  // When using initWithZone, the zone catches this and sends it to RiviumTrace.
  // On next app launch, CrashDetector also detects the unclean exit.
  // ========================================================================
  void _testTriggerCrash() {
    RiviumTrace.addUserBreadcrumb('User triggered intentional crash');
    RiviumTrace.captureMessage(
      'About to crash intentionally',
      level: MessageLevel.warning,
    );

    // This throws outside a try/catch — the zone from initWithZone catches it
    throw Exception('Intentional crash for testing RiviumTrace');
  }

  Future<void> _testMessages() async {
    setState(() => _status = 'Sending messages...');

    // Info message
    await RiviumTrace.captureMessage('User completed onboarding');

    // Warning message with extra data
    await RiviumTrace.captureMessage(
      'API rate limit approaching',
      level: MessageLevel.warning,
      extra: {'remaining_calls': 10, 'limit': 100},
    );

    // Debug message without breadcrumbs
    await RiviumTrace.captureMessage(
      'Cache hit for user data',
      level: MessageLevel.debug,
      includeBreadcrumbs: false,
      extra: {'cache_key': 'user_profile'},
    );

    // Error level message
    await RiviumTrace.captureMessage(
      'Payment processing failed',
      level: MessageLevel.error,
      extra: {'transaction_id': 'tx_12345', 'amount': 99.99},
    );

    setState(() => _status = 'Messages sent!');
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('4 messages sent to RiviumTrace')));
    }
  }

  Future<void> _testLogging() async {
    setState(() => _status = 'Sending logs...');

    RiviumTrace.trace('Entering checkout flow');
    RiviumTrace.debug('Cart items loaded', metadata: {'item_count': 3});
    RiviumTrace.info('User started checkout');
    RiviumTrace.warn('Inventory low for item SKU-123', metadata: {'stock': 2});
    RiviumTrace.logError('Failed to apply discount code');
    RiviumTrace.fatal('Database connection lost');

    // Flush logs immediately
    await RiviumTrace.flushLogs();

    setState(
      () => _status = 'Logs sent! (${RiviumTrace.pendingLogCount} pending)',
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('6 logs sent to RiviumTrace')));
    }
  }

  Future<void> _testPerformance() async {
    setState(() => _status = 'Tracking performance...');

    // Track an async operation
    final result = await RiviumTrace.trackOperation(
      'simulateApiCall',
      () async {
        await Future.delayed(Duration(milliseconds: 350));
        return 'success';
      },
    );

    // Report a manual performance span
    await RiviumTrace.reportPerformanceSpan(
      PerformanceSpan.fromHttpRequest(
        method: 'GET',
        url: 'https://api.example.com/users',
        startTime: DateTime.now().subtract(Duration(milliseconds: 200)),
        durationMs: 200,
        statusCode: 200,
        platform: RiviumTrace.getPlatform(),
        environment: 'production',
        releaseVersion: '0.1.0',
      ),
    );

    // Report a DB query span
    await RiviumTrace.reportPerformanceSpan(
      PerformanceSpan.forDbQuery(
        queryType: 'SELECT',
        tableName: 'users',
        startTime: DateTime.now().subtract(Duration(milliseconds: 15)),
        durationMs: 15,
        rowsAffected: 1,
        platform: RiviumTrace.getPlatform(),
        environment: 'production',
      ),
    );

    setState(() => _status = 'Performance tracked! Result: $result');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Performance spans sent to RiviumTrace')),
      );
    }
  }

  // ========================================================================
  // Performance HTTP Client - Automatic HTTP request tracking
  // Wraps an http.Client to automatically capture performance spans
  // for every HTTP request made through it.
  // ========================================================================
  Future<void> _testPerformanceHttpClient() async {
    setState(() => _status = 'Testing PerformanceHttpClient...');

    // Create a performance-tracking HTTP client via the SDK factory
    final client = RiviumTrace.createPerformanceClient(
      addBreadcrumbs: true,
      // Optionally exclude hosts you don't want tracked
      excludedHosts: {'internal-service.local'},
      // Only report requests slower than 10ms
      minDurationMs: 10,
    );

    try {
      // Every request through this client is automatically tracked as a
      // performance span and sent to RiviumTrace — no manual span creation needed
      final response = await client.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
      );

      // Make a second request to demonstrate batch span reporting
      final response2 = await client.get(
        Uri.parse('https://jsonplaceholder.typicode.com/users/1'),
      );

      // Force flush any buffered spans
      await client.flush();

      setState(
        () => _status =
            'PerformanceHttpClient done! Status: ${response.statusCode}, ${response2.statusCode}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('2 HTTP requests auto-tracked as performance spans'),
          ),
        );
      }
    } catch (e) {
      setState(() => _status = 'HTTP request failed: $e');
    } finally {
      client.close();
    }
  }

  Future<void> _testBreadcrumbs() async {
    setState(() => _status = 'Adding breadcrumbs...');

    // Add various breadcrumb types
    RiviumTrace.addBreadcrumb('App initialized', type: BreadcrumbType.system);
    RiviumTrace.addUserBreadcrumb('Tapped breadcrumb button');
    RiviumTrace.addHttpBreadcrumb(
      'GET',
      'https://api.example.com/data',
      statusCode: 200,
      durationMs: 150,
    );
    RiviumTraceBreadcrumbs.addState(
      'theme_changed',
      data: {'from': 'light', 'to': 'dark'},
    );

    // Send a message with the breadcrumbs attached so they reach the backend
    await RiviumTrace.captureMessage(
      'Breadcrumb test - 4 breadcrumbs recorded',
      level: MessageLevel.info,
      extra: {'breadcrumb_count': 4, 'test_type': 'breadcrumbs'},
    );

    setState(() => _status = 'Breadcrumbs added and sent!');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('4 breadcrumbs added and sent to RiviumTrace')),
      );
    }
  }

  // ========================================================================
  // Crash Detection - Check if the app crashed in the previous session
  // Mobile only: uses marker files to detect unclean exits.
  // Automatically handled by initWithZone, but you can also check manually.
  // ========================================================================
  Future<void> _testCrashDetection() async {
    setState(() => _status = 'Checking crash status...');

    final didCrash = await CrashDetector.didCrashLastSession();
    final lastCrashTime = await CrashDetector.getLastCrashTime();

    if (didCrash) {
      // Retrieve the crash report from the previous session
      final crashReport = await CrashDetector.getCrashReport(
        RiviumTrace.getPlatform() ?? 'unknown',
        'production',
        '0.1.0',
      );

      if (crashReport != null) {
        // Send the crash report to RiviumTrace
        await RiviumTrace.captureException(
          Exception(crashReport.message),
          message: 'Crash detected from previous session',
          extra: {
            'crash_time': lastCrashTime?.toIso8601String(),
            'detected_at': DateTime.now().toIso8601String(),
          },
        );
      }

      setState(
        () => _status =
            'Previous session crashed at ${lastCrashTime?.toIso8601String() ?? "unknown"}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Crash detected from previous session!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      setState(() => _status = 'No crash detected in previous session');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No crash in previous session (clean exit)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // ========================================================================
  // Offline Storage - Store errors locally when offline, retry on reconnect
  // Enabled via enableOfflineStorage: true in RiviumTraceConfig (default).
  // Mobile only — web platform is excluded.
  // ========================================================================
  Future<void> _testOfflineStorage() async {
    setState(() => _status = 'Checking offline storage...');

    final hasStored = await OfflineStorageService.hasStoredErrors();
    final storedCount = await OfflineStorageService.getStoredErrorCount();

    if (hasStored) {
      // Retrieve and display stored errors
      final storedErrors = await OfflineStorageService.getStoredErrors();

      setState(
        () => _status =
            'Offline storage: $storedCount errors stored\n'
            'First stored: ${storedErrors.first['message'] ?? 'unknown'}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$storedCount offline errors found — SDK will auto-retry sending',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      // Demonstrate how offline storage works:
      // When the SDK fails to send an error (no network), it automatically
      // stores it locally. On next app launch, stored errors are retried.
      setState(
        () => _status =
            'Offline storage: 0 errors stored\n'
            'Errors are auto-stored when network is unavailable (mobile only)',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No offline errors stored — errors queue automatically when offline',
            ),
          ),
        );
      }
    }
  }

  // ========================================================================
  // Sample Rate Demo - Show how sampleRate affects error capture
  // ========================================================================
  Future<void> _testSampleRate() async {
    setState(() => _status = 'Testing sample rate...');

    // The sample rate is configured at init time (see main()).
    // With sampleRate: 1.0, all errors are captured.
    // With sampleRate: 0.5, ~50% of errors are randomly dropped.
    //
    // To demonstrate, we send 10 errors and check how many are actually sent.
    // With sampleRate: 1.0 (current config), all 10 should be sent.
    // If you change to sampleRate: 0.5, roughly 5 of 10 will be sent.

    int sentCount = 0;

    for (int i = 0; i < 10; i++) {
      try {
        throw Exception('Sample rate test error #$i');
      } catch (e, stackTrace) {
        await RiviumTrace.captureException(
          e,
          stackTrace: stackTrace,
          message: 'Sample rate test',
          extra: {'error_index': i, 'total_errors': 10},
          callback: (success) {
            if (success) sentCount++;
          },
        );
      }
    }

    // Small delay to let callbacks complete
    await Future.delayed(Duration(milliseconds: 500));

    setState(
      () => _status =
          'Sample rate test: $sentCount/10 errors sent\n'
          'Current rate: 1.0 (100%)',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$sentCount of 10 errors captured (sampleRate: 1.0)'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('RiviumTrace SDK Demo')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'SDK Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('Initialized: ${RiviumTrace.isInitialized()}'),
                    Text('Platform: ${RiviumTrace.getPlatform() ?? "unknown"}'),
                    Text('User: ${RiviumTrace.getUserId() ?? "not set"}'),
                    Text(
                      'Session: ${RiviumTrace.getSessionId()?.substring(0, 8) ?? "none"}...',
                    ),
                    SizedBox(height: 8),
                    Text(_status, style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Feature buttons
            Expanded(
              child: ListView(
                children: [
                  _buildSectionHeader('Core Features'),
                  _buildFeatureButton(
                    'Capture Error',
                    'Test exception capture with stack trace',
                    Icons.error,
                    Colors.red,
                    _testErrorCapture,
                  ),
                  _buildFeatureButton(
                    'Trigger Crash',
                    'Throw uncaught exception (will crash app!)',
                    Icons.dangerous,
                    Colors.red[900]!,
                    _testTriggerCrash,
                  ),
                  _buildFeatureButton(
                    'Send Messages',
                    'Send info, warning, debug, and error messages',
                    Icons.message,
                    Colors.blue,
                    _testMessages,
                  ),
                  _buildFeatureButton(
                    'Send Logs',
                    'Send trace, debug, info, warn, error, fatal logs',
                    Icons.list_alt,
                    Colors.green,
                    _testLogging,
                  ),
                  _buildFeatureButton(
                    'Track Performance',
                    'Send HTTP and DB performance spans (manual)',
                    Icons.speed,
                    Colors.orange,
                    _testPerformance,
                  ),
                  _buildFeatureButton(
                    'Add Breadcrumbs',
                    'Add system, user, HTTP, and state breadcrumbs',
                    Icons.timeline,
                    Colors.purple,
                    _testBreadcrumbs,
                  ),
                  _buildFeatureButton(
                    'Navigate',
                    'Go to details page (sends navigation breadcrumb)',
                    Icons.navigate_next,
                    Colors.teal,
                    () async {
                      await RiviumTrace.captureMessage(
                        'User navigating to details page',
                        level: MessageLevel.info,
                        extra: {'from': 'HomePage', 'to': 'DetailsPage'},
                      );
                      if (context.mounted) {
                        Navigator.pushNamed(context, '/details');
                      }
                    },
                  ),

                  SizedBox(height: 12),
                  _buildSectionHeader('Advanced Features'),
                  _buildFeatureButton(
                    'Performance HTTP Client',
                    'Auto-track HTTP requests as performance spans',
                    Icons.http,
                    Colors.deepOrange,
                    _testPerformanceHttpClient,
                  ),
                  _buildFeatureButton(
                    'Crash Detection',
                    'Check if previous session crashed (mobile only)',
                    Icons.warning_amber,
                    Colors.amber[800]!,
                    _testCrashDetection,
                  ),
                  _buildFeatureButton(
                    'Offline Storage',
                    'View locally stored errors for offline retry (mobile only)',
                    Icons.cloud_off,
                    Colors.grey[700]!,
                    _testOfflineStorage,
                  ),
                  _buildFeatureButton(
                    'Sample Rate',
                    'Send 10 errors to demonstrate sample rate filtering',
                    Icons.tune,
                    Colors.indigo,
                    _testSampleRate,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFeatureButton(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right),
        onTap: onPressed,
      ),
    );
  }
}

class DetailsPage extends StatefulWidget {
  const DetailsPage({super.key});

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  @override
  void initState() {
    super.initState();

    // Log and send page view
    RiviumTrace.info('Details page viewed');
    RiviumTrace.captureMessage(
      'Details page viewed',
      level: MessageLevel.info,
      extra: {
        'current_route': RiviumTraceNavigatorObserver.currentRoute ?? 'unknown',
        'previous_route': RiviumTraceNavigatorObserver.previousRoute ?? 'none',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Details Page')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Navigation breadcrumb was automatically recorded!'),
            SizedBox(height: 16),
            Text(
              'Current route: ${RiviumTraceNavigatorObserver.currentRoute ?? "unknown"}',
            ),
            Text(
              'Previous route: ${RiviumTraceNavigatorObserver.previousRoute ?? "none"}',
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await RiviumTrace.captureMessage(
                  'User navigating back from details page',
                  level: MessageLevel.info,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
