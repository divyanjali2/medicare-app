import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// Centralized error and system logging service for the MediCare application.
///
/// Ensures every error (Flutter framework, unhandled async exceptions,
/// platform dispatcher errors, and manual service try-catches) is captured
/// and persisted into a dedicated `logs` folder.
class LogService {
  LogService._internal();

  /// Singleton instance
  static final LogService instance = LogService._internal();

  Directory? _logDir;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
  final DateFormat _fileDateSuffix = DateFormat('yyyy-MM-dd');
  Completer<void>? _initCompleter;

  /// Initializes the log folder and hooks into global error handlers.
  static Future<void> initialize() async {
    await instance._ensureDirectoryInitialized();

    // 1. Capture Flutter framework errors (widget build, layout, render)
    FlutterError.onError = (FlutterErrorDetails details) async {
      await instance.recordFlutterError(details);
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };

    // 2. Capture unhandled asynchronous Dart & platform errors
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      instance.recordPlatformError(error, stack);
      return true; // Marked as handled
    };

    // 3. Graceful UI fallback for widget crashes
    ErrorWidget.builder = (FlutterErrorDetails details) {
      instance.recordFlutterError(details);
      return Material(
        color: Colors.white,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'An unexpected error occurred.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details.exceptionAsString(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This incident has been recorded to the logs.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    };
  }

  /// Resolves and ensures the `logs` directory exists.
  Future<Directory> get logsDirectory async {
    if (_logDir != null && await _logDir!.exists()) {
      return _logDir!;
    }
    await _ensureDirectoryInitialized();
    return _logDir ?? Directory('logs');
  }

  Future<void> _ensureDirectoryInitialized() async {
    if (kIsWeb) return;
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    _initCompleter = Completer<void>();

    try {
      Directory? targetDir;

      // In Flutter mobile/desktop app runtime, get application documents dir
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        targetDir = Directory('${appDocDir.path}${Platform.pathSeparator}logs');
      } catch (_) {
        // Fallback for tests or environments where path_provider is not mocked
        targetDir = Directory('logs');
      }

      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      _logDir = targetDir;

      // Also ensure workspace/project logs directory exists if running in dev mode
      try {
        final workspaceLogsDir = Directory('logs');
        if (!await workspaceLogsDir.exists()) {
          await workspaceLogsDir.create(recursive: true);
        }
      } catch (_) {
        // Ignore if unable to access current working dir
      }
    } catch (e, stack) {
      debugPrint('[LogService] Failed to initialize log directory: $e\n$stack');
    } finally {
      _initCompleter!.complete();
    }
  }

  /// Records an uncaught Flutter framework error.
  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    final contextInfo = <String, dynamic>{
      'library': details.library,
      'context': details.context?.toString(),
      'summary': details.summary.toString(),
    };

    await logError(
      details.exception,
      stackTrace: details.stack,
      reason: 'Flutter Framework Error',
      category: 'FLUTTER_ERROR',
      context: contextInfo,
    );
  }

  /// Records an uncaught platform or asynchronous Dart error.
  Future<void> recordPlatformError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
  }) async {
    await logError(
      error,
      stackTrace: stackTrace,
      reason: reason ?? 'Unhandled Asynchronous / Platform Error',
      category: 'PLATFORM_ASYNC_ERROR',
    );
  }

  /// Generic method to log an error with details and stack trace.
  Future<void> logError(
    Object error, {
    StackTrace? stackTrace,
    String? reason,
    String category = 'ERROR',
    Map<String, dynamic>? context,
  }) async {
    final now = DateTime.now();
    final timestamp = _dateFormat.format(now);
    final dateSuffix = _fileDateSuffix.format(now);

    final sb = StringBuffer();
    sb.writeln('================================================================');
    sb.writeln('[$timestamp] [$category]');
    if (reason != null && reason.isNotEmpty) {
      sb.writeln('Reason: $reason');
    }
    if (context != null && context.isNotEmpty) {
      sb.writeln('Context: $context');
    }
    sb.writeln('Exception: $error');
    if (stackTrace != null) {
      sb.writeln('StackTrace:\n$stackTrace');
    } else {
      sb.writeln('StackTrace: None provided');
    }
    sb.writeln('================================================================\n');

    final logMessage = sb.toString();

    // Print to console in debug mode
    if (kDebugMode) {
      debugPrint(logMessage);
    }

    await _writeToLogFiles(logMessage, dateSuffix);
  }

  /// Logs informational messages to the log file.
  Future<void> logInfo(String message, {String? tag}) async {
    final now = DateTime.now();
    final timestamp = _dateFormat.format(now);
    final dateSuffix = _fileDateSuffix.format(now);
    final tagPrefix = tag != null ? '[$tag] ' : '';
    final entry = '[$timestamp] [INFO] $tagPrefix$message\n';

    if (kDebugMode) {
      debugPrint(entry);
    }

    await _writeToLogFiles(entry, dateSuffix);
  }

  /// Logs warning messages.
  Future<void> logWarning(
    String message, {
    StackTrace? stackTrace,
  }) async {
    final now = DateTime.now();
    final timestamp = _dateFormat.format(now);
    final dateSuffix = _fileDateSuffix.format(now);

    final sb = StringBuffer();
    sb.writeln('----------------------------------------------------------------');
    sb.writeln('[$timestamp] [WARNING] $message');
    if (stackTrace != null) {
      sb.writeln('StackTrace:\n$stackTrace');
    }
    sb.writeln('----------------------------------------------------------------\n');

    final logMessage = sb.toString();
    if (kDebugMode) {
      debugPrint(logMessage);
    }

    await _writeToLogFiles(logMessage, dateSuffix);
  }

  /// Internal helper to write content into the log files.
  Future<void> _writeToLogFiles(String content, String dateSuffix) async {
    if (kIsWeb) return;
    try {
      final dir = await logsDirectory;
      final dailyFile = File('${dir.path}${Platform.pathSeparator}error_$dateSuffix.log');
      final latestFile = File('${dir.path}${Platform.pathSeparator}latest_errors.log');

      await dailyFile.writeAsString(content, mode: FileMode.append, flush: true);
      await latestFile.writeAsString(content, mode: FileMode.append, flush: true);

      // In local development or desktop, also sync to workspace ./logs directory if it exists
      try {
        final workspaceDir = Directory('logs');
        if (await workspaceDir.exists() && workspaceDir.path != dir.path) {
          final wsDailyFile = File('${workspaceDir.path}${Platform.pathSeparator}error_$dateSuffix.log');
          final wsLatestFile = File('${workspaceDir.path}${Platform.pathSeparator}latest_errors.log');
          await wsDailyFile.writeAsString(content, mode: FileMode.append, flush: true);
          await wsLatestFile.writeAsString(content, mode: FileMode.append, flush: true);
        }
      } catch (_) {
        // Silently skip secondary mirror write failure
      }
    } catch (e) {
      // Avoid recursive crash inside logger
      if (kDebugMode) {
        debugPrint('[LogService] Failed to write error log: $e');
      }
    }
  }

  /// Returns all available log files in the logs directory.
  Future<List<File>> getLogFiles() async {
    try {
      final dir = await logsDirectory;
      final entities = await dir.list().toList();
      final files = entities.whereType<File>().where((f) => f.path.endsWith('.log')).toList();
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return files;
    } catch (_) {
      return [];
    }
  }

  /// Reads the content of the latest log file.
  Future<String> readLatestLogs({int maxLines = 100}) async {
    try {
      final dir = await logsDirectory;
      final file = File('${dir.path}${Platform.pathSeparator}latest_errors.log');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        if (lines.length > maxLines) {
          return lines.sublist(lines.length - maxLines).join('\n');
        }
        return lines.join('\n');
      }
    } catch (_) {}
    return 'No logs found.';
  }

  /// Clears all log files in the directory.
  Future<void> clearAllLogs() async {
    try {
      final files = await getLogFiles();
      for (final file in files) {
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LogService] Failed to clear logs: $e');
      }
    }
  }
}
