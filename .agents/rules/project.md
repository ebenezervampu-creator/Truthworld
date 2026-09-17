---
trigger: always_on
description: Core project rules including icon colors and GetX state management standards
---

# Icon Color Guidelines
- Never use primary color or brand color (`AppColors.brand`, `AppColors.brandVariant`, `AppColors.brandHover`, `Theme.of(context).primaryColor`, etc.) in icons.
- Always use white (`Colors.white` or `AppColors.textPrimary`) for icons across the entire Truthworld project.

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
