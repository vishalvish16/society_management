class AppConstants {
  static const String appName = 'Society Manager';
  static const String appTagline = 'Your residential society, smarter.';

  // For mobile devices on the same WiFi, use your machine's LAN IP.
  // For Flutter web (browser), use localhost.
  // static const String apiBaseUrl = 'http://localhost:3001/api/';
  static const String apiBaseUrl =
      'https://wherever-registration-reynolds-quoted.trycloudflare.com/api/';

  /// Server root for static `/uploads/...` paths returned by the API.
  static String get uploadsBaseUrl => apiBaseUrl.replaceAll('/api/', '');

  static String? uploadUrlFromPath(String? relative) {
    if (relative == null || relative.isEmpty) return null;
    if (relative.startsWith('http')) return relative;
    return '$uploadsBaseUrl$relative';
  }
}
