import 'dart:async';

import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_mixins/channel_controller_base.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/data/repositories/topic_repository.dart';
import 'package:truthworld/features/video/data/models/video.dart';

mixin ChannelTopicsMixin on ChannelControllerBase {
  @override
  final TopicRepository topicRepository = TopicRepository();
  @override
  final Rxn<Topic> selectedChannelTopic = Rxn<Topic>();
  @override
  final RxMap<String, List<Video>> topicVideosMap = <String, List<Video>>{}.obs;
  @override
  final RxMap<String, bool> isLoadingVideosMap = <String, bool>{}.obs;
  @override
  final RxMap<String, List<CommunityPostModel>> topicPostsMap =
      <String, List<CommunityPostModel>>{}.obs;
  @override
  final RxMap<String, bool> isLoadingPostsMap = <String, bool>{}.obs;

  Future<void> fetchVideosForChannelTopic(Topic topic) async {
    final key = topic.id;
    if (topicVideosMap.containsKey(key) && isLoadingVideosMap[key] != true) {
      return;
    }
    isLoadingVideosMap[key] = true;
    try {
      var vids = await topicRepository.getVideosByTopic(topic.slug);
      if (vids.isEmpty && topic.id != topic.slug) {
        vids = await topicRepository.getVideosByTopic(topic.id);
      }
      topicVideosMap[key] = vids;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelTopicsMixin.fetchVideosForTopic',
      );
      topicVideosMap[key] = [];
    } finally {
      isLoadingVideosMap[key] = false;
    }
  }

  Future<void> fetchPostsForChannelTopic(Topic topic) async {
    final key = topic.id;
    if (topicPostsMap.containsKey(key) && isLoadingPostsMap[key] != true) {
      return;
    }
    isLoadingPostsMap[key] = true;
    try {
      var posts = await topicRepository.getCommunityPostsByTopic(topic.slug);
      if (posts.isEmpty && topic.id != topic.slug) {
        posts = await topicRepository.getCommunityPostsByTopic(topic.id);
      }
      topicPostsMap[key] = posts;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelTopicsMixin.fetchPostsForTopic',
      );
      topicPostsMap[key] = [];
    } finally {
      isLoadingPostsMap[key] = false;
    }
  }

  void selectChannelTopic(Topic? topic) {
    selectedChannelTopic.value = topic;
    if (topic != null) {
      fetchVideosForChannelTopic(topic);
      fetchPostsForChannelTopic(topic);
    }
  }


}
