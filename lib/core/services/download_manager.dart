import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class DownloadManager {
  final Dio _dio = Dio();

  Future<String> getModelsDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${dir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir.path;
  }

  Future<String?> downloadModel(String url, String filename, void Function(double, int, int, double) onProgress) async {
    try {
      final modelsDirPath = await getModelsDirectory();
      final filePath = '$modelsDirPath/$filename';
      
      final file = File(filePath);
      if (await file.exists()) {
        return filePath;
      }

      final tmpFile = File('$filePath.tmp');
      int downloadedBytes = 0;
      if (await tmpFile.exists()) {
        downloadedBytes = await tmpFile.length();
      }

      int lastProgressPercent = -1;
      debugPrint('Starting download for $filename...');
      debugPrint('Target path: $filePath');
      
      final headRes = await _dio.head(url);
      final totalBytesStr = headRes.headers.value(HttpHeaders.contentLengthHeader);
      final totalBytes = totalBytesStr != null ? int.parse(totalBytesStr) : 0;
      
      if (totalBytes > 0 && downloadedBytes >= totalBytes) {
         await tmpFile.rename(filePath);
         return filePath;
      }

      final response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: downloadedBytes > 0 ? {'range': 'bytes=$downloadedBytes-'} : null,
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final raf = await tmpFile.open(mode: FileMode.append);
      final stream = response.data!.stream;
      
      int received = downloadedBytes;
      int responseLength = 0;
      final contentLenStr = response.headers.value(HttpHeaders.contentLengthHeader);
      if (contentLenStr != null) {
        responseLength = int.parse(contentLenStr);
      }
      final total = totalBytes > 0 ? totalBytes : (downloadedBytes + responseLength);

      final stopwatch = Stopwatch()..start();
      int bytesSinceLastUpdate = 0;

      await for (final chunk in stream) {
        await raf.writeFrom(chunk);
        received += chunk.length;
        bytesSinceLastUpdate += chunk.length;
        
        if (total > 0) {
          final progress = received / total;
          final currentPercent = (progress * 100).toInt();
          
          if (currentPercent > lastProgressPercent || stopwatch.elapsedMilliseconds > 500) {
            lastProgressPercent = currentPercent;
            
            double speedMBps = 0;
            if (stopwatch.elapsedMilliseconds > 0) {
              speedMBps = (bytesSinceLastUpdate / (1024 * 1024)) / (stopwatch.elapsedMilliseconds / 1000);
            }
            
            debugPrint('Download progress: $currentPercent% ($received / $total bytes) at ${speedMBps.toStringAsFixed(2)} MB/s');
            onProgress(progress, received, total, speedMBps);
            
            bytesSinceLastUpdate = 0;
            stopwatch.reset();
          }
        }
      }
      await raf.close();
      
      await tmpFile.rename(filePath);
      debugPrint('Download completed successfully for $filename');
      return filePath;
    } on DioException catch (e) {
      debugPrint('DioException during download: ${e.message} (type: ${e.type})');
      return null;
    } catch (e) {
      debugPrint('Unknown download error: $e');
      return null;
    }
  }

  Future<List<String>> getDownloadedModels() async {
    final modelsDirPath = await getModelsDirectory();
    final dir = Directory(modelsDirPath);
    if (!await dir.exists()) return [];

    return dir
        .listSync()
        .whereType<File>()
        .map((f) => f.path)
        .toList();
  }
}
