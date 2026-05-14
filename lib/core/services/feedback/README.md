# Premium Feedback UI System

A complete, theme-consistent feedback system for Tower VSP with three levels of user interaction: quick toasts, standard snackbars, and modal dialogs.

## Overview

The feedback system provides three complementary services for different use cases:

```
╔════════════════════════════════════════════════════════════════╗
║                   FEEDBACK SYSTEM                              ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║  [ToastService] (2s)                                           ║
║  ├─ Minimal feedback                                           ║
║  ├─ Top-center position (non-intrusive)                        ║
║  ├─ 320px width (compact)                                      ║
║  ├─ Auto-dismiss (2 seconds)                                   ║
║  └─ Methods: success(), error(), warning(), info(), loading()  ║
║                                                                ║
║  [SnackbarService] (3s)                                        ║
║  ├─ Standard feedback                                          ║
║  ├─ Bottom-center position (prominent)                         ║
║  ├─ 400px width (visible)                                      ║
║  ├─ Auto-dismiss (3 seconds)                                   ║
║  ├─ Action buttons support                                     ║
║  └─ Methods: success(), error(), warning(), info(), custom()   ║
║                                                                ║
║  [DialogService] (modal)                                       ║
║  ├─ Critical feedback                                          ║
║  ├─ Center position (requires interaction)                     ║
║  ├─ 400px width (readable)                                     ║
║  ├─ No auto-dismiss (user must act)                            ║
║  ├─ Icons and action buttons built-in                          ║
║  └─ Methods: success(), error(), warning(), confirm(), info()  ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

## Services

### 1. ToastService - Quick Feedback

**Use when:** You need immediate, non-intrusive feedback (validation, progress, status updates)

**Duration:** 2 seconds (or custom)

**Position:** Top-center (compact, floating)

**Size:** 320px max-width

**Methods:**
```dart
ToastService.success('Operation successful');
ToastService.error('Something went wrong');
ToastService.warning('Warning message');
ToastService.info('Info message');
ToastService.loading('Processing...');
ToastService.custom(
  message: 'Custom',
  icon: Icons.star,
  iconColor: Colors.amber,
  backgroundColor: Colors.amber.withOpacity(0.15),
  borderColor: Colors.amber.withOpacity(0.3),
);
ToastService.dismissAll();
```

**Examples:**
```dart
// Form validation
if (email.isEmpty) {
  ToastService.error('Email is required');
  return;
}

// Real-time feedback
ToastService.info('50% uploaded');

// Quick operations
ToastService.success('Saved');
```

**Color Scheme:**
- Success: YouTubeTheme.success (mint green, #10B981)
- Error: YouTubeTheme.error (crimson red, #DC143C)
- Warning: YouTubeTheme.warning (muted amber)
- Info: YouTubeTheme.info (steel blue, #5B8DEF)

---

### 2. SnackbarService - Standard Feedback

**Use when:** You need to show operation results (success, failure) with optional actions

**Duration:** 3 seconds (configurable: 2s short, 5s long)

**Position:** Bottom-center (prominent)

**Size:** 400px max-width

**Methods:**
```dart
SnackbarService.success(
  message: 'Video uploaded',
  actionLabel: 'View',
  onAction: () => navigateToVideo(),
);

SnackbarService.error(
  message: 'Upload failed',
  actionLabel: 'Retry',
  onAction: () => retryUpload(),
  duration: SnackbarServiceDuration.long,
);

SnackbarService.warning(
  message: 'This action cannot be undone',
  duration: SnackbarServiceDuration.long,
);

SnackbarService.info('New content available');

SnackbarService.loading('Processing your request...');

SnackbarService.custom(
  message: 'Custom message',
  backgroundColor: Colors.purple.withOpacity(0.15),
  borderColor: Colors.purple.withOpacity(0.3),
  icon: Icons.star,
  iconColor: Colors.purple,
  actionLabel: 'Action',
  onAction: () => print('Action triggered'),
);

SnackbarService.dismissAll();
```

**Duration Options:**
```dart
SnackbarServiceDuration.short  // 2 seconds
SnackbarServiceDuration.default // 3 seconds
SnackbarServiceDuration.long   // 5 seconds
```

**Examples:**
```dart
// Operation success with action
SnackbarService.success(
  message: 'Video liked',
  actionLabel: 'Undo',
  onAction: () => unlikeVideo(),
);

// Operation failure with retry
SnackbarService.error(
  message: 'Failed to load comments',
  actionLabel: 'Retry',
  onAction: () => loadComments(),
);

// Loading state
SnackbarService.loading('Saving preferences...');
```

**Color Scheme:**
- Success: YouTubeTheme.success (mint green)
- Error: YouTubeTheme.error (crimson red)
- Warning: YouTubeTheme.warning (muted amber)
- Info: YouTubeTheme.info (steel blue)

---

### 3. DialogService - Critical Feedback

**Use when:** You need user confirmation, validation, or showing critical information

**Duration:** No auto-dismiss (user must act)

**Position:** Center (modal)

**Size:** 400px max-width

**Methods:**
```dart
// Success confirmation
await DialogService.success(
  title: 'Success',
  message: 'Video uploaded successfully',
  confirmLabel: 'Done',
  onConfirm: () => print('Confirmed'),
);

// Error with recovery
await DialogService.error(
  title: 'Upload Failed',
  message: 'Network error. Please try again.',
  confirmLabel: 'Retry',
  onConfirm: () => retryUpload(),
);

// Warning with confirmation
await DialogService.warning(
  title: 'Delete Video?',
  message: 'This action cannot be undone',
  confirmLabel: 'Delete',
  cancelLabel: 'Cancel',
  onConfirm: () => deleteVideo(),
  onCancel: () => print('Cancelled'),
);

// Generic confirm dialog
bool? result = await DialogService.confirm(
  title: 'Logout',
  message: 'You will be logged out from all devices',
  confirmLabel: 'Logout',
  cancelLabel: 'Cancel',
  onConfirm: () => logout(),
  onCancel: () => print('Cancelled'),
);

// Info dialog
await DialogService.info(
  title: 'Information',
  message: 'Your account has been updated',
  confirmLabel: 'Got it',
  onConfirm: () => print('Acknowledged'),
);

// Loading dialog (non-dismissible)
DialogService.loading(
  title: 'Processing',
  message: 'Please wait while we process your request...',
);
// Later: DialogService.close();

// Custom dialog
await DialogService.custom(
  title: 'Custom Title',
  content: YourCustomWidget(),
  confirmLabel: 'Save',
  cancelLabel: 'Cancel',
  barrierDismissible: true,
  onConfirm: () => print('Confirmed'),
  onCancel: () => print('Cancelled'),
);

// Close dialog programmatically
DialogService.close();
DialogService.close(result: true); // With result
```

**Dialog Types:**

| Type | Icon | Color | Use Case |
|------|------|-------|----------|
| `success()` | ✓ | Green | Confirm successful action |
| `error()` | ✗ | Red | Error with recovery option |
| `warning()` | ⚠ | Amber | Destructive action confirmation |
| `confirm()` | ? | Blue | Generic yes/no question |
| `info()` | ℹ | Blue | Information display |
| `loading()` | ◉ | Red | Long-running operation |
| `custom()` | - | - | Custom content |

**Examples:**
```dart
// Delete confirmation
await DialogService.warning(
  title: 'Delete Account',
  message: 'This will permanently delete your account',
  confirmLabel: 'Delete My Account',
  cancelLabel: 'Cancel',
  onConfirm: () => deleteAccount(),
);

// Continue after error
await DialogService.error(
  title: 'Connection Error',
  message: 'Could not connect to server',
  confirmLabel: 'Retry',
  onConfirm: () => retry(),
);

// Blocking operation
DialogService.loading(message: 'Uploading video...');
// ... upload happens
DialogService.close();
SnackbarService.success('Upload complete');
```

---

## Color System

All feedback components use **YouTubeTheme** color constants:

```dart
// Color mappings
YouTubeTheme.success     // Mint green #10B981
YouTubeTheme.error       // Crimson red #DC143C
YouTubeTheme.warning     // Muted amber (golden)
YouTubeTheme.info        // Steel blue #5B8DEF
YouTubeTheme.deepCrimson // Primary accent #C41E3A
YouTubeTheme.cardBackground // #1A1A1A (dark theme)
YouTubeTheme.textPrimary // #FFFFFF (white text)
YouTubeTheme.textSecondary // Gray text

// Opacity variants for depth
Color bgColor = YouTubeTheme.success.withOpacity(0.15);  // Light background
Color borderColor = YouTubeTheme.success.withOpacity(0.3); // Medium border
```

---

## Design Specifications

### All Components

| Property | Value |
|----------|-------|
| Theme | Crimson Noir (dark, premium) |
| Font Family | Primary theme font |
| Max Width | 320px (Toast), 400px (Snackbar/Dialog) |
| Border Radius | 12px (Toast/Snackbar), 16px (Dialog) |
| Elevation/Shadow | 16px for dialog, 12px for snackbar, 8px for toast |
| Padding | 12px compact spacing |
| Icon Size | 20px (Snackbar/Toast), 48px (Dialog header) |
| Animation | 200ms easeOutCubic/easeInCubic |

### Toast

```
┌─────────────────────────┐
│ ✓ Message (max 2 lines) │  ← Top-center, compact
└─────────────────────────┘
```

- Width: 320px max
- Position: Top-center (SnackPosition.TOP)
- Padding: 12px all sides
- Border: 1px colored border
- Duration: 2 seconds (auto-dismiss)

### Snackbar

```
        ┌──────────────────────────┐
        │ ✓ Message with action    │  ← Bottom-center, visible
        │     [Action Button]      │
        └──────────────────────────┘
```

- Width: 400px max
- Position: Bottom-center (SnackPosition.BOTTOM)
- Padding: 20px with 16px border spacing
- Border: Colored accent border
- Duration: 3 seconds (configurable)
- Actions: Optional button with callback

### Dialog

```
╔════════════════════════════════════╗
║   ✓ Success (colored background)   ║  ← Centered modal
║                                    ║
║   Title                            ║
║   Message explaining the action    ║
║   ┌──────────────────────────┐    ║
║   │ Cancel      │   Confirm  │    ║
║   └──────────────────────────┘    ║
╚════════════════════════════════════╝
```

- Width: 400px (center)
- Position: Center (modal, barrierDismissible)
- Header: Icon + colored background (0.1 opacity)
- Content: Title + message + action buttons
- Buttons: Two-button layout (Cancel + Confirm)
- Footer: Divider line separating content from buttons

---

## Implementation Guide

### Step 1: Import Services

```dart
import 'package:towervsp/core/services/feedback/feedback_service.dart';

// Or import individual services:
import 'package:towervsp/core/services/feedback/snackbar_service.dart';
import 'package:towervsp/core/services/feedback/toast_service.dart';
import 'package:towervsp/core/services/feedback/dialog_service.dart';
```

### Step 2: Use in Your Pages

**Upload Page Example:**
```dart
class UploadPage extends StatefulWidget {
  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  Future<void> uploadVideo(File videoFile) async {
    try {
      // Show loading
      ToastService.loading('Preparing video...');

      // Simulate upload
      for (int i = 0; i <= 100; i += 25) {
        await Future.delayed(Duration(milliseconds: 500));
        if (i >= 50 && i < 75) {
          ToastService.dismissAll();
          ToastService.info('$i% uploaded');
        }
      }

      // Success
      ToastService.dismissAll();
      SnackbarService.success(
        message: 'Uploaded successfully',
        actionLabel: 'View',
        onAction: () => navigateToVideo(),
      );
    } catch (e) {
      ToastService.dismissAll();
      
      await DialogService.error(
        title: 'Upload Failed',
        message: e.toString(),
        confirmLabel: 'Retry',
        onConfirm: () => uploadVideo(videoFile),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Upload Video')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Trigger upload
            uploadVideo(videoFile);
          },
          child: Text('Upload'),
        ),
      ),
    );
  }
}
```

**Settings Page Example:**
```dart
Future<void> deleteAccount() async {
  bool? confirmed = await DialogService.confirm(
    title: 'Delete Account?',
    message: 'This action cannot be undone',
    confirmLabel: 'Delete',
    cancelLabel: 'Cancel',
  );

  if (confirmed == true) {
    DialogService.loading(message: 'Deleting account...');
    
    try {
      await accountService.deleteAccount();
      DialogService.close();
      SnackbarService.success('Account deleted');
      // Navigate to login
    } catch (e) {
      DialogService.close();
      ToastService.error('Deletion failed: $e');
    }
  }
}
```

---

## Best Practices

### ✅ DO

- **Use Toast for quick validation** - Form errors, real-time feedback
- **Use Snackbar for results** - Operation complete, success/error
- **Use Dialog for confirmation** - Destructive actions, critical decisions
- **Provide undo/retry actions** - Allow users to recover from errors
- **Dismiss loaders before results** - Never show loading + result simultaneously
- **Use consistent colors** - Green=success, Red=error, Amber=warning, Blue=info
- **Keep messages brief** - "Video uploaded" not "Your video file has been processed and uploaded to our servers"
- **Set appropriate durations** - Quick feedback (2s), normal (3s), errors (5s)

### ❌ DON'T

- **Stack multiple feedbacks** - Use `dismissAll()` before showing new one
- **Use wrong service level** - Don't use Dialog for validation, Toast for deletions
- **Create custom colors** - Always use YouTubeTheme constants
- **Ignore accessibility** - Provide icons, clear text, good contrast
- **Forget to handle timeouts** - Always have error handling
- **Make messages too long** - Toast max 2 lines, Dialog max 5 lines
- **Use feedback for navigation** - Use proper navigation, not feedback UI

---

## Common Patterns

### Pattern 1: Form Validation

```dart
void submitForm() {
  if (email.isEmpty) {
    ToastService.error('Email is required');
    return;
  }
  if (!isValidEmail(email)) {
    ToastService.error('Invalid email format');
    return;
  }
  
  performSubmit();
}
```

### Pattern 2: Async Operation with Feedback

```dart
Future<void> saveSettings() async {
  ToastService.loading('Saving...');
  
  try {
    await settingsService.save();
    ToastService.dismissAll();
    ToastService.success('Settings saved');
  } catch (e) {
    ToastService.dismissAll();
    SnackbarService.error(
      message: 'Save failed: $e',
      actionLabel: 'Retry',
      onAction: () => saveSettings(),
    );
  }
}
```

### Pattern 3: Undo Action

```dart
void likeVideo() {
  video.liked = true;
  
  SnackbarService.success(
    message: 'Video liked',
    actionLabel: 'Undo',
    onAction: () {
      video.liked = false;
      ToastService.info('Removed from likes');
    },
  );
}
```

### Pattern 4: Destructive Confirmation

```dart
Future<void> deleteVideo() async {
  bool? confirmed = await DialogService.warning(
    title: 'Delete Video?',
    message: 'This action cannot be undone',
    confirmLabel: 'Delete',
    cancelLabel: 'Cancel',
  );
  
  if (confirmed == true) {
    await videoService.delete(videoId);
    SnackbarService.success('Video deleted');
  }
}
```

### Pattern 5: Loading State

```dart
Future<void> loadComments() async {
  DialogService.loading(message: 'Loading comments...');
  
  try {
    comments = await commentService.fetch();
    DialogService.close();
    
    if (comments.isEmpty) {
      ToastService.info('No comments yet');
    }
  } catch (e) {
    DialogService.close();
    SnackbarService.error(
      message: 'Failed to load comments',
      actionLabel: 'Retry',
      onAction: () => loadComments(),
    );
  }
}
```

---

## File Structure

```
lib/core/services/feedback/
├── snackbar_service.dart      # Standard bottom-center feedback
├── toast_service.dart         # Quick top-center feedback
├── dialog_service.dart        # Modal dialogs and confirmations
├── feedback_service.dart      # Central hub (exports all)
├── INTEGRATION_EXAMPLES.dart  # Real-world usage patterns
└── README.md                  # This file
```

---

## Testing

Test each feedback type in your app:

```dart
void testFeedbackSystem() {
  // Test Toast
  ToastService.success('Toast: Success');
  Future.delayed(Duration(seconds: 3), () {
    ToastService.error('Toast: Error');
  });

  // Test Snackbar
  Future.delayed(Duration(seconds: 6), () {
    SnackbarService.success(
      message: 'Snackbar: Success with action',
      actionLabel: 'Action',
      onAction: () => print('Action tapped'),
    );
  });

  // Test Dialog
  Future.delayed(Duration(seconds: 10), () {
    DialogService.info(
      title: 'Dialog: Information',
      message: 'This is a test dialog',
      confirmLabel: 'OK',
    );
  });
}
```

---

## Troubleshooting

**Q: Snackbar not appearing?**
A: Ensure you have `GetMaterialApp` in your main.dart (required for GetX)

**Q: Colors not matching YouTubeTheme?**
A: Always use constants from `YouTubeTheme` class, not hardcoded colors

**Q: Multiple toasts stacking?**
A: Call `ToastService.dismissAll()` before showing a new one

**Q: Dialog not dismissing?**
A: Call `DialogService.close()` or check if barrierDismissible is true

**Q: Text gets cut off?**
A: Messages max 2 lines for toast, 5 for snackbar/dialog. Keep brief.

---

## Summary

| Use Case | Service | Duration | Position |
|----------|---------|----------|----------|
| Form error | Toast | 2s | Top-center |
| Validation | Toast | 2s | Top-center |
| Progress update | Toast | 2s | Top-center |
| Success with action | Snackbar | 3s | Bottom-center |
| Error with retry | Snackbar | 5s | Bottom-center |
| Confirmation | Dialog | Modal | Center |
| Critical action | Dialog | Modal | Center |
| Error recovery | Dialog | Modal | Center |

---

**Created:** 2024
**Version:** 1.0
**Theme:** Crimson Noir
**Status:** Complete and production-ready

