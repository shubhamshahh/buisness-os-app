import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final String version;
  final String releaseNotes;
  final String downloadUrl;
  final String htmlUrl;
  final bool hasUpdate;

  UpdateInfo({
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.htmlUrl,
    required this.hasUpdate,
  });
}

class AppUpdateService {
  static const String currentVersion = '1.0.0';
  static const String githubApiUrl = 'https://api.github.com/repos/shubhamshahh/buisness-os-app/releases/latest';

  /// Checks GitHub Releases for new APK updates
  static Future<UpdateInfo?> checkForUpdates() async {
    try {
      final response = await http.get(
        Uri.parse(githubApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String tagName = (data['tag_name'] ?? '').toString().replaceAll('v', '').trim();
        final String body = (data['body'] ?? 'Performance improvements and bug fixes.').toString();
        final String htmlUrl = (data['html_url'] ?? 'https://github.com/shubhamshahh/buisness-os-app/releases').toString();

        String downloadUrl = htmlUrl;
        final List<dynamic> assets = data['assets'] ?? [];
        for (var asset in assets) {
          final name = (asset['name'] ?? '').toString().toLowerCase();
          if (name.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'] ?? htmlUrl;
            break;
          }
        }

        final bool isNewer = _isVersionNewer(currentVersion, tagName);

        return UpdateInfo(
          version: tagName.isEmpty ? currentVersion : tagName,
          releaseNotes: body,
          downloadUrl: downloadUrl,
          htmlUrl: htmlUrl,
          hasUpdate: isNewer,
        );
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
    return null;
  }

  static bool _isVersionNewer(String current, String latest) {
    if (latest.isEmpty) return false;
    try {
      List<int> currentParts = current.split('+')[0].split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> latestParts = latest.split('+')[0].split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        int c = i < currentParts.length ? currentParts[i] : 0;
        int l = i < latestParts.length ? latestParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Displays the Update Dialog to the user inside the mobile application
  static void showUpdateDialog(BuildContext context, UpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.system_update_rounded, color: Colors.blueAccent, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Update Available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Version v${updateInfo.version}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Current: v$currentVersion', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.blueAccent),
                      Text('New: v${updateInfo.version}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('What\'s New:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  updateInfo.releaseNotes,
                  style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final Uri url = Uri.parse(updateInfo.downloadUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
              label: const Text('Update Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );
  }
}
