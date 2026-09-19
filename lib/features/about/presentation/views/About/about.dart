import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/about/presentation/controllers/about_controller.dart';
import 'package:truthworld/features/about/presentation/views/About/widgets/about_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/about/presentation/controllers/about_controller.dart';
export 'package:truthworld/features/about/presentation/views/About/widgets/about_widgets.dart';

// Responsive Breakpoints
const double kMobileBreakpoint = 600;
const double kTabletBreakpoint = 1000;
const double kDesktopBreakpoint = 1200;

/// Declarative, responsive presentation screen for TruthWorld corporate information,
/// platform mission, verification pipeline, creator economics, and statutory grievance details.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key, this.isDashboard = false});

  final bool isDashboard;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AboutController>(
      init: AboutController(),
      builder: (controller) {
        return FadeTransition(
          opacity: controller.fadeAnimation,
          child: SlideTransition(
            position: controller.slideAnimation,
            child: ScaleTransition(
              scale: controller.scaleAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
                  final isTablet =
                      constraints.maxWidth >= kMobileBreakpoint &&
                      constraints.maxWidth < kDesktopBreakpoint;
                  final isMobile = constraints.maxWidth < kMobileBreakpoint;

                  return Scaffold(
                    backgroundColor: AppColors.bgPage,
                    appBar: !isDashboard
                        ? AboutModernAppBar(isTablet: isTablet)
                        : null,
                    body: SafeArea(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            AboutHeroSection(
                              isDesktop: isDesktop,
                              isTablet: isTablet,
                              isMobile: isMobile,
                            ),
                            AboutPlatformPillarsSection(
                              isDesktop: isDesktop,
                              isTablet: isTablet,
                              isMobile: isMobile,
                            ),
                            AboutVerificationPipelineSection(
                              isDesktop: isDesktop,
                              isTablet: isTablet,
                              isMobile: isMobile,
                            ),
                            AboutMonetizationSection(
                              isDesktop: isDesktop,
                              isTablet: isTablet,
                              isMobile: isMobile,
                            ),
                            AboutLeadershipSection(
                              isDesktop: isDesktop,
                              isTablet: isTablet,
                              isMobile: isMobile,
                            ),
                            AboutCorporateAndGrievanceSection(
                              isDesktop: isDesktop,
                              isTablet: isTablet,
                              isMobile: isMobile,
                            ),
                            AboutCTASection(
                              isDesktop: isDesktop,
                              isTablet: isTablet,
                              isMobile: isMobile,
                            ),
                            AboutFooterSection(
                              isDesktop: isDesktop,
                              isTablet: isTablet,
                              isMobile: isMobile,
                              onLaunchUrl: controller.launchExternalUrl,
                              onSendEmail: controller.sendEmail,
                              onCallPhone: controller.callPhone,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
