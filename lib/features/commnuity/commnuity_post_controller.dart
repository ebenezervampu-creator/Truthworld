import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

class CommunityPostController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = Uuid();

  RxDouble uploadProgress = 0.0.obs;
  RxString imageUrl = ''.obs;
  UploadTask? _imageUploadTask;
  var pickedImage = Rx<PlatformFile?>(null);

  RxString selectedCategory = "General".obs;
  RxString selectedVisibility = "Public".obs;
  RxBool isScheduled = false.obs;
  Rx<DateTime> scheduledDate = DateTime.now().add(Duration(days: 1)).obs;

  Future<void> pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      pickedImage.value = result.files.first;
      await _startImageUpload(pickedImage.value!);
    }
  }

  Future<void> _startImageUpload(PlatformFile file) async {
    try {
      if (_imageUploadTask != null) await _imageUploadTask!.cancel();
      uploadProgress.value = 0.0;

      final ref = _storage.ref(
        "community_images/${_uuid.v4()}.${file.extension}",
      );
      final metadata = SettableMetadata(contentType: 'image/${file.extension}');
      _imageUploadTask = ref.putData(file.bytes!, metadata);

      _imageUploadTask!.snapshotEvents.listen((event) {
        uploadProgress.value = event.totalBytes > 0
            ? event.bytesTransferred / event.totalBytes
            : 0;
      });

      final snapshot = await _imageUploadTask!.whenComplete(() {});
      imageUrl.value = await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      debugPrint('🔥 Firebase Storage Error: ${e.code}');
      debugPrint('📝 Message: ${e.message}');
      uploadProgress.value = 0.0;
      Get.snackbar("Upload Error", "Failed to upload image: ${e.message}");
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      uploadProgress.value = 0.0;
      Get.snackbar("Error", "An unexpected error occurred during upload");
    }
  }

  Future<void> uploadPost({
    required String title,
    required String description,
    required String channelId,
    required String channelName,
    required String channelImage,
  }) async {
    if (pickedImage.value == null || imageUrl.value.isEmpty) {
      Get.snackbar("Error", "Please upload an image first.");
      return;
    }

    final docRef = _firestore.collection("Community").doc();
    await docRef.set({
      "id": docRef.id,
      "title": title,
      "description": description,
      "image": imageUrl.value,
      "timestamp": Timestamp.now(),
      "ownerId": FirebaseAuth.instance.currentUser!.uid,
      "channelId": channelId,
      "channelName": channelName,
      "channelImage": channelImage,
      "selectedCategory": selectedCategory.value,
      "visibility": isScheduled.value ? "Scheduled" : selectedVisibility.value,
      if (isScheduled.value)
        "scheduledTime": Timestamp.fromDate(scheduledDate.value),
    });

    Get.snackbar("Success", "Community post uploaded!");
    _resetUploads();
  }

  void _resetUploads() {
    pickedImage.value = null;
    imageUrl.value = '';
    uploadProgress.value = 0.0;
    _imageUploadTask = null;
    isScheduled.value = false;
  }
}




