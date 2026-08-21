import 'package:package_info_plus/package_info_plus.dart';
import 'api_client.dart';

class AppVersionInfo {
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String releaseNotes;
  final bool forceUpdate;

  AppVersionInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.forceUpdate,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      version: json['version'] as String,
      buildNumber: json['build_number'] as int,
      downloadUrl: json['download_url'] as String,
      releaseNotes: json['release_notes'] as String,
      forceUpdate: json['force_update'] as bool,
    );
  }
}

class UpdateInfo {
  final bool updateAvailable;
  final AppVersionInfo? serverVersion;

  UpdateInfo({required this.updateAvailable, this.serverVersion});
}

class UpdateService {
  final ApiClient _apiClient;

  UpdateService(this._apiClient);

  Future<UpdateInfo> checkForUpdates() async {
    try {
      final response = await _apiClient.dio.get('/version');
      if (response.statusCode == 200 && response.data != null) {
        final serverInfo = AppVersionInfo.fromJson(response.data);
        
        final packageInfo = await PackageInfo.fromPlatform();
        final localBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
        
        if (serverInfo.buildNumber > localBuildNumber || serverInfo.version != packageInfo.version) {
          return UpdateInfo(updateAvailable: true, serverVersion: serverInfo);
        }
      }
    } catch (e) {
      // Silently fail on update check errors to not disrupt app usage
    }
    return UpdateInfo(updateAvailable: false);
  }
}
