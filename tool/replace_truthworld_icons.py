import os
import sys
import io
import base64
from PIL import Image
from collections import deque

def main():
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    os.chdir(project_root)

    # 1. Resolve master source image
    custom_src = sys.argv[1] if len(sys.argv) > 1 else None
    master_rgba = None

    if custom_src and os.path.exists(custom_src):
        print(f"Loading custom source image from {custom_src}...")
        src = Image.open(custom_src).convert('RGB')
        w, h = src.size

        print("Performing edge-preserving flood fill...")
        visited = set()
        q = deque()

        for x in range(w):
            q.append((x, 0))
            q.append((x, h - 1))
            visited.add((x, 0))
            visited.add((x, h - 1))

        for y in range(h):
            q.append((0, y))
            q.append((w - 1, y))
            visited.add((0, y))
            visited.add((w - 1, y))

        bg_r, bg_g, bg_b = 11, 15, 26
        bg_lum = (bg_r + bg_g + bg_b) / 3.0

        while q:
            x, y = q.popleft()
            for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited:
                    r, g, b = src.getpixel((nx, ny))
                    lum = (r + g + b) / 3.0
                    if lum > 35:
                        visited.add((nx, ny))
                        q.append((nx, ny))

        out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        out_pixels = out.load()
        src_pixels = src.load()

        for y in range(h):
            for x in range(w):
                if (x, y) not in visited:
                    r, g, b = src_pixels[x, y]
                    out_pixels[x, y] = (r, g, b, 255)
                else:
                    r, g, b = src_pixels[x, y]
                    lum = (r + g + b) / 3.0
                    if lum >= 248:
                        out_pixels[x, y] = (0, 0, 0, 0)
                    elif lum <= bg_lum:
                        out_pixels[x, y] = (r, g, b, 255)
                    else:
                        alpha = int(255 * (1.0 - (lum - bg_lum) / (254.0 - bg_lum)))
                        alpha = max(0, min(255, alpha))
                        out_pixels[x, y] = (bg_r, bg_g, bg_b, alpha)

        bbox = out.getbbox()
        cropped = out.crop(bbox)
        master_rgba = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
        resized_squircle = cropped.resize((988, 988), Image.Resampling.LANCZOS)
        master_rgba.paste(resized_squircle, (18, 18), resized_squircle)
    else:
        # Load from canonical high-resolution in-repo master asset
        canonical_masters = [
            'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png',
            'assets/app_icon_squircle.png',
        ]
        master_path = None
        for path in canonical_masters:
            if os.path.exists(path):
                master_path = path
                break

        if not master_path:
            raise FileNotFoundError("Canonical master icon asset not found in repository.")

        print(f"Loading master squircle logo from {master_path}...")
        base_img = Image.open(master_path).convert('RGBA')
        if base_img.size != (1024, 1024):
            master_rgba = base_img.resize((1024, 1024), Image.Resampling.LANCZOS)
        else:
            master_rgba = base_img

    bg_r, bg_g, bg_b = 11, 15, 26

    # 2. Master Full-Bleed RGB (1024x1024 without alpha, background #0B0F1A for iOS App Store)
    master_rgb = Image.new('RGB', (1024, 1024), (bg_r, bg_g, bg_b))
    master_rgb.paste(master_rgba, (0, 0), master_rgba)

    # 3. Extract crisp white silhouette of TruthWorld brand mark (T + play triangle)
    # for Android status bar notification small icon (ic_notification.png)
    print("Extracting white silhouette for Android status bar notification icon...")
    w, h = master_rgba.size
    silhouette_canvas = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    src_px = master_rgba.load()
    sil_px = silhouette_canvas.load()

    for y in range(h):
        for x in range(w):
            r, g, b, a = src_px[x, y]
            if a < 10:
                continue
            lum = (r + g + b) / 3.0
            if lum > 60:
                alpha = min(255, int(255 * (lum - 30) / 100.0))
                sil_px[x, y] = (255, 255, 255, alpha)

    mark_bbox = silhouette_canvas.getbbox()
    if not mark_bbox:
        raise ValueError("Failed to extract mark silhouette from master icon.")

    mark_cropped = silhouette_canvas.crop(mark_bbox)
    print(f"Mark silhouette cropped bounds: {mark_bbox} ({mark_cropped.width}x{mark_cropped.height})")

    def make_notification_small_icon(size):
        """Generates Android Material Design compliant monochrome white notification icon with optical margin."""
        canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        target_content_size = max(1, int(size * 0.78))
        scale = float(target_content_size) / max(mark_cropped.width, mark_cropped.height)
        new_w = max(1, int(mark_cropped.width * scale))
        new_h = max(1, int(mark_cropped.height * scale))
        scaled_mark = mark_cropped.resize((new_w, new_h), Image.Resampling.LANCZOS)
        paste_x = (size - new_w) // 2
        paste_y = (size - new_h) // 2
        canvas.paste(scaled_mark, (paste_x, paste_y), scaled_mark)
        return canvas

    def save_png(img, dest_path, size=None, mode='RGBA'):
        os.makedirs(os.path.dirname(dest_path), exist_ok=True)
        target_img = img
        if size is not None and target_img.size != size:
            target_img = target_img.resize(size, Image.Resampling.LANCZOS)
        if mode == 'RGB' and target_img.mode != 'RGB':
            target_img = target_img.convert('RGB')
        elif mode == 'RGBA' and target_img.mode != 'RGBA':
            target_img = target_img.convert('RGBA')
        target_img.save(dest_path, 'PNG', optimize=True)
        print(f"  [SAVED] {dest_path} ({target_img.size[0]}x{target_img.size[1]}, {mode})")

    print("\nMaster images ready. Commencing replacements across all platforms and apps...")

    # --- 1. Android Notification Icons (Small Monochrome & Large Color) ---
    print("\n[1/8] Updating Android Notification Icons (ic_notification & ic_notification_large)...")
    notif_small_sizes = {
        'android/app/src/main/res/drawable/ic_notification.png': 96,
        'android/app/src/main/res/drawable-mdpi/ic_notification.png': 24,
        'android/app/src/main/res/drawable-hdpi/ic_notification.png': 36,
        'android/app/src/main/res/drawable-xhdpi/ic_notification.png': 48,
        'android/app/src/main/res/drawable-xxhdpi/ic_notification.png': 72,
        'android/app/src/main/res/drawable-xxxhdpi/ic_notification.png': 96,
    }
    for path, sz in notif_small_sizes.items():
        icon_img = make_notification_small_icon(sz)
        save_png(icon_img, path, (sz, sz))

    notif_large_sizes = {
        'android/app/src/main/res/drawable/ic_notification_large.png': 256,
        'android/app/src/main/res/drawable-mdpi/ic_notification_large.png': 64,
        'android/app/src/main/res/drawable-hdpi/ic_notification_large.png': 96,
        'android/app/src/main/res/drawable-xhdpi/ic_notification_large.png': 128,
        'android/app/src/main/res/drawable-xxhdpi/ic_notification_large.png': 192,
        'android/app/src/main/res/drawable-xxxhdpi/ic_notification_large.png': 256,
    }
    for path, sz in notif_large_sizes.items():
        save_png(master_rgba, path, (sz, sz))

    # Extract inner brand mark for adaptive foreground
    inner_mark_canvas = Image.new('RGBA', master_rgba.size, (0, 0, 0, 0))
    im_px = inner_mark_canvas.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = src_px[x, y]
            if 100 < x < (w - 100) and 100 < y < (h - 100):
                if r > 40 or g > 40 or b > 40:
                    im_px[x, y] = (r, g, b, a)
    inner_bbox = inner_mark_canvas.getbbox()
    cropped_inner_mark = inner_mark_canvas.crop(inner_bbox) if inner_bbox else mark_cropped

    def make_adaptive_foreground(size):
        """Generates Android Adaptive Icon foreground (108dp canvas with safe zone)."""
        canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        target_mark_size = int(size * 0.56)
        scale = float(target_mark_size) / max(cropped_inner_mark.width, cropped_inner_mark.height)
        mw = int(cropped_inner_mark.width * scale)
        mh = int(cropped_inner_mark.height * scale)
        scaled_mark = cropped_inner_mark.resize((mw, mh), Image.Resampling.LANCZOS)
        canvas.paste(scaled_mark, ((size - mw) // 2, (size - mh) // 2), scaled_mark)
        return canvas

    def make_round_launcher_icon(size):
        """Generates legacy circular launcher icon with brand dark background."""
        from PIL import ImageDraw
        mask = Image.new('L', (size, size), 0)
        draw = ImageDraw.Draw(mask)
        draw.ellipse((0, 0, size, size), fill=255)
        round_canvas = Image.new('RGBA', (size, size), (bg_r, bg_g, bg_b, 255))
        target_mark_size = int(size * 0.70)
        scale = float(target_mark_size) / max(cropped_inner_mark.width, cropped_inner_mark.height)
        mw = int(cropped_inner_mark.width * scale)
        mh = int(cropped_inner_mark.height * scale)
        scaled_mark = cropped_inner_mark.resize((mw, mh), Image.Resampling.LANCZOS)
        round_canvas.paste(scaled_mark, ((size - mw) // 2, (size - mh) // 2), scaled_mark)
        result = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        result.paste(round_canvas, (0, 0), mask)
        return result

    # --- 2. Android Mipmap Launchers ---
    print("\n[2/8] Updating Android mipmap launcher icons...")
    android_sizes = {
        'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': (48, 48),
        'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': (72, 72),
        'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': (96, 96),
        'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': (144, 144),
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': (192, 192),
    }
    for path, sz in android_sizes.items():
        save_png(master_rgba, path, sz)

    adaptive_foreground_sizes = {
        'android/app/src/main/res/mipmap-mdpi/ic_launcher_foreground.png': 108,
        'android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.png': 162,
        'android/app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.png': 216,
        'android/app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.png': 324,
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png': 432,
    }
    for path, sz in adaptive_foreground_sizes.items():
        icon_img = make_adaptive_foreground(sz)
        save_png(icon_img, path, (sz, sz))

    round_icon_sizes = {
        'android/app/src/main/res/mipmap-mdpi/ic_launcher_round.png': 48,
        'android/app/src/main/res/mipmap-hdpi/ic_launcher_round.png': 72,
        'android/app/src/main/res/mipmap-xhdpi/ic_launcher_round.png': 96,
        'android/app/src/main/res/mipmap-xxhdpi/ic_launcher_round.png': 144,
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png': 192,
    }
    for path, sz in round_icon_sizes.items():
        icon_img = make_round_launcher_icon(sz)
        save_png(icon_img, path, (sz, sz))

    adaptive_xml_content = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
'''
    os.makedirs('android/app/src/main/res/mipmap-anydpi-v26', exist_ok=True)
    with open('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml', 'w', encoding='utf-8') as f:
        f.write(adaptive_xml_content)
    with open('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml', 'w', encoding='utf-8') as f:
        f.write(adaptive_xml_content)

    # --- 3. Flutter In-App Assets ---
    print("\n[3/8] Updating Flutter in-app assets...")
    save_png(master_rgba, 'assets/app_icon_squircle.png', (512, 512))
    save_png(master_rgba, 'assets/app_icon_playstore_512.png', (512, 512))
    save_png(master_rgb,  'assets/app_icon_fullbleed_512.png', (512, 512), mode='RGB')
    save_png(master_rgba, 'assets/app_logo.png', (256, 256))
    save_png(master_rgba, 'assets/app_logo_512.png', (512, 512))
    save_png(master_rgba, 'assets/app_logo_transparent.png', (512, 512))
    save_png(master_rgba, 'assets/logo.png', (512, 512))
    save_png(master_rgba, 'assets/icons/app_logo.png', (512, 512))
    save_png(master_rgba, 'assets/icons/Icon-192.png', (192, 192))
    save_png(master_rgba, 'assets/images/logo.png', (512, 512))

    # Feature Graphic (1024x500 banner with dark theme)
    print("Generating feature graphic (1024x500)...")
    fg = Image.new('RGB', (1024, 500), (bg_r, bg_g, bg_b))
    fg_icon = master_rgba.resize((380, 380), Image.Resampling.LANCZOS)
    fg_x = (1024 - 380) // 2
    fg_y = (500 - 380) // 2
    fg.paste(fg_icon, (fg_x, fg_y), fg_icon)
    fg.save('assets/feature_graphic_1024x500.png', 'PNG', optimize=True)
    print("  [SAVED] assets/feature_graphic_1024x500.png (1024x500, RGB)")

    # --- 4. Web Assets & Favicons ---
    print("\n[4/8] Updating Web assets and favicons...")
    save_png(master_rgba, 'web/favicon.png', (64, 64))
    save_png(master_rgba, 'web/favicon-48x48.png', (48, 48))
    save_png(master_rgba, 'web/icons/Icon-192.png', (192, 192))
    save_png(master_rgba, 'web/icons/Icon-512.png', (512, 512))
    save_png(master_rgba, 'web/icons/Icon-maskable-192.png', (192, 192))
    save_png(master_rgba, 'web/icons/Icon-maskable-512.png', (512, 512))

    # Web favicon.ico (multi-resolution ICO)
    print("Generating web favicon.ico...")
    web_ico_path = 'web/favicon.ico'
    master_rgba.save(
        web_ico_path,
        format='ICO',
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64)]
    )
    print(f"  [SAVED] {web_ico_path} (Multi-res ICO)")

    # OG Image for Social Previews (1200x630 banner)
    print("Generating web og-image.png (1200x630)...")
    og = Image.new('RGBA', (1200, 630), (bg_r, bg_g, bg_b, 255))
    og_icon = master_rgba.resize((388, 388), Image.Resampling.LANCZOS)
    og_x = (1200 - 388) // 2
    og_y = (630 - 388) // 2
    og.paste(og_icon, (og_x, og_y), og_icon)
    og.save('web/icons/og-image.png', 'PNG', optimize=True)
    print("  [SAVED] web/icons/og-image.png (1200x630, RGBA)")

    # --- 5. iOS AppIcon & LaunchImage ---
    print("\n[5/8] Updating iOS icons...")
    ios_sizes = {
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png': (20, 20),
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png': (40, 40),
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png': (60, 60),
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png': (29, 29),
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png': (58, 58),
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png': (87, 87),
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png': (40, 40),
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png': (80, 80),
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png': (120, 120),
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png': (120, 120),
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png': (180, 180),
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png': (76, 76),
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png': (152, 152),
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png': (167, 167),
    }
    for path, sz in ios_sizes.items():
        save_png(master_rgba, path, sz)

    save_png(master_rgb, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png', (1024, 1024), mode='RGB')

    print("\nUpdating iOS LaunchImages...")
    save_png(master_rgba, 'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png', (256, 256))
    save_png(master_rgba, 'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png', (512, 512))
    save_png(master_rgba, 'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png', (768, 768))

    # --- 6. macOS AppIcon ---
    print("\n[6/8] Updating macOS icons...")
    macos_sizes = {
        'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png': (16, 16),
        'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png': (32, 32),
        'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png': (64, 64),
        'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png': (128, 128),
        'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png': (256, 256),
        'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png': (512, 512),
        'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png': (1024, 1024),
    }
    for path, sz in macos_sizes.items():
        save_png(master_rgba, path, sz)

    # --- 7. Windows ICO ---
    print("\n[7/8] Generating Windows app_icon.ico...")
    ico_path = 'windows/runner/resources/app_icon.ico'
    os.makedirs(os.path.dirname(ico_path), exist_ok=True)
    master_rgba.save(
        ico_path,
        format='ICO',
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    )
    print(f"  [SAVED] {ico_path} (Multi-res ICO)")

    # --- 8. Admin Portal ---
    print("\n[8/8] Updating Admin Portal assets...")
    if os.path.exists('admin-portal/dist'):
        save_png(master_rgba, 'admin-portal/dist/favicon.png', (64, 64))
    if os.path.exists('admin-portal/public'):
        save_png(master_rgba, 'admin-portal/public/favicon.png', (64, 64))
    if os.path.exists('admin-portal/src/assets'):
        save_png(master_rgba, 'admin-portal/src/assets/logo.png', (256, 256))

    # Generate clean SVG favicon for Admin Portal
    buffered = io.BytesIO()
    save_icon_256 = master_rgba.resize((256, 256), Image.Resampling.LANCZOS)
    save_icon_256.save(buffered, format="PNG")
    img_b64 = base64.b64encode(buffered.getvalue()).decode("utf-8")
    svg_content = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">
  <image href="data:image/png;base64,{img_b64}" width="256" height="256"/>
</svg>
'''
    if os.path.exists('admin-portal/public'):
        with open('admin-portal/public/favicon.svg', 'w', encoding='utf-8') as f:
            f.write(svg_content)
        print("  [SAVED] admin-portal/public/favicon.svg (SVG)")

    if os.path.exists('admin-portal/dist'):
        with open('admin-portal/dist/favicon.svg', 'w', encoding='utf-8') as f:
            f.write(svg_content)
        print("  [SAVED] admin-portal/dist/favicon.svg (SVG)")

    print("\n[SUCCESS] All Truthworld icons and notification drawables across all 4 apps successfully generated and replaced!")

if __name__ == '__main__':
    main()
