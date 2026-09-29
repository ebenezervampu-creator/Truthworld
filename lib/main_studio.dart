import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/main.dart' as app;

/// Entry point for the [AppFlavor.studio] flavor.
///
/// Delegates all bootstrap logic to [app.bootstrap] with a
/// forced initial route of '/studio', ensuring the Studio
/// dashboard is the landing page on native mobile builds
/// regardless of hostname-based routing.
void main() => app.bootstrap(flavor: AppFlavor.studio);
