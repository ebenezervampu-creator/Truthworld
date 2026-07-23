import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class UploadRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Creates an initial placeholder document in Firestore
  Future<void> createPlaceholderDocument({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection('videos').doc(docId).set(data);
  }

  /// Listen to a document for server-side processing updates
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToVideoDocument(String docId) {
    return _firestore.collection('videos').doc(docId).snapshots();
  }

  /// Uploads video bytes and returns an UploadTask for progress tracking
  UploadTask uploadVideoBytes({
    required String uniqueId,
    required Uint8List bytes,
  }) {
    final videoRef = _storage.ref().child('videos/$uniqueId/original.mp4');
    final metadata = SettableMetadata(contentType: 'video/mp4');
    return videoRef.putData(bytes, metadata);
  }

  /// Uploads image bytes and returns the download URL
  Future<String> uploadImageBytes({
    required String uniqueId,
    required Uint8List bytes,
  }) async {
    final imageRef = _storage.ref().child('thumbnails/$uniqueId.jpg');
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    final uploadTask = await imageRef.putData(bytes, metadata);
    return uploadTask.ref.getDownloadURL();
  }

  /// Uploads an AI voice sample for dubbing cloning
  Future<void> uploadVoiceSample({
    required PlatformFile voiceSampleFile,
    required String userId,
    required String uniqueId,
  }) async {
    final sampleExt = voiceSampleFile.extension ?? 'wav';
    final sampleRef = _storage.ref().child('voices/$userId/$uniqueId.$sampleExt');
    final sampleMeta = SettableMetadata(contentType: 'audio/$sampleExt');
    final sampleBytes = await voiceSampleFile.xFile.readAsBytes();
    await sampleRef.putData(sampleBytes, sampleMeta);
  }

  /// Updates an existing video document
  Future<void> updateVideoDocument({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection('videos').doc(docId).update(data);
  }

  /// Deletes a video document (used for cleanup on failure)
  Future<void> deleteVideoDocument(String docId) async {
    await _firestore.collection('videos').doc(docId).delete();
  }
}
