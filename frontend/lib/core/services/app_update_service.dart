import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';

class AppUpdateService {
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));
      final response = await dio.get('${AppConstants.apiBaseUrl}app-info');
      final data = response.data['data'] as Map<String, dynamic>?;
      if (data == null) return;

      final minVersion = data['minVersion'] as String? ?? '1.0.0';
      final storeUrl = Platform.isIOS
          ? (data['iosUrl'] as String? ?? '')
          : (data['androidUrl'] as String? ?? '');

      final info = await PackageInfo.fromPlatform();
      final current = info.version;

      if (_isOlderThan(current, minVersion)) {
        if (context.mounted) {
          _showForceUpdateDialog(context, minVersion, storeUrl);
        }
      }
    } catch (_) {
      // Silently fail — never block the app for an update check
    }
  }

  /// Returns true if [current] is strictly older than [minimum].
  static bool _isOlderThan(String current, String minimum) {
    final c = _parse(current);
    final m = _parse(minimum);
    for (var i = 0; i < 3; i++) {
      if (c[i] < m[i]) return true;
      if (c[i] > m[i]) return false;
    }
    return false;
  }

  static List<int> _parse(String v) {
    final parts = v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) parts.add(0);
    return parts;
  }

  static void _showForceUpdateDialog(
      BuildContext context, String minVersion, String storeUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.system_update, color: Colors.blue),
              SizedBox(width: 10),
              Text('Update Required'),
            ],
          ),
          content: Text(
            'A newer version ($minVersion) of the app is required to continue. '
            'Please update to the latest version.',
          ),
          actions: [
            FilledButton.icon(
              onPressed: storeUrl.isNotEmpty
                  ? () => launchUrl(Uri.parse(storeUrl),
                      mode: LaunchMode.externalApplication)
                  : null,
              icon: const Icon(Icons.download),
              label: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }
}
