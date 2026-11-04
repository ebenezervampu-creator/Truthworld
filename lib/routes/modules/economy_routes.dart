import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/route_guards.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/features/premium/presentation/bindings/premium_binding.dart';
import 'package:truthworld/features/premium/presentation/views/premium_plans_screen.dart'
    deferred as premium_plans;
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/routes/app_transitions.dart';

/// Lightweight transparent handoff screen that auto-pops itself when payment deep links return.
class PaymentHandoffScreen extends StatelessWidget {
  const PaymentHandoffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Navigator.of(context).canPop()) {
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
