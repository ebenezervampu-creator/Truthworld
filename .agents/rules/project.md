---
trigger: always_on
description: Core project rules including icon colors and GetX state management standards
---

# UI Contrast & Accessibility Guidelines (ZERO White-on-White Policy)
- **Brand & White Background Surfaces**:
  - TruthWorld uses `AppColors.brand = Color(0xFFFFFFFF)` (pure white accent).
  - Any button, badge, pill, or container with a white/brand background (`AppColors.brand`, `Colors.white`, or light opacity >= 0.6) MUST use black foreground:
    - Button foreground: `foregroundColor: Colors.black` (or `Colors.black87`).
    - Icons on white/brand surfaces MUST be `color: Colors.black` (or `Colors.black87`). NEVER use `Colors.white` or `AppColors.textPrimary` on white surfaces!
    - Text on white/brand surfaces MUST be `color: Colors.black` (or `Colors.black87`).
    - Loading spinners inside white buttons MUST be black (`CircularProgressIndicator(color: Colors.black)` or `AlwaysStoppedAnimation<Color>(Colors.black)`).
- **Dark Background Surfaces**:
  - On dark surfaces (`AppColors.bgPage`, `AppColors.bgSurface`, etc.), icons and text are white (`Colors.white`, `AppColors.textPrimary`).
  - Never use brand/primary color for icons on dark surfaces (maintain clean white iconography).
- **Dynamic Theme Adaptations**:
  - Any component that supports light mode or dynamic surfaces (`isDarkMode ? AppColors.bgSurface : Colors.white`) MUST dynamically adapt icon and text colors: `color: isDarkMode ? Colors.white : Colors.black87`. Never hardcode `Colors.white` inside dynamic containers.
- **Button Text Styles**:
  - `AppTextStyles.buttonText` defaults to `AppColors.textPrimary` (white). When using `AppTextStyles.buttonText` on white/brand buttons, you MUST specify `.copyWith(color: Colors.black)` or omit it and rely directly on the button's `foregroundColor: Colors.black`.
- **Contrast Guard Verification**:
  - Always run `flutter test test/core/ui_contrast_guard_test.dart` to verify that no white-on-white violations exist.

# State Management Guidelines
- **Zero `setState` Policy**: Never use `setState()` in any view, widget, or component across the entire Truthworld project.
- **GetX Only**: Use only GetX state management (`GetxController`, `Rx`, `Obx`, `GetBuilder`).
- **Declarative Views**: All screens and UI components must be `StatelessWidget`, `GetView<T>`, or `GetWidget<T>`. All mutable state, UI flags, and business logic belong exclusively inside `GetxController`.
- **Granular Reactivity**: Wrap only the specific micro-widgets that mutate inside `Obx(() => ...)`. Never wrap entire Scaffolds or large widget subtrees in `Obx`.
- **Scalable Performance & Low Latency**:
  - Use `GetBuilder<T>` with targeted IDs for high-throughput or complex batch rendering.
  - Use GetX workers (`debounce`, `throttle`, `ever`) in `onInit()` for high-frequency user interactions (search inputs, scrubbing, rapid taps).
  - Ensure strict memory safety: all streams, timers, and worker subscriptions must be disposed in `onClose()`.
  - Manage controller lifecycles via route-bound `Bindings` using `Get.lazyPut()` to scale memory efficiently.

# User Feedback & Snackbar Guidelines
- **Zero Raw Developer Error Policy**: Never expose `$e`, `e.toString()`, or technical exception codes to end users.
- **No Aggressive "Error" Titles**: Never use `'Error'`, `'Input Error'`, `'Validation Error'` as toast/snackbar titles. Present problems in friendly, polite, solution-oriented standard English.
- **Use `AppSnackbar` / `AppToast`**: Always route UI notifications through `AppSnackbar` (`AppSnackbar.error(...)`, `AppSnackbar.warning(...)`, `AppSnackbar.success(...)`, `AppSnackbar.info(...)`) or `AppToast`.
- **Automatic Sanitization**: All notifications are processed through `UserFeedbackSanitizer` to automatically intercept and cleanse any lingering technical tokens.
- **Icon Colors**: Feedback icons must always be white (`Colors.white`).

# Zero Charm-Pricing & Marketing Gimmick Guidelines
- **No Charm/Psychological Pricing (9, .99, 99, 999, 9999)**:
  - TruthWorld stands for absolute truth, transparency, and epistemic honesty.
  - Never use marketing gimmick numbers like $9, $9.99, $14.99, $29.99, $99, 9999, or .99 in any pricing, tier, credit, or UI display.
  - Always use clear, round, honest numbers ($10, $15, $20, $25, $30, $50, $100).
  - Creator trial credits and promotional bonuses must always show and award $10.00 (never $9.00). Legacy or accidental 9.0 trial credit must automatically normalize to the honest $10.00 standard.

