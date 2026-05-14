import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/data/models/channel.dart';

class ChannelLoaderController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChannel();
    });
  }

  Future<void> _loadChannel() async {
    final channelId = Get.parameters['channelId'];

    if (channelId == null) {
      Get.snackbar("Error", "No channel ID found in URL");
      return;
    }

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('channels')
          .doc(channelId)
          .get();

      if (!doc.exists) {
        Get.snackbar("Error", "Channel not found");
        return;
      }

      final channel = Channel.fromDocumentSnapshot(doc);

      Get.offNamed("/channel-details", arguments: {"channel": channel});
      debugPrint("🧭 All route params: ${Get.parameters}");
    } catch (e) {
      Get.snackbar("Error", "Something went wrong: $e");
    }
  }
}

class ChannelLoaderScreen extends StatelessWidget {
  const ChannelLoaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(ChannelLoaderController());
    return Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}





