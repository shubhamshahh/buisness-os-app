import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

class UpdateInfo {
  final String version;
  final String currentInstalledVersion;
  final String releaseNotes;
  final String downloadUrl;
  final String htmlUrl;
  final bool hasUpdate;

  UpdateInfo({
    required this.version,
    required this.currentInstalledVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.htmlUrl,
    required this.hasUpdate,
  });
}

class AppUpdateService {
  static const String fallbackVersion = '1.0.4';
  static const String githubApiUrl = 'https://api.github.com/repos/shubhamshahh/buisness-os-app/releases/latest';

  /// Checks GitHub Releases API and Supabase for new APK updates
  static Future<UpdateInfo?> checkForUpdates() async {
    String currentVersion = fallbackVersion;
    try {
      final pkgInfo = await PackageInfo.fromPlatform();
      if (pkgInfo.version.isNotEmpty) {
        currentVersion = pkgInfo.version;
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();

    // 1. Try GitHub API
    try {
      final response = await http.get(
        Uri.parse(githubApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 5));

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

        final String dismissedVer = prefs.getString('dismissed_update_version') ?? '';
        final bool isNewer = _isVersionNewer(currentVersion, tagName);
        final bool shouldShow = isNewer && (dismissedVer != tagName);

        return UpdateInfo(
          version: tagName.isEmpty ? currentVersion : tagName,
          currentInstalledVersion: currentVersion,
          releaseNotes: body,
          downloadUrl: downloadUrl,
          htmlUrl: htmlUrl,
          hasUpdate: shouldShow,
        );
      }
    } catch (e) {
      debugPrint('GitHub API check failed: $e');
    }

    // 2. Fallback: Check Supabase for app version if GitHub repo is private
    try {
      final response = await SupabaseService.instance.client
          .from('companies')
          .select('id, app_version, apk_url')
          .not('app_version', 'is', null)
          .limit(1);

      if (response.isNotEmpty) {
        final row = response.first;
        final String latestVer = (row['app_version'] ?? '').toString().replaceAll('v', '').trim();
        final String apkUrl = (row['apk_url'] ?? 'https://github.com/shubhamshahh/buisness-os-app/releases').toString();

        final bool isNewer = _isVersionNewer(currentVersion, latestVer);
        if (isNewer) {
          return UpdateInfo(
            version: latestVer,
            currentInstalledVersion: currentVersion,
            releaseNotes: 'Performance improvements, invoice enhancements, and new features.',
            downloadUrl: apkUrl,
            htmlUrl: apkUrl,
            hasUpdate: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Supabase version check failed: $e');
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
        return _UpdateDialogContent(updateInfo: updateInfo);
      },
    );
  }
}

class _UpdateDialogContent extends StatefulWidget {
  final UpdateInfo updateInfo;
  const _UpdateDialogContent({required this.updateInfo});

  @override
  State<_UpdateDialogContent> createState() => _UpdateDialogContentState();
}

class _UpdateDialogContentState extends State<_UpdateDialogContent> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusText = '';

  Future<http.StreamedResponse> _getWithRedirects(String initialUrl) async {
    final client = http.Client();
    var currentUri = Uri.parse(initialUrl);
    int redirectCount = 0;

    while (redirectCount < 10) {
      final request = http.Request('GET', currentUri);
      request.headers['User-Agent'] = 'Mozilla/5.0';
      final response = await client.send(request);

      if (response.statusCode >= 300 && response.statusCode < 400) {
        final String? location = response.headers['location'];
        if (location != null && location.isNotEmpty) {
          currentUri = Uri.parse(location);
          redirectCount++;
          continue;
        }
      }
      return response;
    }
    throw Exception('Too many redirects');
  }

  Future<void> _startDownloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusText = 'Preparing update...';
    });

    final String targetUrl = widget.updateInfo.downloadUrl.isNotEmpty
        ? widget.updateInfo.downloadUrl
        : widget.updateInfo.htmlUrl;

    try {
      final response = await _getWithRedirects(targetUrl);
      if (response.statusCode == 200) {
        final int contentLength = response.contentLength ?? 0;
        final Directory tempDir = await getTemporaryDirectory();
        final File apkFile = File('${tempDir.path}/app-release.apk');
        final sink = apkFile.openWrite();

        int downloaded = 0;
        await response.stream.listen((List<int> chunk) {
          downloaded += chunk.length;
          sink.add(chunk);
          if (contentLength > 0 && mounted) {
            setState(() {
              _downloadProgress = downloaded / contentLength;
              _statusText = 'Downloading: ${(_downloadProgress * 100).toStringAsFixed(0)}%';
            });
          }
        }).asFuture();

        await sink.close();

        if (mounted) {
          setState(() {
            _statusText = 'Opening installer...';
          });
        }

        final OpenResult res = await OpenFilex.open(
          apkFile.path,
          type: 'application/vnd.android.package-archive',
        );

        if (res.type == ResultType.done && mounted) {
          Navigator.pop(context);
          return;
        }
      }
    } catch (e) {
      debugPrint('Direct APK download error: $e');
    }

    // Fallback if direct APK download/open fails: Launch external browser
    try {
      final Uri url = Uri.parse(targetUrl);
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrlString(targetUrl, mode: LaunchMode.externalApplication);
      } catch (_) {
        try {
          await launchUrl(Uri.parse(widget.updateInfo.htmlUrl), mode: LaunchMode.platformDefault);
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _isDownloading = false;
      });
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Text('Version v${widget.updateInfo.version}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                  Text('Current: v${widget.updateInfo.currentInstalledVersion}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.blueAccent),
                  Text('New: v${widget.updateInfo.version}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_isDownloading) ...[
              Text(_statusText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(6),
              ),
            ] else ...[
              const Text('What\'s New:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Text(
                widget.updateInfo.releaseNotes,
                style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isDownloading) ...[
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('dismissed_update_version', widget.updateInfo.version);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Later', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: _startDownloadAndInstall,
            icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
            label: const Text('Update Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }
}
