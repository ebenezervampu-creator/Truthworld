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
    final handle = Get.parameters['handle'];

    if (channelId == null && (handle == null || !handle.startsWith('@'))) {
      Get.offAllNamed('/');
      return;
    }

    try {
      DocumentSnapshot? doc;
      if (channelId != null) {
        doc = await FirebaseFirestore.instance
            .collection('channels')
            .doc(channelId)
            .get();
      } else if (handle != null) {
        String cleanHandle = handle;
        if (cleanHandle.startsWith('@')) {
          cleanHandle = cleanHandle.substring(1);
        }
        final query = await FirebaseFirestore.instance
            .collection('channels')
            .where('handleLowercase', isEqualTo: cleanHandle.toLowerCase())
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          doc = query.docs.first;
        }
      }

      if (doc == null || !doc.exists) {
        Get.snackbar("Error", "Channel not found");
        Get.offAllNamed('/');
        return;
      }

      final channel = Channel.fromDocumentSnapshot(doc);

      Get.offNamed(channel.channelRoute, arguments: {"channel": channel});
      debugPrint("🧭 All route params: ${Get.parameters}");
    } catch (e) {
      Get.snackbar("Error", "Something went wrong: $e");
      Get.offAllNamed('/');
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





