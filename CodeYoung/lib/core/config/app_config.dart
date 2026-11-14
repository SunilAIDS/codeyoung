import 'dart:io' show Platform;

/// Central runtime configuration.
///
/// The API base URL is resolved per platform and can be overridden at build
/// time without touching code:
///
///   flutter run --dart-define=API_BASE=http://192.168.1.20:3000
///   flutter build apk --dart-define=API_BASE=https://api.codeyoung.com
///
/// Android emulators reach the host machine through `10.0.2.2`; every other
/// target (Windows, iOS simulator, web, Linux) uses `localhost`.
class AppConfig {
  AppConfig._();

  static const String appName = 'CodeYoung';
  static const String tagline = 'Learn. Create. Innovate.';

  static const String _definedApi = String.fromEnvironment('API_BASE');
  static const String _definedChat = String.fromEnvironment('CHAT_BASE');

  static String get apiBase {
    if (_definedApi.isNotEmpty) return _normalize(_definedApi);
    return _normalize('$_host:3000');
  }

  /// Direct path to the Python mentor (used only for debugging the voice
  /// service; the app normally goes through [apiBase] so auth is attached).
  static String get chatBase {
    if (_definedChat.isNotEmpty) return _normalize(_definedChat);
    return _normalize('$_host:5001');
  }

  static String get _host {
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2';
    } catch (_) {
      // Platform is unavailable on web builds; fall through.
    }
    return 'http://127.0.0.1';
  }

  static String _normalize(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  // Timeouts (milliseconds)
  static const int connectTimeout = 8000;
  static const int receiveTimeout = 45000; // chat + tts can be slow
}
