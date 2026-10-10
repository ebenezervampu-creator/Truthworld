import 'package:get/get.dart';
import 'package:truthworld/features/content/presentation/bindings/copyright_complaint_binding.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/community_guidelines.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/copyright_complaint_screen.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/privacy_polices.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/terms.dart';
import 'package:truthworld/features/feedback/presentation/views/feedback/feedbacks.dart';
import 'package:truthworld/routes/app_routes.dart';

/// Terms of service, privacy policies, community guidelines, copyright complaints, and feedback routes.
class LegalRoutes {
  LegalRoutes._();

  static final List<GetPage> routes = [
    GetPage(
      name: AppRoutes.feedback,
      page: () => const SendFeedbackPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(SendFeedbackController.new);
      }),
    ),
    GetPage(
      name: AppRoutes.privacy,
      page: PrivacyPolicyScreen.new,
    ),
    GetPage(
      name: AppRoutes.terms,
      page: TermsAndConditionsPage.new,
    ),
    GetPage(
      name: AppRoutes.communityGuidelines,
      page: CommunityGuidelinesPage.new,
    ),
    GetPage(
      name: AppRoutes.copyrightComplaint,
      page: CopyrightComplaintScreen.new,
      binding: CopyrightComplaintBinding(),
    ),
    GetPage(
      name: AppRoutes.dmca,
      page: CopyrightComplaintScreen.new,
      binding: CopyrightComplaintBinding(),
    ),
  ];
}
