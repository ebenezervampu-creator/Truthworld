import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/features/video/domain/repositories/video_upload_repository.dart';

/// Firebase Storage & Firestore implementation of [VideoUploadRepository].
class StorageVideoUploadRepository implements VideoUploadRepository {
  StorageVideoUploadRepository({
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;

  @override
  Future<Result<String>> uploadVideoFile({
    required String filePath,
    required String destinationPath,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final file = File(filePath);
      final ref = _storage.ref().child(destinationPath);
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final metadata = SettableMetadata(
        contentType: 'video/mp4',
        customMetadata: {
          'uploaderId': ?currentUid,
        },
      );
      final uploadTask = ref.putFile(file, metadata);

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((event) {
          if (event.totalBytes > 0) {
            final progress = event.bytesTransferred / event.totalBytes;
            onProgress(progress);
          }
        });
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return Result.success(downloadUrl);
    } catch (e) {
      return Result.failure(GenericAppException(message: e.toString()));
    }
  }

  @override
  Future<Result<String>> uploadThumbnailBytes({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final ref = _storage.ref().child('thumbnails/$fileName');
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploaderId': ?currentUid,
        },
      );
      final uploadTask = ref.putData(imageBytes, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return Result.success(downloadUrl);
    } catch (e) {
      return Result.failure(GenericAppException(message: e.toString()));
    }
  }

  @override
  Future<Result<String>> saveVideoMetadata(Map<String, dynamic> metadata) async {
    try {
      final docRef = _firestore.collection('videos').doc();
      final id = docRef.id;
      final data = Map<String, dynamic>.from(metadata);
      data['id'] = id;
      data['createdAt'] = FieldValue.serverTimestamp();

      await docRef.set(data);
      return Result.success(id);
    } catch (e) {
      return Result.failure(GenericAppException(message: e.toString()));
    }
  }
}
