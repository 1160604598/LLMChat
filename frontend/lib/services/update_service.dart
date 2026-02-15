import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';

class UpdateInfo {
  final String version;
  final int buildNumber;
  final String changelog;
  final String downloadUrlAndroid;
  final String downloadUrlWindows;
  final bool forceUpdate;

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.changelog,
    required this.downloadUrlAndroid,
    required this.downloadUrlWindows,
    required this.forceUpdate,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'],
      buildNumber: json['build_number'],
      changelog: json['changelog'],
      downloadUrlAndroid: json['download_url_android'],
      downloadUrlWindows: json['download_url_windows'],
      forceUpdate: json['force_update'],
    );
  }
}

class UpdateService {
  final Dio _dio = Dio();

  Future<UpdateInfo?> checkUpdate() async {
    try {
      final response = await _dio.get('${ApiService.baseUrl}/system/check-update');
      if (response.statusCode == 200) {
        final info = UpdateInfo.fromJson(response.data);
        final packageInfo = await PackageInfo.fromPlatform();
        
        int currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
        print('Update Check: Server Build=${info.buildNumber}, Client Build=$currentBuild');
        
        // If build number is 0 (debug/dev), maybe we want to force check version string?
        // Or just assume server build number > 0 means update if current is 0?
        // Let's assume current build is valid. 
        // For development, we can manually set build number in pubspec.yaml
        
        if (info.buildNumber > currentBuild) {
          return info;
        }
      }
    } catch (e) {
      print('Check update failed: $e');
    }
    return null;
  }

  Future<File?> downloadUpdate(String url, Function(int, int) onProgress) async {
    try {
      Directory? dir;
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      
      if (dir == null) return null;

      String fileName = url.split('/').last;
      String savePath = '${dir.path}/$fileName';
      
      // Delete existing file if it exists to ensure fresh download
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Append timestamp to avoid cache
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final downloadUrl = url.contains('?') ? '$url&t=$timestamp' : '$url?t=$timestamp';

      await _dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: onProgress,
        deleteOnError: true, // Delete file if download fails
      );

      return File(savePath);
    } catch (e) {
      print('Download failed: $e');
      return null;
    }
  }

  Future<void> installUpdate(File file) async {
    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        await Permission.requestInstallPackages.request();
      }
    }
    
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      print("Install failed: ${result.message}");
    }
  }
}
