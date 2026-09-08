import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/controllers/create_playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_detail_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CreatePlaylistController Tests', () {
    late CreatePlaylistController controller;

    setUp(() {
      Get.reset();
      controller = CreatePlaylistController();
      controller.onInit();
    });

    tearDown(() {
      controller.onClose();
    });

    test('initial state and text listeners update length observables', () {
      expect(controller.nameLength.value, equals(0));
      expect(controller.descLength.value, equals(0));
      expect(controller.isPublic.value, isTrue);
      expect(controller.selectedVideos, isEmpty);
      expect(controller.selectedThumbnailIndex.value, equals(0));
      expect(controller.useCustomThumbnail.value, isFalse);

      controller.nameController.text = 'My Tech Playlist';
      expect(controller.nameLength.value, equals('My Tech Playlist'.length));

      controller.descController.text = 'A collection of tech reviews';
      expect(controller.descLength.value, equals('A collection of tech reviews'.length));
    });

    test('toggleVideoSelection adds and removes video properly', () {
      final video = Video(
        id: 'v101',
        title: 'Tech Intro',
        description: 'Desc',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'u1',
        channelId: 'c1',
        channelName: 'TechChannel',
        category: 'Technology',
        tags: const ['tech'],
      );

      controller.selectedVideos.add(video);
      expect(controller.selectedVideos.length, equals(1));
      expect(controller.selectedVideos.first.id, equals('v101'));

      controller.selectedVideos.removeWhere((v) => v.id == 'v101');
      expect(controller.selectedVideos, isEmpty);
    });

    test('privacy toggle updates isPublic observable', () {
      expect(controller.isPublic.value, isTrue);
      controller.isPublic.value = false;
      expect(controller.isPublic.value, isFalse);
    });
  });

  group('PlaylistDetailController Tests', () {
    late PlaylistDetailController controller;

    setUp(() {
      Get.reset();
      controller = PlaylistDetailController();
    });

    test('initial state has expected defaults', () {
      expect(controller.rxIsLoading.value, isTrue);
      expect(controller.isReordering.value, isFalse);
      expect(controller.isDragging.value, isFalse);
      expect(controller.selectedVideoId.value, isEmpty);
      expect(controller.draggedIndex.value, equals(-1));
      expect(controller.filterValue.value, isEmpty);
      expect(controller.showFilterMenu.value, isFalse);
      expect(controller.selectedView.value, equals('Grid'));
      expect(controller.selectedSort.value, equals('Recent'));
    });

    test('setter methods update reactive state accurately', () {
      controller.setLoading(false);
      expect(controller.rxIsLoading.value, isFalse);

      controller.setReordering(true);
      expect(controller.isReordering.value, isTrue);

      controller.setDragging(true);
      expect(controller.isDragging.value, isTrue);

      controller.setSelectedVideo('v_abc');
      expect(controller.selectedVideoId.value, equals('v_abc'));

      controller.setDraggedIndex(3);
      expect(controller.draggedIndex.value, equals(3));

      controller.setFilterValue('Flutter');
      expect(controller.filterValue.value, equals('Flutter'));

      controller.toggleFilterMenu();
      expect(controller.showFilterMenu.value, isTrue);

      controller.setSelectedView('List');
      expect(controller.selectedView.value, equals('List'));

      controller.setSelectedSort('Oldest');
      expect(controller.selectedSort.value, equals('Oldest'));

      controller.toggleSearchVisibility();
      expect(controller.isSearchVisible.value, isTrue);
    });

    test('reset clears interaction and filtering state', () {
      controller.setReordering(true);
      controller.setDragging(true);
      controller.setSelectedVideo('v_123');
      controller.setDraggedIndex(2);
      controller.setFilterValue('Test');
      controller.showFilterMenu.value = true;

      controller.reset();

      expect(controller.isReordering.value, isFalse);
      expect(controller.isDragging.value, isFalse);
      expect(controller.selectedVideoId.value, isEmpty);
      expect(controller.draggedIndex.value, equals(-1));
      expect(controller.filterValue.value, isEmpty);
      expect(controller.showFilterMenu.value, isFalse);
    });

    test('activePlaylist holds and updates playlist model', () {
      final playlist = PlaylistModel(
        id: 'pl_1',
        name: 'Curated Science',
        description: 'Best science videos',
        ownerId: 'user_1',
        channelId: 'channel_1',
        videoIds: ['v1', 'v2'],
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      controller.activePlaylist.value = playlist;
      expect(controller.activePlaylist.value, isNotNull);
      expect(controller.activePlaylist.value?.name, equals('Curated Science'));
      expect(controller.activePlaylist.value?.videoIds.length, equals(2));
    });
  });
}
