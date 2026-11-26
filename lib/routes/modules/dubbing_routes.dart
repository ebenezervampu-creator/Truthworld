import 'package:get/get.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/features/dubbing/presentation/bindings/dubbing_binding.dart';
import 'package:truthworld/features/dubbing/presentation/views/dubbing_studio_screen.dart'
    deferred as dubbing_studio;
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/routes/app_transitions.dart';

/// Standalone TruthWorld Dubbing Studio routes.
class DubbingRoutes {
  DubbingRoutes._();

  static final List<GetPage> routes = [
    GetPage(
      name: AppRoutes.dubbing,
      binding: DubbingBinding(),
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
      page: () => DeferredWidget(
        loader: dubbing_studio.loadLibrary,
        builder: () => dubbing_studio.DubbingStudioScreen(),
      ),
    ),
    GetPage(
      name: AppRoutes.dubbingEditorWithId,
      binding: DubbingBinding(),
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
      page: () => DeferredWidget(
        loader: dubbing_studio.loadLibrary,
        builder: () => dubbing_studio.DubbingStudioScreen(),
      ),
    ),
    GetPage(
      name: AppRoutes.dubbingSubtitles,
      binding: DubbingBinding(),
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
      page: () => DeferredWidget(
        loader: dubbing_studio.loadLibrary,
        builder: () => dubbing_studio.DubbingStudioScreen(),
      ),
    ),
  ];
}
