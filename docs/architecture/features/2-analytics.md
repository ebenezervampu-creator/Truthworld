# Feature 2: Analytics

## Overview
The **Analytics** feature is one of the most complex, data-rich modules in the TruthWorld web application. It provides real-time and aggregated insights for content creators, detailing their audience retention, geographical reach, and watch time statistics.

## Frontend (UI/UX)
- **Location**: `lib/features/analytics/presentation/`
- **Pages**:
  - `creator_analytics_dashboard.dart`: The master dashboard aggregating multiple data points.
  - `subscribers_page.dart`, `views_page.dart`, `watch_time_page.dart`: Drill-down pages for specific metrics.
- **Widgets**:
  - Highly dynamic custom charts: `analytics_charts_widget.dart`, `retention_funnel_chart_widget.dart`.
  - Geographic insights: `geographic_map_widget.dart`, `geo_breakdown_widget.dart`.
  - Live data: `live_viewer_widget.dart`, `hourly_trend_widget.dart`.
- **UX Strategy**: Heavy use of `Obx` wrappers around charting libraries to ensure charts animate smoothly as new data is aggregated or date ranges are filtered.

## Backend & State Management
- **Controller**: `CreatorAnalyticsController`
- **State Management (GetX)**:
  - Manages reactive date ranges (`AnalyticsDateRange`, custom start/end dates).
  - Handles concurrent data fetching states (`isLoadingVideoAnalytics`, `isLoadingChannelAnalytics`).
  - Manages reactive chart lists (`watchtimeChartData`, `stateTrafficChartData`, `trafficSourceChartData`, `watchTimeTrendData`) to feed UI components.
- **Performance Optimization**: Specifically designed to "Read from pre-aggregated daily stats for cost efficiency" rather than querying massive raw collections per user session.

## Data & Domain Layer
- **Location**: `lib/features/analytics/data/`
- **Models**: `watch_event_model.dart` represents individual viewer interaction segments.
- **Services**:
  - `video_analytics_service.dart`: Interacts with Firebase Firestore to retrieve aggregated data.
  - `geolocation_service.dart`: Likely maps viewer IPs or provided region codes to physical map boundaries.
  - `impression_tracking_service.dart` & `viewer_identity_service.dart`: Tracks user funnels and unique impressions securely.
