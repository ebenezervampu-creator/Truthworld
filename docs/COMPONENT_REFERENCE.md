# 🎯 Component Library Quick Reference

## Import Cheat Sheet

```dart
// Core design tokens
import 'package:truthworld/core/theme/app_tokens.dart';

// UI Components
import 'package:truthworld/components/ui/base_card.dart';
import 'package:truthworld/components/ui/primary_button.dart';
import 'package:truthworld/components/ui/icon_button_custom.dart';
import 'package:truthworld/components/ui/category_chip.dart';
import 'package:truthworld/components/ui/loading_state.dart';
import 'package:truthworld/components/ui/responsive_grid.dart';
import 'package:truthworld/components/ui/layout_container.dart';
import 'package:truthworld/components/ui/video_card.dart';
```

---

## Token Quick Reference

### Spacing (8px grid)
| Token | Value |
|-------|-------|
| `AppTokens.spacing.xs` | 8px |
| `AppTokens.spacing.sm` | 16px |
| `AppTokens.spacing.md` | 24px |
| `AppTokens.spacing.lg` | 32px |
| `AppTokens.spacing.xl` | 40px |
| `AppTokens.spacing.xxl` | 48px |

### Colors (Crimson Noir)
| Token | Purpose |
|-------|---------|
| `AppTokens.colors.primary` | Action, accents |
| `AppTokens.colors.surface` | Cards, backgrounds |
| `AppTokens.colors.textPrimary` | Main text |
| `AppTokens.colors.textSecondary` | Secondary text |
| `AppTokens.colors.error` | Errors, danger |
| `AppTokens.colors.success` | Success states |
| `AppTokens.colors.border` | Dividers, borders |

### Sizes
| Token | Size |
|-------|------|
| Icon sizes | `iconSm` (20px) to `iconXl` (48px) |
| Avatar sizes | `avatarSm` (32px) to `avatarXl` (80px) |
| Thumbnail width | 120px, 160px, 240px |
| Thumbnail height | 68px, 90px, 135px |

### Animations
| Token | Duration |
|-------|----------|
| `animations.fast` | 100ms |
| `animations.normal` | 200ms |
| `animations.slow` | 300ms |
| `animations.slower` | 500ms |

---

## Component Patterns

### BaseCard Pattern
```dart
BaseCard(
  onTap: () => openDetails(),
  semanticLabel: 'Content card',
  child: Column(
    children: [/* content */],
  ),
)
```

### PrimaryButton Variants
```dart
// Primary action
PrimaryButton(
  label: 'Upload',
  variant: ButtonVariant.primary,
  size: ButtonSize.medium,
  onPressed: upload,
)

// Secondary action
PrimaryButton(
  label: 'Cancel',
  variant: ButtonVariant.secondary,
  onPressed: cancel,
)

// Danger/Delete
PrimaryButton(
  label: 'Delete',
  variant: ButtonVariant.danger,
  onPressed: delete,
)

// Icon only
PrimaryButton(
  label: 'Like',
  icon: Icons.favorite,
  variant: ButtonVariant.icon,
  onPressed: toggleLike,
)
```

### Loading State Pattern
```dart
// Show loading
if (isLoading) {
  LoadingState(
    size: LoadingSize.medium,
    semanticLabel: 'Loading content...',
  )
} else {
  // Show content
  contentWidget
}
```

### Responsive Grid Pattern
```dart
ResponsiveGrid(
  children: items.map((item) => ItemCard(item: item)).toList(),
  columnsDesktop: 4,
  columnsTablet: 3,
  columnsMobile: 2,
)
```

### Layout Container Pattern
```dart
LayoutContainer(
  maxWidth: 1400,
  padding: EdgeInsets.symmetric(
    horizontal: AppTokens.spacing.md,
  ),
  child: mainContent,
)
```

---

## Common Pitfalls

### ❌ Hardcoding Values
```dart
// DON'T DO THIS
Padding(
  padding: EdgeInsets.all(16), // ❌ Hardcoded
  child: Text('Hello'),
)

// DO THIS
Padding(
  padding: EdgeInsets.all(AppTokens.spacing.sm),
  child: Text('Hello'),
)
```

### ❌ Missing Semantic Labels
```dart
// DON'T DO THIS
IconButton(
  icon: Icon(Icons.favorite), // ❌ No label
  onPressed: like,
)

// DO THIS
Semantics(
  button: true,
  label: 'Like video',
  child: IconButton(
    icon: Icon(Icons.favorite),
    onPressed: like,
  ),
)
```

### ❌ Not Using Const
```dart
// DON'T DO THIS
SizedBox(height: AppTokens.spacing.sm) // Can't optimize

// DO THIS
const SizedBox(height: 16) // Const where possible
// Or from constants
static const SizedBox spacingSm = SizedBox(height: 16);
```

### ❌ Custom Colors
```dart
// DON'T DO THIS
Container(
  color: Color(0xFFDC143C), // ❌ Hardcoded color
)

// DO THIS
Container(
  color: AppTokens.colors.primary,
)
```

---

## File Structure

```
lib/
├── components/
│   ├── ui/
│   │   ├── base_card.dart         ← Reusable card
│   │   ├── primary_button.dart    ← Action button
│   │   ├── icon_button_custom.dart ← Icon button
│   │   ├── category_chip.dart     ← Selection chip
│   │   ├── loading_state.dart     ← Loading indicators
│   │   ├── responsive_grid.dart   ← Grid layout
│   │   ├── layout_container.dart  ← Responsive container
│   │   ├── video_card.dart        ← Video display
│   │   └── ...
│   └── layout/
│       ├── standard_header.dart
│       └── standard_sidebar.dart
├── core/
│   └── theme/
│       ├── app_tokens.dart        ← All tokens
│       ├── netflix_theme.dart     ← Color definitions
│       ├── spacing_constants.dart ← Spacing values
│       └── typography_constants.dart ← Type styles
├── features/
│   └── ... (feature screens)
└── OPTIMIZATION_GUIDE.md          ← Full documentation
```

---

## Performance Tips

1. **Use SkeletonLoader** for image placeholders
   ```dart
   CachedNetworkImage(
     imageUrl: url,
     placeholder: (_, __) => SkeletonLoader(width: 160, height: 90),
   )
   ```

2. **Optimize image cache sizes**
   ```dart
   memCacheWidth: AppTokens.sizes.imageCacheMediumWidth,
   memCacheHeight: AppTokens.sizes.imageCacheMediumHeight,
   ```

3. **Use ResponsiveGrid for videos**
   ```dart
   ResponsiveGrid(
     children: videos,
     columnsDesktop: 4,
     columnsTablet: 3,
     columnsMobile: 2,
   )
   ```

4. **Memoize components with @immutable**
   ```dart
   @immutable
   class VideoCard extends StatelessWidget {
     // ...
   }
   ```

---

## Next Steps

1. ✅ Use tokens in all new code
2. ✅ Migrate hardcoded values gradually
3. ✅ Add semantic labels to interactive elements
4. ✅ Test on mobile, tablet, and desktop
5. ✅ Monitor performance metrics

---

## Support

For questions or issues:
- Check [OPTIMIZATION_GUIDE.md](./OPTIMIZATION_GUIDE.md)
- Review component examples in `lib/components/ui/`
- Refer to token definitions in `lib/core/theme/app_tokens.dart`
