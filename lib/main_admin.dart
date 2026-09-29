import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/main.dart' as app;

/// Entry point for the [AppFlavor.admin] flavor.
///
/// Delegates all bootstrap logic to [app.bootstrap] with a
/// forced initial route of '/admin/login', ensuring the Admin
/// panel is the landing page on native mobile builds.
void main() => app.bootstrap(flavor: AppFlavor.admin);
