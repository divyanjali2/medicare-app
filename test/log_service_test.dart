import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare_app/services/log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final logDir = Directory('logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
  });

  test('LogService writes error and stackTrace into logs directory', () async {
    final logService = LogService.instance;

    const testError = 'Sample Test Error: Failed to fetch data';
    final testStackTrace = StackTrace.current;

    await logService.logError(
      testError,
      stackTrace: testStackTrace,
      reason: 'Unit Test Triggered Error',
      category: 'TEST_ERROR',
      context: {'testKey': 'testValue'},
    );

    final files = await logService.getLogFiles();
    expect(files.isNotEmpty, isTrue);

    final recentContent = await logService.readLatestLogs(maxLines: 50);
    expect(recentContent.contains('Sample Test Error: Failed to fetch data'), isTrue);
    expect(recentContent.contains('TEST_ERROR'), isTrue);
    expect(recentContent.contains('Unit Test Triggered Error'), isTrue);
    expect(recentContent.contains('testKey'), isTrue);
  });
}
