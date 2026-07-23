
/// Central Feedback Service Hub
///
/// Provides convenient access to all feedback mechanisms:
/// - SnackbarService: Full-width notifications (3 seconds)
/// - ToastService: Quick notifications top-center (2 seconds)
/// - DialogService: Modal dialogs for critical feedback
///
/// Example Usage:
///   // Simple feedback
///   Feedback.success('Uploaded successfully');
///   Feedback.error('Upload failed');
///
///   // Confirmation
///   DialogService.confirm(
///     title: 'Delete video?',
///     message: 'This cannot be undone',
///   );
///
///   // Loading state
///   DialogService.loading(message: 'Processing...');
library;


export 'dialog_service.dart';
export 'snackbar_service.dart';
export 'toast_service.dart';





