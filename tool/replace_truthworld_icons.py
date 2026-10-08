import os
import io
import base64
from PIL import Image
from collections import deque

def main():
    src_path = 'C:/Users/ebene/.gemini/antigravity/brain/5d4ff2c3-74b3-4bb2-8d8a-c390b85d3224/.user_uploaded/media_1791045439710.jpg'
    if not os.path.exists(src_path):
        raise FileNotFoundError(f"Source file not found: {src_path}")

    print(f"Loading source image from {src_path}...")
    src = Image.open(src_path).convert('RGB')
    w, h = src.size

    # 1. Floodfill from all 4 borders to detect outer white pixels
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
    print(f"Squircle cutout bounds: {bbox}")
    cropped = out.crop(bbox)

    # 2. Master Squircle RGBA (1024x1024 with 18px padding for perfect icon proportion)
    master_rgba = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
    resized_squircle = cropped.resize((988, 988), Image.Resampling.LANCZOS)
    master_rgba.paste(resized_squircle, (18, 18), resized_squircle)

    # 3. Master Full-Bleed RGB (1024x1024 without alpha, background #0B0F1A for iOS App Store)
    master_rgb = Image.new('RGB', (1024, 1024), (bg_r, bg_g, bg_b))
    master_rgb.paste(resized_squircle, (18, 18), resized_squircle)

    print("Master images ready. Commencing replacements across all platforms...")

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

    # --- 1. Assets (Flutter In-App Assets) ---
    print("\nUpdating Flutter in-app assets...")
    save_png(master_rgba, 'assets/app_icon_squircle.png', (512, 512))
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

    # --- 2. Web Assets ---
    print("\nUpdating Web assets...")
    save_png(master_rgba, 'web/favicon.png', (64, 64))
    save_png(master_rgba, 'web/icons/Icon-192.png', (192, 192))
    save_png(master_rgba, 'web/icons/Icon-512.png', (512, 512))
    save_png(master_rgba, 'web/icons/Icon-maskable-192.png', (192, 192))
    save_png(master_rgba, 'web/icons/Icon-maskable-512.png', (512, 512))

    # OG Image for Social Previews (1200x630 banner)
    print("Generating web og-image.png (1200x630)...")
    og = Image.new('RGBA', (1200, 630), (bg_r, bg_g, bg_b, 255))
    og_icon = master_rgba.resize((388, 388), Image.Resampling.LANCZOS)
    og_x = (1200 - 388) // 2
    og_y = (630 - 388) // 2
    og.paste(og_icon, (og_x, og_y), og_icon)
    og.save('web/icons/og-image.png', 'PNG', optimize=True)
    print("  [SAVED] web/icons/og-image.png (1200x630, RGBA)")

    # --- 3. Android mipmap Launchers ---
    print("\nUpdating Android mipmap icons...")
    android_sizes = {
        'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': (48, 48),
        'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': (72, 72),
        'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': (96, 96),
        'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': (144, 144),
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': (192, 192),
    }
    for path, sz in android_sizes.items():
        save_png(master_rgba, path, sz)

    # --- 4. iOS AppIcon & LaunchImage ---
    print("\nUpdating iOS icons...")
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

    # iOS App Store 1024x1024 marketing icon (must be 24-bit RGB without alpha per Apple App Store requirements)
    save_png(master_rgb, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png', (1024, 1024), mode='RGB')

    # iOS LaunchImages
    print("\nUpdating iOS LaunchImages...")
    save_png(master_rgba, 'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png', (256, 256))
    save_png(master_rgba, 'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png', (512, 512))
    save_png(master_rgba, 'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png', (768, 768))

    # --- 5. macOS AppIcon ---
    print("\nUpdating macOS icons...")
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

    # --- 6. Windows ICO ---
    print("\nGenerating Windows app_icon.ico...")
    ico_path = 'windows/runner/resources/app_icon.ico'
    os.makedirs(os.path.dirname(ico_path), exist_ok=True)
    master_rgba.save(
        ico_path,
        format='ICO',
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    )
    print(f"  [SAVED] {ico_path} (Multi-res ICO)")

    # --- 7. Admin Portal ---
    print("\nUpdating Admin Portal assets...")
    save_png(master_rgba, 'admin-portal/dist/favicon.png', (64, 64))
    save_png(master_rgba, 'admin-portal/public/favicon.png', (64, 64))
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
    with open('admin-portal/public/favicon.svg', 'w', encoding='utf-8') as f:
        f.write(svg_content)
    print("  [SAVED] admin-portal/public/favicon.svg (SVG)")

    if os.path.exists('admin-portal/dist'):
        with open('admin-portal/dist/favicon.svg', 'w', encoding='utf-8') as f:
            f.write(svg_content)
        print("  [SAVED] admin-portal/dist/favicon.svg (SVG)")

    print("\nAll Truthworld icons successfully generated and replaced!")

if __name__ == '__main__':
    main()
