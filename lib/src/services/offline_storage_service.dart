// lib/src/services/offline_storage_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/rivium_trace_error.dart';

/// Service for storing errors offline when network is unavailable
class OfflineStorageService {
  static const String _fileName = 'rivium_trace_offline_errors.json';
  static const int _maxStoredErrors = 100;

  static File? _file;
  static bool _isInitialized = false;

  /// Initialize the offline storage
  static Future<void> initialize() async {
    if (_isInitialized || kIsWeb) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      _file = File('${directory.path}/$_fileName');
      _isInitialized = true;
    } catch (e) {
      debugPrint('RiviumTrace: Failed to initialize offline storage: $e');
    }
  }

  /// Store an error for later sending
  static Future<void> storeError(RiviumTraceError error) async {
    if (!_isInitialized || _file == null || kIsWeb) return;

    try {
      final errors = await _readErrors();
      errors.add(error.toJson());

      // Keep only the most recent errors
      if (errors.length > _maxStoredErrors) {
        errors.removeRange(0, errors.length - _maxStoredErrors);
      }

      await _file!.writeAsString(jsonEncode(errors));
    } catch (e) {
      debugPrint('RiviumTrace: Failed to store offline error: $e');
    }
  }

  /// Get all stored errors
  static Future<List<Map<String, dynamic>>> getStoredErrors() async {
    if (!_isInitialized || _file == null || kIsWeb) return [];
    return await _readErrors();
  }

  /// Clear all stored errors
  static Future<void> clearStoredErrors() async {
    if (!_isInitialized || _file == null || kIsWeb) return;

    try {
      if (await _file!.exists()) {
        await _file!.writeAsString('[]');
      }
    } catch (e) {
      debugPrint('RiviumTrace: Failed to clear offline errors: $e');
    }
  }

  /// Remove a specific error after it's been sent
  static Future<void> removeError(int index) async {
    if (!_isInitialized || _file == null || kIsWeb) return;

    try {
      final errors = await _readErrors();
      if (index >= 0 && index < errors.length) {
        errors.removeAt(index);
        await _file!.writeAsString(jsonEncode(errors));
      }
    } catch (e) {
      debugPrint('RiviumTrace: Failed to remove offline error: $e');
    }
  }

  /// Check if there are stored errors
  static Future<bool> hasStoredErrors() async {
    if (!_isInitialized || _file == null || kIsWeb) return false;

    try {
      final errors = await _readErrors();
      return errors.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get the count of stored errors
  static Future<int> getStoredErrorCount() async {
    if (!_isInitialized || _file == null || kIsWeb) return 0;

    try {
      final errors = await _readErrors();
      return errors.length;
    } catch (e) {
      return 0;
    }
  }

  static Future<List<Map<String, dynamic>>> _readErrors() async {
    try {
      if (_file == null || !await _file!.exists()) {
        return [];
      }

      final content = await _file!.readAsString();
      if (content.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('RiviumTrace: Failed to read offline errors: $e');
      return [];
    }
  }
}
