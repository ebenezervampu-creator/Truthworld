# 🎬 Truthworld UI Optimization Guide
## Production-Grade Video Platform Frontend Architecture

---

## 📋 Table of Contents
1. [Design Token System](#design-token-system)
2. [Component Architecture](#component-architecture)
3. [Performance Optimization](#performance-optimization)
4. [Accessibility Standards](#accessibility-standards)
5. [Layout System](#layout-system)
6. [Best Practices](#best-practices)
7. [Migration Guide](#migration-guide)

---

## 🎨 Design Token System

### Token Categories

#### 1. **Spacing Tokens** `AppTokens.spacing`
All spacing must use these values (8px grid):
```dart
AppTokens.spacing.xs   // 8px
AppTokens.spacing.sm   // 16px
AppTokens.spacing.md   // 24px
AppTokens.spacing.lg   // 32px
AppTokens.spacing.xl   // 40px
AppTokens.spacing.xxl  // 48px
```

**Rule**: Never hardcode padding, margin, or width/height values for spacing.

#### 2. **Color Tokens** `AppTokens.colors`
All colors must use tokens:
```dart
AppTokens.colors.primary        // Crimson
AppTokens.colors.background     // Deep noir
AppTokens.colors.surface        // Card background
AppTokens.colors.textPrimary    // Main text
AppTokens.colors.textSecondary  // Secondary text
AppTokens.colors.success        // Success green
AppTokens.colors.error          // Error red
AppTokens.colors.warning        // Warning amber
AppTokens.colors.info           // Info blue
AppTokens.colors.border         // Border color
AppTokens.colors.divider        // Divider color
```

#### 3. **Typography Tokens** `AppTokens.typography`
All text styles must use tokens:
```dart
AppTokens.typography.h1         // Display Large
AppTokens.typography.h2         // Headline Large
AppTokens.typography.h3         // Title Large
AppTokens.typography.body       // Body Large
AppTokens.typography.bodyMedium // Body Medium
AppTokens.typography.caption    // Body Small
AppTokens.typography.label      // Label Large
```

#### 4. **Radius Tokens** `AppTokens.radius`
All border radius must use tokens:
```dart
AppTokens.radius.sm          // 4px
AppTokens.radius.md          // 8px
AppTokens.radius.lg          // 16px
AppTokens.radius.xl          // 20px
AppTokens.radius.circularSm  // BorderRadius.circular(4px)
AppTokens.radius.circularMd  // BorderRadius.circular(8px)
AppTokens.radius.circularLg  // BorderRadius.circular(16px)
```

#### 5. **Size Tokens** `AppTokens.sizes`
For icons, avatars, and specific dimensions:
```dart
// Icon sizes
AppTokens.sizes.iconXs        // 16px
AppTokens.sizes.iconSm        // 20px
AppTokens.sizes.iconMd        // 24px
AppTokens.sizes.iconLg        // 32px
AppTokens.sizes.iconXl        // 48px

// Avatar sizes
AppTokens.sizes.avatarXs      // 24px
AppTokens.sizes.avatarSm      // 32px
AppTokens.sizes.avatarMd      // 40px
AppTokens.sizes.avatarLg      // 56px
AppTokens.sizes.avatarXl      // 80px

// Image thumbnail sizes & caching
AppTokens.sizes.thumbnailSmallWidth     // 120px
AppTokens.sizes.thumbnailSmallHeight    // 68px
AppTokens.sizes.thumbnailMediumWidth    // 160px
AppTokens.sizes.thumbnailMediumHeight   // 90px
AppTokens.sizes.imageCacheMediumWidth   // 400px (for memory cache)
AppTokens.sizes.imageCacheMediumHeight  // 300px
```

#### 6. **Shadow Tokens** `AppTokens.shadows`
For elevation effects:
```dart
AppTokens.shadows.elevationSm   // Subtle shadow
AppTokens.shadows.elevationMd   // Medium shadow
AppTokens.shadows.elevationLg   // Strong shadow
AppTokens.shadows.elevationXl   // Extra strong shadow
```

#### 7. **Animation Tokens** `AppTokens.animations`
For smooth, consistent transitions:
```dart
// Durations
AppTokens.animations.fast       // 100ms
AppTokens.animations.normal     // 200ms
AppTokens.animations.slow       // 300ms
AppTokens.animations.slower     // 500ms

// Curves
AppTokens.animations.easeIn
AppTokens.animations.easeOut
AppTokens.animations.easeInOut
AppTokens.animations.easeOutCubic
AppTokens.animations.easeOutBack
```

#### 8. **Component Tokens** `AppTokens.components`
Pre-calculated padding for common components:
```dart
AppTokens.components.buttonPaddingSmall     // Small buttons
AppTokens.components.buttonPaddingMedium    // Medium buttons
AppTokens.components.buttonPaddingLarge     // Large buttons
AppTokens.components.cardPadding            // Card default padding
AppTokens.components.chipPadding            // Chip padding
AppTokens.components.inputPadding           // Input field padding
AppTokens.components.gridSpacing            // Grid spacing (16px)
```

---

## 🧩 Component Architecture

### Core UI Components

#### BaseCard
Reusable card wrapper with elevation, border, and hover effects.

**Usage**:
```dart
BaseCard(
  onTap: () => print('Tapped'),
  semanticLabel: 'Video card',
  child: Column(
    children: [/* content */],
  ),
)
```

**Features**:
- Consistent styling using tokens
- Hover effect support
- Tap/double-tap callbacks
- Semantic accessibility labels
- Custom padding, borders, shadows

#### PrimaryButton
Standardized button component with multiple variants and sizes.

**Variants**: `primary`, `secondary`, `danger`, `ghost`, `icon`
**Sizes**: `small`, `medium`, `large`

**Usage**:
```dart
PrimaryButton(
  label: 'Play',
  icon: Icons.play_arrow,
  variant: ButtonVariant.primary,
  size: ButtonSize.medium,
  onPressed: () => playVideo(),
  isLoading: isLoading,
)
```

#### IconButtonCustom
Consistent icon button with variants and loading state.

**Variants**: `primary`, `secondary`, `danger`, `ghost`
**Sizes**: `small`, `medium`, `large`

**Usage**:
```dart
IconButtonCustom(
  icon: Icons.favorite,
  variant: IconButtonVariant.danger,
  size: IconButtonSize.medium,
  onPressed: () => toggleLike(),
  tooltip: 'Like video',
)
```

#### CategoryChip
Selection chip for categories with visual feedback.

**Usage**:
```dart
CategoryChip(
  label: 'Action',
  isSelected: selectedCategory == 'Action',
  onTap: () => selectCategory('Action'),
)
```

#### LoadingState
Consistent loading indicator.

**Sizes**: `small`, `medium`, `large`

**Usage**:
```dart
LoadingState(
  size: LoadingSize.medium,
  semanticLabel: 'Loading videos',
)
```

#### SkeletonLoader
Animated placeholder for content loading.

**Usage**:
```dart
SkeletonLoader(
  width: 160,
  height: 90,
  borderRadius: AppTokens.radius.lg,
)
```

#### ResponsiveGrid
Token-based responsive grid system.

**Usage**:
```dart
ResponsiveGrid(
  children: videos.map((v) => VideoCard(video: v)).toList(),
  columnsDesktop: 4,
  columnsTablet: 3,
  columnsMobile: 2,
)
```

#### LayoutContainer
Responsive container for max-width and padding.

**Usage**:
```dart
LayoutContainer(
  maxWidth: 1400,
  child: Column(
    children: [/* content */],
  ),
)
```

#### ContentSection
Standardized section wrapper.

**Usage**:
```dart
ContentSection(
  semanticLabel: 'Featured Videos',
  padding: EdgeInsets.all(AppTokens.spacing.md),
  child: Text('Featured content'),
)
```

---

## ⚡ Performance Optimization

### 1. Image Optimization

**For CachedNetworkImage**:
```dart
CachedNetworkImage(
  imageUrl: url,
  // Use token-based cache sizes
  memCacheWidth: AppTokens.sizes.imageCacheMediumWidth,
  memCacheHeight: AppTokens.sizes.imageCacheMediumHeight,
  placeholder: (context, url) => SkeletonLoader(
    width: 160,
    height: 90,
  ),
  errorWidget: (context, url, error) => Icon(Icons.error),
)
```

**Cache Sizes Strategy**:
- **Small thumbnails**: `imageCacheSmallWidth/Height` (300×200)
- **Medium thumbnails**: `imageCacheMediumWidth/Height` (400×300)
- **Large thumbnails**: `imageCacheLargeWidth/Height` (600×450)

### 2. Widget Memoization

Use `@immutable` annotation for performance:
```dart
@immutable
class MyComponent extends StatelessWidget {
  final String data;
  
  const MyComponent({required this.data});
  
  @override
  Widget build(BuildContext context) => Text(data);
}
```

### 3. Lazy Loading

Implement lazy loading for lists:
```dart
GridView.builder(
  itemBuilder: (context, index) {
    return FutureBuilder(
      future: loadVideo(index),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return VideoCard(video: snapshot.data!);
        }
        return SkeletonLoader(width: 160, height: 90);
      },
    );
  },
)
```

### 4. Use const Constructors

Always use `const` where possible:
```dart
// ✅ Good
const SizedBox(height: AppTokens.spacing.sm)

// ❌ Avoid
SizedBox(height: AppTokens.spacing.sm)
```

---

## ♿ Accessibility Standards

### 1. Semantic Labels
All interactive elements must have semantic labels:
```dart
Semantics(
  button: true,
  label: 'Play video: ${video.title}',
  enabled: true,
  child: GestureDetector(
    onTap: playVideo,
    child: Icon(Icons.play_arrow),
  ),
)
```

### 2. Alt Text for Images
```dart
Image.network(
  url,
  semanticLabel: 'Video thumbnail: ${video.title}',
)
```

### 3. Minimum Touch Target
Ensure minimum 48px touch targets:
```dart
// ✅ Good (48px minimum)
SizedBox(
  width: AppTokens.sizes.minimumTouchTarget,
  height: AppTokens.sizes.minimumTouchTarget,
  child: IconButton(icon: Icon(Icons.favorite)),
)
```

### 4. Color Contrast
All text colors must meet WCAG AA standards (4.5:1 contrast ratio).
The Crimson Noir theme is pre-validated for contrast.

### 5. Keyboard Navigation
All buttons and interactive elements must be keyboard accessible:
```dart
// Use onKey callbacks for keyboard support
Focus(
  onKey: (node, event) {
    if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
      onAction();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  },
  child: button,
)
```

---

## 🎎 Layout System

### Responsive Breakpoints
```dart
// Mobile: < 768px
// Tablet: 768px - 1200px
// Desktop: >= 1200px
```

### Responsive Sizing
```dart
@override
Widget build(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  final isMobile = width < 768;
  final isTablet = width >= 768 && width < 1200;
  final isDesktop = width >= 1200;
  
  return /* content based on breakpoint */;
}
```

### Sidebar Layout
```dart
Row(
  children: [
    // Sidebar with fixed width
    SizedBox(
      width: AppTokens.sizes.sidebarWidth,
      child: StandardSidebar(items: items),
    ),
    // Main content area
    Expanded(
      child: mainContent,
    ),
  ],
)
```

---

## ✅ Best Practices

### 1. NO Hardcoded Values
```dart
// ❌ Bad
Container(
  width: 160,
  height: 90,
  padding: EdgeInsets.all(16),
  margin: EdgeInsets.only(bottom: 24),
)

// ✅ Good
Container(
  width: AppTokens.sizes.thumbnailMediumWidth,
  height: AppTokens.sizes.thumbnailMediumHeight,
  padding: AppTokens.components.cardPadding,
  margin: EdgeInsets.only(bottom: AppTokens.spacing.md),
)
```

### 2. Use Const Constructors
```dart
// ✅ Good - const everywhere possible
const VideoCard(video: video)

// Consider using @immutable on classes
@immutable
class VideoModel {
  // ...
}
```

### 3. Consistent Spacing Scale
```dart
// ✅ Good - using 8px grid
padding: EdgeInsets.all(AppTokens.spacing.md) // 24px
margin: EdgeInsets.only(bottom: AppTokens.spacing.sm) // 16px

// ❌ Avoid - random values
padding: EdgeInsets.all(15) // 15px is not on grid
margin: EdgeInsets.only(bottom: 18) // 18px is not on grid
```

### 4. Accessibility First
- Always add semantic labels to interactive elements
- Use meaningful button labels (not "OK", use "Save Changes")
- Ensure text contrast is at least 4.5:1 (AA standard)

### 5. Animation Consistency
```dart
// ✅ Good - use animation tokens
AnimatedContainer(
  duration: AppTokens.animations.normal,
  curve: AppTokens.animations.easeOutCubic,
)

// ❌ Avoid
AnimatedContainer(
  duration: Duration(milliseconds: 250),
  curve: Curves.easeOut,
)
```

### 6. Component Composition
```dart
// ✅ Good - reuse BaseCard
BaseCard(
  onTap: onTap,
  child: content,
)

// ❌ Avoid
Container(
  decoration: BoxDecoration(/* custom styling */),
  child: GestureDetector(
    onTap: onTap,
    child: content,
  ),
)
```

---

## 📖 Migration Guide

### Step 1: Replace Hardcoded Values

**Before**:
```dart
Padding(
  padding: EdgeInsets.all(16),
  // ...
)
```

**After**:
```dart
Padding(
  padding: EdgeInsets.all(AppTokens.spacing.sm),
  // ...
)
```

### Step 2: Use Reusable Components

**Before**:
```dart
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.grey[900],
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text('Label'),
)
```

**After**:
```dart
ContentSection(
  child: Text('Label'),
)
```

### Step 3: Add Component Tokens

Replace custom styling with component tokens:

**Before**:
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    backgroundColor: Colors.red,
  ),
)
```

**After**:
```dart
PrimaryButton(
  label: 'Action',
  variant: ButtonVariant.primary,
  size: ButtonSize.medium,
)
```

### Step 4: Ensure Accessibility

Add semantic labels to all interactive elements:

**Before**:
```dart
IconButton(icon: Icon(Icons.favorite))
```

**After**:
```dart
Semantics(
  button: true,
  label: 'Like this video',
  child: IconButton(icon: Icon(Icons.favorite)),
)
```

---

## 📊 Consistency Checklist

Before committing code, verify:

- [ ] No hardcoded spacing values (use `AppTokens.spacing.*`)
- [ ] No hardcoded colors (use `AppTokens.colors.*`)
- [ ] No hardcoded font sizes (use `AppTokens.typography.*`)
- [ ] No hardcoded border radius (use `AppTokens.radius.*`)
- [ ] All interactive elements have semantic labels
- [ ] Image cache sizes use tokens
- [ ] Button variants are from `ButtonVariant` enum
- [ ] Animation durations use tokens
- [ ] All components are `@immutable`
- [ ] Responsive design tested on mobile, tablet, desktop

---

## 🚀 Performance Metrics

Optimization targets:
- **Image loading**: < 100ms with caching
- **Scroll FPS**: 60 FPS on modern devices
- **Animation smoothness**: 16ms per frame (60 FPS)
- **Memory usage**: < 50MB for video list
- **Bundle size**: No significant increase

---

## 📝 Summary

**Key Principles**:
1. ✅ **Always use tokens** - never hardcode values
2. ✅ **Reuse components** - no duplicate logic
3. ✅ **Optimize images** - use caching tokens
4. ✅ **Ensure accessibility** - semantic labels on all interactive elements
5. ✅ **Use const** - improve performance
6. ✅ **Test responsiveness** - across all device sizes

For questions, refer back to this guide or check the implemented examples in:
- `/lib/components/ui/` - UI component library
- `/lib/core/theme/app_tokens.dart` - Token definitions
