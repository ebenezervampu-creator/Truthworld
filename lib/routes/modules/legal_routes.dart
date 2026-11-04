import 'package:get/get.dart';
import 'package:truthworld/features/content/presentation/bindings/copyright_complaint_binding.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/community_guidelines.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/copyright_complaint_screen.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/privacy_polices.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/terms.dart';
import 'package:truthworld/features/feedback/presentation/views/feedback/feedbacks.dart';
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/routes/app_transitions.dart';

/// Terms of service, privacy policies, community guidelines, copyright complaints, and feedback routes.
class LegalRoutes {
  LegalRoutes._();

  static final List<GetPage> routes = [
    GetPage(
      name: AppRoutes.feedback,
      page: () => const SendFeedbackPage(),
      transition: AppTransitions.modal,
      transitionDuration: AppTransitions.modalDuration,
      curve: AppTransitions.modalCurve,
      binding: BindingsBuilder(() {
        Get.lazyPut(SendFeedbackController.new);
      }),
    ),
    GetPage(
      name: AppRoutes.privacy,
      page: PrivacyPolicyScreen.new,
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
    ),
    GetPage(
      name: AppRoutes.terms,
      page: TermsAndConditionsPage.new,
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
    ),
    GetPage(
      name: AppRoutes.communityGuidelines,
      page: CommunityGuidelinesPage.new,
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
    ),
    GetPage(
      name: AppRoutes.copyrightComplaint,
      page: CopyrightComplaintScreen.new,
      transition: AppTransitions.modal,
      transitionDuration: AppTransitions.modalDuration,
      curve: AppTransitions.modalCurve,
      binding: CopyrightComplaintBinding(),
    ),
    GetPage(
      name: AppRoutes.dmca,
      page: CopyrightComplaintScreen.new,
      transition: AppTransitions.modal,
      transitionDuration: AppTransitions.modalDuration,
      curve: AppTransitions.modalCurve,
      binding: CopyrightComplaintBinding(),
    ),
  ];
}
