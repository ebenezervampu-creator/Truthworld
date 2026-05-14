# 🔄 Page-by-Page Migration Guide

## Overview
This guide helps migrate existing feature pages to use the new Design Token System.

**Status**: Non-breaking change - existing pages will continue to work while you migrate gradually.

---

## 📍 Pages That Need Migration

### High-Priority (High Traffic)
1. **home/** - Main dashboard
2. **video/** - Video player screen
3. **dashboard/** - User dashboard
4. **search/** (if exists) - Search results

### Medium-Priority (Regular Traffic)
5. **library/** - User library (found: 7 hardcoded paddings)
6. **watchlater/** - Watch later list (found: 10 hardcoded paddings)
7. **watchhistory/** - Watch history
8. **myvideos/** - User videos
9. **playlist/** - Playlist management

### Low-Priority (Support Pages)
10. **settings/** - Settings page
11. **notifications/** - Notifications
12. **trending/** - Trending videos
13. **category/** - Category browse
14. **channel/** - Channel pages
15. **about/** - About page
16. **feedback/** - Feedback form
17. **commnuity/** - Community content (found: 10 hardcoded paddings)
18. **content/** - Content management
19. **hashtag/** - Hashtag pages
20. **subscriptions/** - Subscriptions
21. **splash/** - Splash screen

---

## 🎯 Migration Steps (Per Page)

### Step 1: Add Token Import
```dart
// At the top of your file, add:
import 'package:truthworld/core/theme/app_tokens.dart';
```

### Step 2: Map Hardcoded Values to Tokens

#### Padding Mappings
```dart
// BEFORE (hardcoded)
padding: EdgeInsets.all(16),
padding: EdgeInsets.all(24),
padding: const EdgeInsets.all(8),

// AFTER (tokens)
padding: EdgeInsets.all(AppTokens.spacing.sm),     // 16px
padding: EdgeInsets.all(AppTokens.spacing.md),     // 24px
padding: EdgeInsets.all(AppTokens.spacing.xs),     // 8px
```

#### Size Mappings
```dart
// BEFORE (hardcoded)
width: 20,
height: 24,
size: 32,

// AFTER (tokens)
width: AppTokens.sizes.iconSm,      // 20px
height: AppTokens.sizes.iconMd,     // 24px
size: AppTokens.sizes.iconLg,       // 32px
```

#### Color Mappings
```dart
// BEFORE (hardcoded)
color: Colors.red,
backgroundColor: Color(0xFFDC143C),

// AFTER (tokens)
color: AppTokens.colors.error,
backgroundColor: AppTokens.colors.primary,
```

### Step 3: Replace Custom Components with Standard Ones

#### Replace Custom Buttons
```dart
// BEFORE (custom)
ElevatedButton(
  onPressed: onTap,
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.red,
    padding: EdgeInsets.all(16),
  ),
  child: Text('Action'),
)

// AFTER (standard)
PrimaryButton(
  label: 'Action',
  variant: ButtonVariant.primary,
  onPressed: onTap,
)
```

#### Replace Custom Cards
```dart
// BEFORE (custom container)
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.grey[900],
    borderRadius: BorderRadius.circular(12),
  ),
  child: content,
)

// AFTER (standard card)
BaseCard(
  child: content,
)
```

#### Replace Custom Grids
```dart
// BEFORE (custom GridView)
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 4,
    crossAxisSpacing: 16,
    mainAxisSpacing: 16,
  ),
  itemBuilder: (context, index) => items[index],
)

// AFTER (responsive grid)
ResponsiveGrid(
  children: items,
  columnsDesktop: 4,
  columnsTablet: 3,
  columnsMobile: 2,
)
```

---

## 📋 Token Mapping Reference

### Spacing (8px Grid)
| Old Value | New Token | Size |
|-----------|-----------|------|
| 4 | `AppTokens.spacing.xxs` | 4px |
| 8 | `AppTokens.spacing.xs` | 8px |
| 12 | `AppTokens.spacing.smMinus` | 12px |
| 16 | `AppTokens.spacing.sm` | 16px |
| 20 | *Use 16 or 24* | - |
| 24 | `AppTokens.spacing.md` | 24px |
| 32 | `AppTokens.spacing.lg` | 32px |
| 40 | `AppTokens.spacing.xl` | 40px |
| 48 | `AppTokens.spacing.xxl` | 48px |

### Icon Sizes
| Old Value | New Token | Size |
|-----------|-----------|------|
| 16 | `AppTokens.sizes.iconXs` | 16px |
| 20 | `AppTokens.sizes.iconSm` | 20px |
| 24 | `AppTokens.sizes.iconMd` | 24px |
| 32 | `AppTokens.sizes.iconLg` | 32px |
| 48 | `AppTokens.sizes.iconXl` | 48px |

### Avatar Sizes
| Old Value | New Token | Size |
|-----------|-----------|------|
| 24 | `AppTokens.sizes.avatarXs` | 24px |
| 32 | `AppTokens.sizes.avatarSm` | 32px |
| 40 | `AppTokens.sizes.avatarMd` | 40px |
| 56 | `AppTokens.sizes.avatarLg` | 56px |
| 80 | `AppTokens.sizes.avatarXl` | 80px |

### Video Thumbnails
| Old Value | New Token | Size |
|-----------|-----------|------|
| 120 | `AppTokens.sizes.thumbnailSmallWidth` | 120px |
| 160 | `AppTokens.sizes.thumbnailMediumWidth` | 160px |
| 240 | `AppTokens.sizes.thumbnailLargeWidth` | 240px |

---

## 🔍 Pages Already Migrated

✅ `lib/components/ui/video_card.dart` - All tokens
✅ `lib/components/ui/primary_button.dart` - All tokens
✅ `lib/components/ui/category_chip.dart` - All tokens
✅ `lib/components/ui/base_card.dart` - All tokens (new)
✅ `lib/components/ui/icon_button_custom.dart` - All tokens (new)

---

## 📝 Migration Priority Queue

### Phase 1: High-Impact Features (Week 1)
- [ ] `home/` - Update dashboard grids
- [ ] `video/` - Update video player layout
- [ ] `dashboard/` - Update dashboard cards

### Phase 2: Core Features (Week 2)
- [ ] `library/` - 7 hardcoded paddings found
- [ ] `watchlater/` - 10 hardcoded paddings found
- [ ] `myvideos/` - User content grid
- [ ] `watchhistory/` - History list

### Phase 3: Supporting Features (Week 3)
- [ ] `playlist/` - Playlist management
- [ ] `channel/` - Channel pages
- [ ] `trending/` - Trending grid
- [ ] `category/` - Category browse

### Phase 4: Admin/Support Pages (Week 4)
- [ ] `settings/` - Settings page
- [ ] `commnuity/` - 10 hardcoded paddings found
- [ ] `notifications/` - Notification list
- [ ] `feedback/` - Feedback form
- [ ] `about/` - About page
- [ ] `hashtag/` - Hashtag pages
- [ ] `subscriptions/` - Subscriptions
- [ ] `splash/` - Splash screen
- [ ] `content/` - Content management

---

## ✅ Verification Checklist (Per Page)

Before marking a page as "migrated":

- [ ] All `import 'package:truthworld/core/theme/app_tokens.dart';` added
- [ ] No hardcoded spacing values (all use `AppTokens.spacing.*`)
- [ ] No hardcoded colors (all use `AppTokens.colors.*`)
- [ ] No hardcoded icon sizes (all use `AppTokens.sizes.icon*`)
- [ ] Custom buttons replaced with `PrimaryButton`
- [ ] Custom cards replaced with `BaseCard`
- [ ] Custom grids replaced with `ResponsiveGrid`
- [ ] All interactive elements have semantic labels
- [ ] Responsive design tested on mobile/tablet/desktop
- [ ] Code review passed with CODE_REVIEW_CHECKLIST.md

---

## 🛠️ Tools for Migration

### Migration Helpers Utility
Use this to quickly find token mappings:

```dart
import 'package:truthworld/core/theme/migration_helpers.dart';

// Print mapping guide
MigrationMap.printMigrationGuide('my_screen.dart');

// Convert old value to token string
String token = 16.0.getToken();  // → 'AppTokens.spacing.sm'
```

### Search for Hardcoded Values
In your editor, search for regex patterns:
```
EdgeInsets\.all\(\d+\)     // Find all hardcoded EdgeInsets
width: \d{3,}              // Find large hardcoded widths
height: \d{3,}             // Find large hardcoded heights
```

---

## 💡 Before/After Examples

### Example 1: Simple List Page

**BEFORE**:
```dart
class MyVideosPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemBuilder: (context, index) => Container(
        padding: EdgeInsets.all(16),
        margin: EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[900],
        ),
        child: Row(
          children: [
            Container(width: 160, height: 90),
            SizedBox(width: 16),
            Expanded(child: Text(title)),
          ],
        ),
      ),
    );
  }
}
```

**AFTER**:
```dart
import 'package:truthworld/core/theme/app_tokens.dart';
import 'package:truthworld/components/ui/base_card.dart';
import 'package:truthworld/components/ui/video_card.dart';

class MyVideosPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(AppTokens.spacing.sm),
      itemBuilder: (context, index) => VideoCard(
        video: videos[index],
        isGrid: false,
      ),
    );
  }
}
```

---

### Example 2: Grid Page

**BEFORE**:
```dart
GridView.builder(
  padding: EdgeInsets.all(24),
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 4,
    crossAxisSpacing: 16,
    mainAxisSpacing: 16,
  ),
  itemBuilder: (context, index) => VideoCard(video: videos[index]),
)
```

**AFTER**:
```dart
import 'package:truthworld/components/ui/responsive_grid.dart';

ResponsiveGrid(
  children: videos.map((v) => VideoCard(video: v)).toList(),
  columnsDesktop: 4,
  columnsTablet: 3,
  columnsMobile: 2,
)
```

---

## 📞 Support

- **Quick Reference**: See `lib/COMPONENT_REFERENCE.md`
- **Full Guide**: See `lib/OPTIMIZATION_GUIDE.md`
- **Code Review**: Use `lib/CODE_REVIEW_CHECKLIST.md`
- **Mappings**: Use `core/theme/migration_helpers.dart`

---

## 🎯 Success Criteria

Migration is complete when:
1. ✅ Zero hardcoded spacing values in all pages
2. ✅ All pages import `AppTokens`
3. ✅ All custom components replaced with standard ones
4. ✅ All pages pass CODE_REVIEW_CHECKLIST
5. ✅ Responsive design verified on all pages
6. ✅ Accessibility verified (semantic labels, contrast)
