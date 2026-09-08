import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/feedback/feedback_service.dart';

/// GetX Service for Firebase Storage operations
class StorageService extends GetxService {
  late final FirebaseStorage _storage;

  // Observable states
  final RxBool isLoading = false.obs;
  final RxDouble uploadProgress = 0.0.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _storage = FirebaseStorage.instance;
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

      DialogService.loading(message: 'Uploading file...');

      final ref = _storage.ref().child(path);
      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      final uploadTask = ref.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(
          contentType: mimeType ?? 'application/octet-stream',
          customMetadata: {
            'uploaderId': ?currentUid,
          },
        ),
      );

      uploadTask.snapshotEvents.listen(
        (snapshot) {
          uploadProgress.value =
              snapshot.bytesTransferred / snapshot.totalBytes;
          if (uploadProgress.value == 1.0 || uploadProgress.value >= 0.9) {
            // Near completion
          }
        },
        onError: (e) {
          _handleError(e);
        },
      );

      await uploadTask;
      DialogService.close();
      final downloadUrl = await ref.getDownloadURL();

      SnackbarService.success(
        message: 'File uploaded successfully',
        duration: const Duration(seconds: 2),
      );
      return downloadUrl;
    } catch (e) {
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
