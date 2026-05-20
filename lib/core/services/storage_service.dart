import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/feedback/feedback_service.dart';

/// GetX Service for Firebase Storage operations
class StorageService extends GetxService {
  late final FirebaseStorage _storage;

  // Observable states
  final isLoading = false.obs;
  final uploadProgress = 0.0.obs;
  final hasError = false.obs;
  final errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _storage = FirebaseStorage.instance;
  }

  /// Ensure auth context is ready for Storage operations on web
  Future<void> _ensureStorageAuthReady() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not authenticated");
      }

      // Get the ID token and ensure it's fresh
      await user.getIdToken(true);

      // On web, add a small delay to ensure Firebase Storage SDK picks it up
      if (kIsWeb) {
        debugPrint('⏳ [StorageService] Waiting for Storage auth context sync...');
        await Future.delayed(const Duration(milliseconds: 300));
        debugPrint('✅ [StorageService] Storage auth context synchronized');
      }

      debugPrint('✅ [StorageService] Storage auth ready for user: ${user.uid}');
    } catch (e) {
      debugPrint('❌ [StorageService] Failed to prepare Storage auth: $e');
      throw Exception("Storage auth preparation failed: $e");
    }
  }

  /// Upload file from bytes
  Future<String> uploadFileFromBytes({
    required String path,
    required List<int> bytes,
    String? mimeType,
  }) async {
    try {
      isLoading.value = true;
      uploadProgress.value = 0;
      hasError.value = false;

      debugPrint('🚀 [StorageService] Starting uploadFileFromBytes...');
      debugPrint('📂 [StorageService] Target Path: $path');
      debugPrint('📦 [StorageService] Payload Bytes: ${bytes.length} bytes');
      debugPrint('🏷️ [StorageService] MimeType: ${mimeType ?? 'application/octet-stream'}');

      DialogService.loading(message: 'Uploading file...');

      // Ensure Storage auth is synchronized on web
      await _ensureStorageAuthReady();

      final ref = _storage.ref().child(path);

      debugPrint('📤 [StorageService] Invoking putData...');
      final uploadTask = ref.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(contentType: mimeType ?? 'application/octet-stream'),
      );

      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          debugPrint('📊 [StorageService] Event -> State: ${snapshot.state}, '
              'Transferred: ${snapshot.bytesTransferred}/${snapshot.totalBytes} bytes');
          uploadProgress.value = snapshot.totalBytes > 0
              ? (snapshot.bytesTransferred / snapshot.totalBytes)
              : 0.0;
          debugPrint('📈 [StorageService] Calculated Progress: ${(uploadProgress.value * 100).toStringAsFixed(1)}%');
        },
        onError: (e) {
          debugPrint('❌ [StorageService] Stream Event Error: $e');
          _handleError(e);
        },
      );

      debugPrint('⏳ [StorageService] Awaiting uploadTask future completion with 20s timeout...');
      await uploadTask.timeout(const Duration(seconds: 20));
      debugPrint('✅ [StorageService] uploadTask completed successfully!');

      final downloadUrl = await ref.getDownloadURL();
      debugPrint('🔗 [StorageService] Retrieved Download URL: $downloadUrl');

      DialogService.close();
      SnackbarService.success(
        message: 'File uploaded successfully',
        duration: const Duration(seconds: 2),
      );
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ [StorageService] Critical catch block exception: $e');
      DialogService.close();
      _handleError(e);
      SnackbarService.error(
        message: 'Upload failed: ${errorMessage.value}',
        actionLabel: 'Retry',
        onAction: () =>
            uploadFileFromBytes(path: path, bytes: bytes, mimeType: mimeType),
      );
      rethrow;
    } finally {
      isLoading.value = false;
      uploadProgress.value = 0;
    }
  }

  /// Get download URL for a file
  Future<String> getDownloadUrl(String path) async {
    try {
      isLoading.value = true;
      hasError.value = false;

      final url = await _storage.ref().child(path).getDownloadURL();
      return url;
    } catch (e) {
      _handleError(e);
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Delete a file
  Future<void> deleteFile(String path) async {
    try {
      isLoading.value = true;
      hasError.value = false;
      DialogService.loading(message: 'Deleting file...');

      await _storage.ref().child(path).delete();

      DialogService.close();
      ToastService.success('File deleted');
    } catch (e) {
      DialogService.close();
      _handleError(e);
      SnackbarService.error(
        message: 'Delete failed: ${errorMessage.value}',
        actionLabel: 'Retry',
        onAction: () => deleteFile(path),
      );
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// List files in a directory
  Future<List<Reference>> listFiles(String path) async {
    try {
      isLoading.value = true;
      hasError.value = false;

      final result = await _storage.ref().child(path).listAll();
      return result.items;
    } catch (e) {
      _handleError(e);
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Get Firebase Storage instance
  FirebaseStorage get storage => _storage;

  /// Handle errors
  void _handleError(dynamic error) {
    hasError.value = true;
    errorMessage.value = error.toString();
  }

  /// Clear error
  void clearError() {
    hasError.value = false;
    errorMessage.value = '';
  }
}





