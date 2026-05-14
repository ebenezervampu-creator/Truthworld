// Unused import removed
// Quick Reference: Premium Feedback UI
//
// Use this guide to quickly choose the right feedback component for your use case
//
// â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• QUICK DECISION TREE â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
// â•‘                                                      â•‘
// â•‘  Need feedback?                                      â•‘
// â•‘  â”‚                                                   â•‘
// â•‘  â”œâ”€ Immediate (typing, validation)                  â•‘
// â•‘  â”‚  â””â”€ Use: ToastService (2 seconds)                â•‘
// â•‘  â”‚                                                   â•‘
// â•‘  â”œâ”€ Operation result (upload done, saved)           â•‘
// â•‘  â”‚  â”œâ”€ With action (undo, retry)?                   â•‘
// â•‘  â”‚  â”‚  â””â”€ Use: SnackbarService (3 seconds + action) â•‘
// â•‘  â”‚  â””â”€ Simple result?                               â•‘
// â•‘  â”‚     â””â”€ Use: ToastService (2 seconds)             â•‘
// â•‘  â”‚                                                   â•‘
// â•‘  â””â”€ Critical (delete, confirm, warning)             â•‘
// â•‘     â””â”€ Use: DialogService (modal, user driven)      â•‘
// â•‘                                                      â•‘
// â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// 1. TOAST SERVICE (Quick, 2 seconds, top-center)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//
// Best for: Immediate, non-critical feedback
// Position: Top-center (minimal disruption)
// Size: 320px (compact)
// Duration: 2 seconds (auto-dismiss)
// Actions: None
//
// When to use:
// â€¢ Form validation errors
// â€¢ Real-time feedback (typing, processing)
// â€¢ Status updates (50% uploaded)
// â€¢ Quick operations (saved, sent)
// â€¢ Progress milestones
//
// Examples:
//
// // Validation
// if (email.isEmpty) {
//   ToastService.error('Email is required');
// }
//
// // Progress
// ToastService.info('50% uploaded');
//
// // Status
// ToastService.success('Changes saved');
//
// // Loading
// ToastService.loading('Processing...');
//
// API:
// â€¢ ToastService.success(message)
// â€¢ ToastService.error(message)
// â€¢ ToastService.warning(message)
// â€¢ ToastService.info(message)
// â€¢ ToastService.loading(message)
// â€¢ ToastService.custom(message, icon, colors)
// â€¢ ToastService.dismissAll()

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// 2. SNACKBAR SERVICE (Standard, 3 seconds, bottom-center)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//
// Best for: Operation results with optional actions
// Position: Bottom-center (prominent)
// Size: 400px (visible)
// Duration: 3 seconds (configurable: 2s, 3s, 5s)
// Actions: Optional button (undo, retry, view, etc.)
//
// When to use:
// â€¢ Operation completion (upload done, video saved)
// â€¢ Success messages that might need undo
// â€¢ Errors that might need retry
// â€¢ Important status changes
// â€¢ Actionable results
//
// Examples:
//
// // Success with action
// SnackbarService.success(
//   message: 'Video uploaded',
//   actionLabel: 'View',
//   onAction: () => navigateToVideo(),
// );
//
// // Error with retry
// SnackbarService.error(
//   message: 'Upload failed',
//   actionLabel: 'Retry',
//   onAction: () => retryUpload(),
//   duration: SnackbarServiceDuration.long,
// );
//
// // Undo pattern
// SnackbarService.success(
//   message: 'Video liked',
//   actionLabel: 'Undo',
//   onAction: () => unlikeVideo(),
// );
//
// // Loading state
// SnackbarService.loading('Saving preferences...');
//
// API:
// â€¢ SnackbarService.success(message, actionLabel?, onAction?)
// â€¢ SnackbarService.error(message, actionLabel?, onAction?)
// â€¢ SnackbarService.warning(message)
// â€¢ SnackbarService.info(message)
// â€¢ SnackbarService.custom(message, colors, icon)
// â€¢ SnackbarService.loading(message)
// â€¢ SnackbarService.dismissAll()

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// 3. DIALOG SERVICE (Critical, modal, user-driven)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//
// Best for: Confirmations, critical decisions, warnings
// Position: Center (modal, requires interaction)
// Size: 400px (readable)
// Duration: None (user must act)
// Actions: Confirm + Cancel buttons
//
// When to use:
// â€¢ Destructive actions (delete, logout, reset)
// â€¢ Important confirmations (are you sure?)
// â€¢ Warnings before action
// â€¢ Required user acknowledgement
// â€¢ Long-running operations (loading dialog)
// â€¢ Custom content dialogs
//
// Examples:
//
// // Delete confirmation
// bool? result = await DialogService.confirm(
//   title: 'Delete video?',
//   message: 'This cannot be undone',
//   confirmLabel: 'Delete',
//   cancelLabel: 'Cancel',
// );
//
// // Error dialog
// await DialogService.error(
//   title: 'Upload Failed',
//   message: 'Network error occurred',
//   confirmLabel: 'Retry',
//   onConfirm: () => retryUpload(),
// );
//
// // Warning dialog
// await DialogService.warning(
//   title: 'Delete Account',
//   message: 'This will delete all your data permanently',
//   confirmLabel: 'Delete',
//   cancelLabel: 'Cancel',
//   onConfirm: () => deleteAccount(),
// );
//
// // Loading dialog
// DialogService.loading(message: 'Processing...');
// // Later: DialogService.close();
//
// // Info dialog
// await DialogService.info(
//   title: 'Success',
//   message: 'Operation completed',
//   confirmLabel: 'Got it',
// );
//
// // Custom content
// await DialogService.custom(
//   title: 'Report This',
//   content: ReportForm(),
//   confirmLabel: 'Send',
//   onConfirm: () => submitReport(),
// );
//
// API:
// â€¢ DialogService.success(title, message, confirmLabel?, onConfirm?)
// â€¢ DialogService.error(title, message, confirmLabel?, onConfirm?)
// â€¢ DialogService.warning(title, message, confirmLabel?, cancelLabel?, onConfirm?, onCancel?)
// â€¢ DialogService.confirm(title, message, confirmLabel?, cancelLabel?, onConfirm?, onCancel?)
// â€¢ DialogService.info(title, message, confirmLabel?, onConfirm?)
// â€¢ DialogService.loading(title?, message)
// â€¢ DialogService.custom(content, title?, confirmLabel?, cancelLabel?, barrierDismissible?)
// â€¢ DialogService.close()

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// COMPARISON TABLE
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//
// Feature              â”‚ Toast        â”‚ Snackbar     â”‚ Dialog
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Duration             â”‚ 2s           â”‚ 3s           â”‚ Modal (no auto)
// Position             â”‚ Top-center   â”‚ Bottom-centerâ”‚ Center
// Max Width            â”‚ 320px        â”‚ 400px        â”‚ 400px
// User Action          â”‚ None         â”‚ Optional     â”‚ Required
// Disruption Level     â”‚ Minimal      â”‚ Medium       â”‚ High
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Icons                â”‚ Yes          â”‚ Yes          â”‚ Yes (larger)
// Colors               â”‚ AppTheme.colors.primary  â”‚ AppTheme.colors.primary  â”‚ AppTheme.colors.primary
// Animation            â”‚ Fade + Slide â”‚ Fade + Slide â”‚ Scale + Fade
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Validation           â”‚ âœ“            â”‚ âœ—            â”‚ âœ—
// Progress             â”‚ âœ“            â”‚ âœ“            â”‚ âœ—
// Success + Action     â”‚ âœ—            â”‚ âœ“            â”‚ âœ“
// Confirmation         â”‚ âœ—            â”‚ âœ—            â”‚ âœ“
// Critical Warnings    â”‚ âœ—            â”‚ âœ“            â”‚ âœ“
// Destructive Actions  â”‚ âœ—            â”‚ âœ—            â”‚ âœ“
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Auto-dismiss         â”‚ Yes          â”‚ Yes          â”‚ No
// Stacks Multiple      â”‚ No (replace) â”‚ Rare         â”‚ Yes (modal)
// Dismissible          â”‚ Auto         â”‚ Auto or tap  â”‚ Button only
//

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// COLOR SYSTEM
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//
// All services use Crimson Noir theme:
//
// â€¢ Success (Green)    - AppTheme.colors.success (#10B981)
//   â””â”€ Use for: Operation successful, item saved, file uploaded
//
// â€¢ Error (Crimson)    - AppTheme.colors.error (#DC143C)
//   â””â”€ Use for: Operation failed, item deleted, connection error
//
// â€¢ Warning (Amber)    - AppTheme.colors.warning (golden)
//   â””â”€ Use for: Destructive action, confirmation needed, caution
//
// â€¢ Info (Blue)        - AppTheme.colors.info (#5B8DEF)
//   â””â”€ Use for: Status update, information, general feedback
//
// NEVER use other colors - always use AppTheme.colors.primary constants

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// COMMON PATTERNS
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//
// Pattern 1: Form Validation
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// if (email.isEmpty) {
//   ToastService.error('Email required');
//   return;
// }
//
// Pattern 2: Operation with Result
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// try {
//   await uploadVideo();
//   SnackbarService.success(
//     message: 'Video uploaded',
//     actionLabel: 'View',
//     onAction: () => viewVideo(),
//   );
// } catch (e) {
//   SnackbarService.error(
//     message: 'Upload failed',
//     actionLabel: 'Retry',
//     onAction: () => uploadVideo(),
//   );
// }
//
// Pattern 3: Confirmation Before Action
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// bool? confirmed = await DialogService.confirm(
//   title: 'Delete?',
//   message: 'This cannot be undone',
// );
// if (confirmed == true) {
//   performDelete();
// }
//
// Pattern 4: Loading with Completion
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// DialogService.loading(message: 'Processing...');
// try {
//   await operation();
//   DialogService.close();
//   SnackbarService.success('Complete');
// } catch (e) {
//   DialogService.close();
//   SnackbarService.error(message: 'Failed: $e');
// }
//
// Pattern 5: Undo Operation
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// void likeVideo() {
//   video.liked = true;
//   SnackbarService.success(
//     message: 'Video liked',
//     actionLabel: 'Undo',
//     onAction: () {
//       video.liked = false;
//       ToastService.info('Removed from likes');
//     },
//   );
// }

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// DO's and DON'Ts
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//
// âœ“ DO:
//   â€¢ Use Toast for immediate validation feedback
//   â€¢ Use Snackbar for operation results
//   â€¢ Use Dialog for confirmations
//   â€¢ Provide action buttons when possible (undo, retry)
//   â€¢ Keep messages short and clear
//   â€¢ Use appropriate colors (green=success, red=error)
//   â€¢ Dismiss loaders before showing results
//   â€¢ Set durations based on message length
//   â€¢ Always include icons for clarity
//   â€¢ Test on different screen sizes
//
// âœ— DON'T:
//   â€¢ Stack multiple feedback messages
//   â€¢ Use Dialog for validation (use Toast)
//   â€¢ Use Toast for critical actions (use Dialog)
//   â€¢ Create custom colors (use AppTheme.colors.primary)
//   â€¢ Show loading indefinitely (always close it)
//   â€¢ Make messages too long
//   â€¢ Ignore accessibility (contrast, size)
//   â€¢ Use feedback for navigation
//   â€¢ Show emoticon/emoji in messages
//   â€¢ Mix feedback services for same action

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// IMPLEMENTATION CHECKLIST
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//
// â–¡ Import feedback services:
//   import 'package:truthworld/core/services/feedback/feedback_service.dart';
//
// â–¡ Replace all custom snackbars with SnackbarService
// â–¡ Replace all custom dialogs with DialogService
// â–¡ Replace all custom toasts with ToastService
// â–¡ Verify all colors use AppTheme.colors.primary constants
// â–¡ Test on different screen resolutions
// â–¡ Check accessibility (tap targets, contrast)
// â–¡ Verify animations are smooth (200ms duration)
// â–¡ Add action buttons where appropriate
// â–¡ Document custom feedback patterns used
// â–¡ Get design review and approval

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// TROUBLESHOOTING
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//
// Issue: Snackbar/Dialog not appearing
// Fix:   Ensure GetMaterialApp is your root widget (not MaterialApp)
//
// Issue: Colors don't match AppTheme.colors.primary
// Fix:   Check you're using AppTheme.colors.success, not Colors.green
//
// Issue: Multiple toasts stacking
// Fix:   Call ToastService.dismissAll() before showing new one
//
// Issue: Dialog not closing
// Fix:   Call DialogService.close() or check barrierDismissible
//
// Issue: Text getting cut off
// Fix:   Keep messages brief (2 lines toast, 5 lines dialog)
//
// Issue: Actions not triggering
// Fix:   Verify onAction callback is passed and spelled correctly
//
// Issue: Loading dialog won't close
// Fix:   Must call DialogService.close() manually (no auto-dismiss)
//
// Issue: Wrong position of feedback
// Fix:   Toast = TOP, Snackbar = BOTTOM, Dialog = CENTER (automatic)

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// SUMMARY
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//
// 1. ToastService   â†’ Quick feedback (validation, progress)
// 2. SnackbarService â†’ Operation results (success, error with action)
// 3. DialogService   â†’ Confirmations (delete, logout, warning)
//
// Choose based on:
// â€¢ Time-criticality    â†’ Toast (immediate) â†’ Snackbar (result) â†’ Dialog (critical)
// â€¢ User interaction    â†’ Toast (none) â†’ Snackbar (optional) â†’ Dialog (required)
// â€¢ Message importance  â†’ Toast (low) â†’ Snackbar (medium) â†’ Dialog (high)
// â€¢ Screen disruption   â†’ Toast (minimal) â†’ Snackbar (medium) â†’ Dialog (high)
//
// All use AppTheme.colors.primary theme colors and premium animations.
// Always follow the patterns in INTEGRATION_EXAMPLES.dart
//
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•







