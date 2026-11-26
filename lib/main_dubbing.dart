import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/main.dart' as app;

/// Entry point for the [AppFlavor.dubbing] flavor.
///
/// Delegates all bootstrap logic to [app.bootstrap] with a
/// forced initial route of '/dubbing', ensuring the Dubbing Studio
/// is the landing page on native mobile builds and web builds.
void main() => app.bootstrap(flavor: AppFlavor.dubbing);
