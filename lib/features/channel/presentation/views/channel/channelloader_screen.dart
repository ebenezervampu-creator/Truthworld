import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/data/models/channel.dart';

class ChannelLoaderController extends BaseController {
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

    if (channelId == null && handle == null) {
      Get.back();
      return;
    }

    try {
      DocumentSnapshot? doc;
      final isHandleInChannelId =
          channelId != null && channelId.startsWith('@');

      if (channelId != null && !isHandleInChannelId) {
        doc = await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .get();
      }

      if ((doc == null || !doc.exists) &&
          (handle != null || isHandleInChannelId)) {
        var cleanHandle = handle ?? channelId!;
        if (cleanHandle.startsWith('@')) {
          cleanHandle = cleanHandle.substring(1);
        }
        while (cleanHandle.endsWith('.') ||
            cleanHandle.endsWith(',') ||
            cleanHandle.endsWith(')') ||
            cleanHandle.endsWith(']') ||
            cleanHandle.endsWith('!') ||
            cleanHandle.endsWith('?')) {
          cleanHandle = cleanHandle.substring(0, cleanHandle.length - 1);
        }

        final query = await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .where('handleLowercase', isEqualTo: cleanHandle.toLowerCase())
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          doc = query.docs.first;
        }
      }

      if (doc == null || !doc.exists) {
        final displayHandle = handle ?? channelId;
        Get.snackbar(
          'Channel Not Found',
          'No channel found for $displayHandle',
        );
        Get.back();
        return;
      }

      final channel = Channel.fromDocumentSnapshot(doc);
      Get.offNamed(channel.channelRoute, arguments: {'channel': channel});
      debugPrint('🧭 Channel loaded successfully: ${channel.channelName}');
    } catch (e) {
      Get.snackbar('Error', 'Failed to load channel: $e');
      Get.back();
    }
  }
}

class ChannelLoaderScreen extends StatelessWidget {
  const ChannelLoaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ChannelLoaderController>()) {
      Get.put(ChannelLoaderController());
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
