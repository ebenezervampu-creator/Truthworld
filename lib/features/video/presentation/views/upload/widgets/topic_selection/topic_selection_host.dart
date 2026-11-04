import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';

/// Contract interface defining the state and operations required by
/// [TopicSelectionBottomSheet] and its child components.
/// Ensures type-safety without relying on untyped `dynamic` reflection.
abstract class TopicSelectionHost {
  RxList<Topic> get availableTopics;
  RxBool get isTopicsLoading;
  RxString get topicSearchQuery;
  RxString get selectedTopicId;
  RxMap<String, dynamic> get newTopicData;
  RxList<String>? get selectedTopicIds => null;
  TextEditingController? get titleController => null;
  RxString? get selectedCategory => null;

  int get selectedOwnTopicsCount => 0;
  int get selectedPublicTopicsCount => 0;

  List<dynamic>? getRankedTopicsForCurrentVideo() => null;
  bool isOwnTopic(Topic topic) => false;

  void selectTopic(String id);
  void toggleTopicSelection(Topic topic);
  bool isTopicSelected(String key);
  Future<void> fetchAvailableTopics();
}
