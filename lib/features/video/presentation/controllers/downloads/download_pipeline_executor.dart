import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/media_crypto_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/video/data/datasources/local/database_helpers.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Pipeline executor for native encrypted disk streaming and web IndexedDB media downloading.
class DownloadPipelineExecutor {
  /// Validates whether downloads are permitted given current network and user preferences.
  static bool validateDownloadSettings() {
    if (!Get.isRegistered<UserSettingsController>()) return true;
    final dl = UserSettingsController.to.downloads.value;

    if (dl.wifiOnly) {
      final isWifi = !Get.isRegistered<ConnectivityService>() ||
          ConnectivityService.to.isWifi;
      if (!isWifi) {
        AppSnackbar.show(
          'Wi-Fi Required',
          'Downloads are restricted to Wi-Fi connections in Settings.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF1E1E1E),
          colorText: Colors.white,
        );
        return false;
      }
    }
    return true;
  }

  /// Direct disk-streamed download pipeline for native platforms (Android / iOS / Desktop).
  static Future<void> downloadNative({
    required Video video,
    required String targetUrl,
    required OfflineVideo offlineVideo,
    required RxMap<String, double> progressMap,
    Function(double progress)? onProgress,
  }) async {
    final dir = await getOfflineDirectory();
    final ext = offlineVideo.isAudioOnly ? 'mp3' : 'mp4';
    final targetFile = File('${dir.path}/${video.id}.$ext');
    final tempFile = File('${dir.path}/${video.id}.part');

    if (await tempFile.exists()) {
      try {
        await tempFile.delete();
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'DownloadPipelineExecutor.downloadNative.deleteTemp',
        );
      }
    }

    var downloadSucceeded = false;
    var activeUrl = targetUrl;

    // 1. Direct HTTP streaming directly into file sink
    for (var attempt = 0; attempt < 2; attempt++) {
      if (activeUrl.startsWith('gs://')) {
        try {
          activeUrl = await FirebaseStorage.instance
              .refFromURL(activeUrl)
              .getDownloadURL();
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'DownloadPipelineExecutor.downloadNative.gsUrl',
          );
        }
      }

      if (activeUrl.startsWith('http://') || activeUrl.startsWith('https://')) {
        http.Client? client;
        IOSink? sink;
        try {
          client = http.Client();
          final request = http.Request('GET', Uri.parse(activeUrl));
          request.headers['Accept'] = '*/*';
          request.headers['User-Agent'] = 'Truthworld/1.0';

          final streamedResponse = await client.send(request);
          final status = streamedResponse.statusCode;

          if (status == 200 || status == 206) {
            final contentLength = streamedResponse.contentLength ?? 0;
            sink = tempFile.openWrite();
            var receivedBytes = 0;

            await for (final chunk in streamedResponse.stream) {
              sink.add(chunk);
              receivedBytes += chunk.length;
              if (contentLength > 0) {
                final prog = (receivedBytes / contentLength).clamp(0.0, 1.0);
                progressMap[video.id] = prog;
                onProgress?.call(prog);
              }
            }
            await sink.flush();
            await sink.close();
            sink = null;

            if (receivedBytes >= 512) {
              downloadSucceeded = true;
              break;
            }
          } else if (status == 401 || status == 403) {
            // Unauthenticated/expired token: resolve fresh signed token from Firebase Storage
            if (attempt == 0 &&
                (activeUrl.contains('firebasestorage.googleapis.com') ||
                    activeUrl.contains('storage.googleapis.com'))) {
              try {
                final ref = FirebaseStorage.instance.refFromURL(activeUrl);
                activeUrl = await ref.getDownloadURL();
                continue;
              } catch (e, s) {
                ErrorHandler.log(
                  e,
                  stackTrace: s,
                  tag: 'DownloadPipelineExecutor.downloadNative.refreshToken',
                );
              }
            }
          }
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'DownloadPipelineExecutor.downloadNative.httpStream',
          );
          if (sink != null) {
            try {
              await sink.close();
            } catch (e2, s2) {
              ErrorHandler.log(
                e2,
                stackTrace: s2,
                tag: 'DownloadPipelineExecutor.downloadNative.closeSink',
              );
            }
            sink = null;
          }
        } finally {
          client?.close();
        }
      }
    }

    // 2. Fallback: Firebase Storage SDK writeToFile (Direct stream to disk, no 10MB RAM cap)
    if (!downloadSucceeded) {
      try {
        Reference? storageRef;
        if (targetUrl.startsWith('gs://') ||
            targetUrl.startsWith('https://firebasestorage.googleapis.com') ||
            targetUrl.startsWith('https://storage.googleapis.com')) {
          try {
            storageRef = FirebaseStorage.instance.refFromURL(targetUrl);
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'DownloadPipelineExecutor.downloadNative.storageRefFromURL',
            );
          }
        }

        if (storageRef == null) {
          final probePaths = [
            'videos/${video.id}/1080p.mp4',
            'videos/${video.id}/720p.mp4',
            'videos/${video.id}/480p.mp4',
            'videos/${video.id}/360p.mp4',
            'videos/${video.id}/original.mp4',
            'videos/${video.id}/video.mp4',
            'videos/${video.id}.mp4',
          ];
          for (final path in probePaths) {
            try {
              final testRef = FirebaseStorage.instance.ref(path);
              await testRef.getMetadata();
              storageRef = testRef;
              break;
            } catch (e, s) {
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag: 'DownloadPipelineExecutor.downloadNative.probeMetadata',
              );
            }
          }
        }

        if (storageRef != null) {
          final downloadTask = storageRef.writeToFile(tempFile);
          downloadTask.snapshotEvents.listen(
            (event) {
              if (event.totalBytes > 0) {
                final prog =
                    (event.bytesTransferred / event.totalBytes).clamp(0.0, 1.0);
                progressMap[video.id] = prog;
                onProgress?.call(prog);
              }
            },
            onError: (e, stackTrace) => ErrorHandler.log(
              e,
              stackTrace: stackTrace,
              tag: 'DownloadPipelineExecutor.downloadSnapshotEvents',
            ),
          );
          await downloadTask;
          if (await tempFile.exists() && (await tempFile.length()) >= 512) {
            downloadSucceeded = true;
          }
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'DownloadPipelineExecutor.downloadNative.storageWriteToFile',
        );
      }
    }

    if (!downloadSucceeded ||
        !(await tempFile.exists()) ||
        (await tempFile.length()) < 512) {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'DownloadPipelineExecutor.downloadNative.deleteTempPart',
          );
        }
      }
      throw Exception('Media stream download failed or is too small.');
    }

    // Check for M3U8 text playlist header '#EXTM3U'
    final headerBytes =
        await tempFile.openRead(0, 7).expand((e) => e).take(7).toList();
    if (headerBytes.length >= 7 &&
        headerBytes[0] == 0x23 &&
        headerBytes[1] == 0x45 &&
        headerBytes[2] == 0x58 &&
        headerBytes[3] == 0x54 &&
        headerBytes[4] == 0x4D &&
        headerBytes[5] == 0x33 &&
        headerBytes[6] == 0x55) {
      await tempFile.delete();
      throw Exception('Stream URL is an HLS playlist rather than raw media.');
    }

    // Encrypt downloaded raw media into .twenc container
    final encryptedTargetFile = File('${dir.path}/${video.id}.twenc');
    final tempEncryptedFile = File('${dir.path}/${video.id}.twenc.tmp');

    if (await tempEncryptedFile.exists()) {
      try {
        await tempEncryptedFile.delete();
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'DownloadPipelineExecutor.downloadNative.deleteTempEncrypted',
        );
      }
    }

    await MediaCryptoService.instance.encryptFile(
      tempFile,
      tempEncryptedFile,
      isAudio: offlineVideo.isAudioOnly,
    );

    if (await encryptedTargetFile.exists()) {
      await encryptedTargetFile.delete();
    }
    await tempEncryptedFile.rename(encryptedTargetFile.path);

    // Securely delete plaintext temp file and any legacy files
    try {
      await tempFile.delete();
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'DownloadPipelineExecutor.downloadNative.deleteTempAndTarget',
      );
    }

    await saveOfflineVideoMetadata(video.id, offlineVideo);
  }

  /// Web platform download pipeline (buffers via BytesBuilder and persists to IndexedDB).
  static Future<void> downloadWeb({
    required Video video,
    required String targetUrl,
    required OfflineVideo offlineVideo,
    required RxMap<String, double> progressMap,
    Function(double progress)? onProgress,
  }) async {
    Uint8List? fileBytes;
    var activeUrl = targetUrl;

    for (var attempt = 0; attempt < 2; attempt++) {
      if (activeUrl.startsWith('gs://')) {
        try {
          activeUrl = await FirebaseStorage.instance
              .refFromURL(activeUrl)
              .getDownloadURL();
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'DownloadPipelineExecutor.downloadWeb.gsUrl',
          );
        }
      }

      if (activeUrl.startsWith('http://') || activeUrl.startsWith('https://')) {
        http.Client? client;
        try {
          client = http.Client();
          final request = http.Request('GET', Uri.parse(activeUrl));
          request.headers['Accept'] = '*/*';

          final streamedResponse = await client.send(request);
          final status = streamedResponse.statusCode;

          if (status == 200 || status == 206) {
            final contentLength = streamedResponse.contentLength ?? 0;
            final builder = BytesBuilder(copy: false);
            var received = 0;

            await for (final chunk in streamedResponse.stream) {
              builder.add(chunk);
              received += chunk.length;
              if (contentLength > 0) {
                final prog = (received / contentLength).clamp(0.0, 1.0);
                progressMap[video.id] = prog;
                onProgress?.call(prog);
              }
            }
            if (received >= 512) {
              fileBytes = builder.toBytes();
              break;
            }
          } else if (status == 401 || status == 403) {
            if (attempt == 0 &&
                (activeUrl.contains('firebasestorage.googleapis.com') ||
                    activeUrl.contains('storage.googleapis.com'))) {
              try {
                final ref = FirebaseStorage.instance.refFromURL(activeUrl);
                activeUrl = await ref.getDownloadURL();
                continue;
              } catch (e, s) {
                ErrorHandler.log(
                  e,
                  stackTrace: s,
                  tag: 'DownloadPipelineExecutor.downloadWeb.refreshToken',
                );
              }
            }
          }
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'DownloadPipelineExecutor.downloadWeb.httpStream',
          );
        } finally {
          client?.close();
        }
      }
    }

    // Web Fallback: Firebase Storage SDK getData with 500 MB maximum size cap
    if (fileBytes == null || fileBytes.length < 512) {
      try {
        Reference? storageRef;
        if (targetUrl.startsWith('gs://') ||
            targetUrl.startsWith('https://firebasestorage.googleapis.com') ||
            targetUrl.startsWith('https://storage.googleapis.com')) {
          try {
            storageRef = FirebaseStorage.instance.refFromURL(targetUrl);
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'DownloadPipelineExecutor.downloadWeb.storageRefFromURL',
            );
          }
        }
        if (storageRef == null) {
          final probePaths = [
            'videos/${video.id}/1080p.mp4',
            'videos/${video.id}/720p.mp4',
            'videos/${video.id}/480p.mp4',
            'videos/${video.id}/360p.mp4',
            'videos/${video.id}/original.mp4',
            'videos/${video.id}/video.mp4',
            'videos/${video.id}.mp4',
          ];
          for (final path in probePaths) {
            try {
              final testRef = FirebaseStorage.instance.ref(path);
              await testRef.getMetadata();
              storageRef = testRef;
              break;
            } catch (e, s) {
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag: 'DownloadPipelineExecutor.downloadWeb.probeMetadata',
              );
            }
          }
        }

        if (storageRef != null) {
          fileBytes = await storageRef.getData(500 * 1024 * 1024);
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'DownloadPipelineExecutor.downloadWeb.getData',
        );
      }
    }

    if (fileBytes == null || fileBytes.length < 512) {
      throw Exception('Media stream download failed or is too small.');
    }

    if (fileBytes.length >= 7 &&
        fileBytes[0] == 0x23 &&
        fileBytes[1] == 0x45 &&
        fileBytes[2] == 0x58 &&
        fileBytes[3] == 0x54 &&
        fileBytes[4] == 0x4D &&
        fileBytes[5] == 0x33 &&
        fileBytes[6] == 0x55) {
      throw Exception('Stream URL is an HLS playlist rather than raw media.');
    }

    await saveOfflineVideoBytes(video.id, fileBytes, offlineVideo);
  }
}
