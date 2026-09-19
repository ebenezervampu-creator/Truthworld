import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

/// Controller managing entry animations and external intent handlers for the About screen.
class AboutController extends BaseController with GetTickerProviderStateMixin {
  late AnimationController fadeAnimationController;
  late AnimationController slideAnimationController;
  late AnimationController scaleAnimationController;

  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;
  late Animation<double> scaleAnimation;

  @override
  void onInit() {
    super.onInit();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: fadeAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(
        parent: slideAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    scaleAnimation = Tween<double>(begin: 0.98, end: 1).animate(
      CurvedAnimation(
        parent: scaleAnimationController,
        curve: Curves.easeOutBack,
      ),
    );

    fadeAnimationController.forward();
    slideAnimationController.forward();
    scaleAnimationController.forward();
  }

  @override
  void onClose() {
    fadeAnimationController.dispose();
    slideAnimationController.dispose();
    scaleAnimationController.dispose();
    super.onClose();
  }

  Future<void> launchExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        ErrorHandler.log('Could not launch $url', tag: 'AboutController.launchExternalUrl');
        AppSnackbar.warning(
          'Could not open the requested webpage.',
          title: 'Unable to open link',
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'AboutController.launchExternalUrl');
      AppSnackbar.warning(
        'Could not open the requested webpage.',
        title: 'Unable to open link',
      );
    }
  }

  Future<void> sendEmail(String email) async {
    try {
      final uri = Uri(scheme: 'mailto', path: email);
      if (!await launchUrl(uri)) {
        ErrorHandler.log('Could not send email to $email', tag: 'AboutController.sendEmail');
        AppSnackbar.warning(
          'Could not open your email client.',
          title: 'Unable to send email',
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'AboutController.sendEmail');
      AppSnackbar.warning(
        'Could not open your email client.',
        title: 'Unable to send email',
      );
    }
  }

  Future<void> callPhone(String number) async {
    try {
      final uri = Uri(scheme: 'tel', path: number);
      if (!await launchUrl(uri)) {
        ErrorHandler.log('Could not call phone $number', tag: 'AboutController.callPhone');
        AppSnackbar.warning(
          'Could not open phone dialer.',
          title: 'Unable to make call',
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'AboutController.callPhone');
      AppSnackbar.warning(
        'Could not open phone dialer.',
        title: 'Unable to make call',
      );
    }
  }
}
