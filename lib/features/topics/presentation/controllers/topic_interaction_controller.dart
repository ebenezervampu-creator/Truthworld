import 'package:truthworld/features/topics/presentation/controllers/interaction/topic_interaction_barrel.dart';

export 'package:truthworld/features/topics/presentation/controllers/interaction/topic_interaction_barrel.dart';

/// Central controller coordinating Topic interactions including likes,
/// comments streaming & CRUD, replies, and comment/reply reactions.
class TopicInteractionController extends TopicInteractionStateBase
    with
        TopicLikeMixin,
        TopicCommentsCrudMixin,
        TopicRepliesCrudMixin,
        TopicCommentReactionsMixin,
        TopicReplyReactionsMixin {}
