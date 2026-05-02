class AppConstants {
  static const String appName = 'Society Manager';
  static const String appTagline = 'Your residential society, smarter.';

  // For mobile devices on the same WiFi, use your machine's LAN IP.
  // For Flutter web (browser), use localhost.
  // static const String apiBaseUrl = 'http://localhost:3001/api/';
  static const String apiBaseUrl =
      'https://appendix-meat-operators-protocols.trycloudflare.com/api/';

  /// Server root (scheme+host) derived from `apiBaseUrl`.
  static String get uploadsBaseUrl => apiBaseUrl.replaceAll('/api/', '');

  static String? uploadUrlFromPath(String? relative) {
    if (relative == null || relative.isEmpty) return null;
    if (relative.startsWith('http')) return relative;

    final r = relative.trim();
    // DB stores `/uploads/...` and backend serves it publicly.
    if (r.startsWith('/uploads/')) return '$uploadsBaseUrl$r';

    // Already an API path (or absolute-from-root path).
    if (r.startsWith('/api/')) return '$uploadsBaseUrl$r';
    if (r.startsWith('/')) return '$uploadsBaseUrl$r';
    return '$uploadsBaseUrl/$r';
  }
}
