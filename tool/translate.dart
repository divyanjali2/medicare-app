// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// Free automated translator for ARB localization files.
/// Translates new English strings from `app_en.arb` into `app_si.arb` (Sinhala)
/// using the free MyMemory translation API (no API key or credit card needed).
void main() async {
  final enFile = File('lib/l10n/app_en.arb');
  final siFile = File('lib/l10n/app_si.arb');

  if (!enFile.existsSync()) {
    print('Error: lib/l10n/app_en.arb not found.');
    exit(1);
  }

  final enJson = jsonDecode(await enFile.readAsString()) as Map<String, dynamic>;
  final siJson = siFile.existsSync()
      ? jsonDecode(await siFile.readAsString()) as Map<String, dynamic>
      : <String, dynamic>{'@@locale': 'si'};

  final client = HttpClient();
  int newCount = 0;

  for (final entry in enJson.entries) {
    final key = entry.key;
    if (key.startsWith('@')) continue;

    final enText = entry.value.toString();

    // Only translate if not already translated
    if (!siJson.containsKey(key) || siJson[key] == null || (siJson[key] as String).isEmpty) {
      print('Translating "$key": "$enText"...');
      try {
        final translated = await _translateText(client, enText, 'en', 'si');
        siJson[key] = translated;
        newCount++;
        print('  -> $translated');
        // Brief pause to respect free API rate limits
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        print('  Failed to translate "$key": $e');
      }
    }
  }

  client.close();

  // Save sorted ARB
  const encoder = JsonEncoder.withIndent('  ');
  await siFile.writeAsString('${encoder.convert(siJson)}\n');

  print('\nDone! Auto-translated $newCount new strings into lib/l10n/app_si.arb.');

  // Run flutter gen-l10n
  print('Regenerating Flutter localization classes...');
  final res = await Process.run('flutter', ['gen-l10n'], runInShell: true);
  if (res.exitCode == 0) {
    print('Flutter localization updated successfully!');
  } else {
    print('Note: You can run "flutter gen-l10n" to refresh classes.');
  }
}

Future<String> _translateText(
  HttpClient client,
  String text,
  String sourceLang,
  String targetLang,
) async {
  final uri = Uri.parse(
    'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(text)}&langpair=$sourceLang|$targetLang',
  );

  final request = await client.getUrl(uri);
  request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)');
  final response = await request.close();

  if (response.statusCode != 200) {
    throw Exception('HTTP status ${response.statusCode}');
  }

  final body = await response.transform(utf8.decoder).join();
  final data = jsonDecode(body) as Map<String, dynamic>;
  final responseData = data['responseData'] as Map<String, dynamic>?;
  final translatedText = responseData?['translatedText'] as String?;

  if (translatedText != null && translatedText.isNotEmpty) {
    return translatedText;
  }
  return text;
}
