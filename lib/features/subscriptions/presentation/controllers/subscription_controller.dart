import 'package:truthworld/features/subscriptions/presentation/controllers/subscriptions/subscription_barrel.dart';

export 'package:truthworld/features/subscriptions/presentation/controllers/subscriptions/subscription_barrel.dart';

/// Coordinator controller for user subscriptions and multi-content feed aggregation.
///
/// Composed of:
/// - [SubscriptionStateBase]: Core observables, enums, reactive filters, and lifecycle management.
/// - [SubscriptionActionsMixin]: Multi-source subscription loading, deduplication, and subscribe/unsubscribe transactions.
/// - [SubscriptionContentIngestionMixin]: Multi-content feed aggregation (feed inbox, videos, playlists, community posts, topics).
/// - [SubscriptionFiltersMixin]: Refresh orchestration, duration/type/date filters, and algorithmic sorting.
class SubscriptionController extends SubscriptionStateBase
    with
        SubscriptionActionsMixin,
        SubscriptionContentIngestionMixin,
        SubscriptionFiltersMixin {}
