import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/components/ui/community_post_card.dart';

void main() {
  group('CommunityPostCard reaction state', () {
    test('toggles like on and off without changing dislike state', () {
      const state = CommunityPostReactionState(
        likes: 10,
        dislikes: 2,
        likedBy: ['user-1'],
        dislikedBy: [],
        isLiked: true,
        isDisliked: false,
      );

      final updated = CommunityPostCardReactionEngine.toggleLike(state, 'user-2');

      expect(updated.likes, 11);
      expect(updated.dislikes, 2);
      expect(updated.isLiked, true);
      expect(updated.isDisliked, false);
      expect(updated.likedBy, contains('user-2'));
    });

    test('switches from dislike to like and keeps counts consistent', () {
      const state = CommunityPostReactionState(
        likes: 5,
        dislikes: 3,
        likedBy: [],
        dislikedBy: ['user-1'],
        isLiked: false,
        isDisliked: true,
      );

      final updated = CommunityPostCardReactionEngine.toggleLike(state, 'user-1');

      expect(updated.likes, 6);
      expect(updated.dislikes, 2);
      expect(updated.isLiked, true);
      expect(updated.isDisliked, false);
      expect(updated.likedBy, contains('user-1'));
      expect(updated.dislikedBy, isNot(contains('user-1')));
    });
  });
}
