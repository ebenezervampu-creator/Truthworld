import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/features/premium/presentation/bindings/premium_binding.dart';
import 'package:truthworld/features/premium/presentation/views/premium_plans_screen.dart'
    deferred as premium_plans;
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/routes/app_transitions.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lightweight transparent handoff screen that auto-pops itself on payment return deep links,
/// or forwards direct hosted-checkout sessions on Web when opened with `session_id` + `order_id`.
class PaymentHandoffScreen extends StatelessWidget {
  const PaymentHandoffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final params = Get.parameters;
    final sessionId = params['session_id']?.trim() ?? '';
    final orderId = params['order_id']?.trim() ?? '';
    final action = params['action']?.trim().toLowerCase() ?? '';
    final isHostedSessionLaunch =
        kIsWeb && sessionId.isNotEmpty && orderId.isNotEmpty && action != 'result';

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (isHostedSessionLaunch) {
        final env = (params['env']?.trim().toLowerCase() == 'sandbox') ? 'sandbox' : 'production';
        final target = Uri.https('www.truthworld.in', '/checkout', {
          'session_id': sessionId,
          'order_id': orderId,
          'env': env,
        });
        await launchUrl(target, mode: LaunchMode.externalApplication);
      }
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
    return const SizedBox.shrink();
  }
}

/// Monetization, premium plans, creator wallet, checkout, and payment handoff routes.
class EconomyRoutes {
  EconomyRoutes._();

  static final List<GetPage> routes = [
    GetPage(
      name: AppRoutes.premium,
      page: () => DeferredWidget(
        loader: premium_plans.loadLibrary,
        builder: () => premium_plans.PremiumPlansScreen(),
      ),
      transition: AppTransitions.modal,
      transitionDuration: AppTransitions.modalDuration,
      curve: AppTransitions.modalCurve,
      binding: PremiumBinding(),
    ),
    GetPage(
      name: AppRoutes.paymentResult,
      page: () => const PaymentHandoffScreen(),
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
    ),
    GetPage(
      name: AppRoutes.checkout,
      page: () => const PaymentHandoffScreen(),
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
    ),
  ];
}
