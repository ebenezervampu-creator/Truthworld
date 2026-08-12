import os
from PIL import Image

USER_UPLOADED_DIR = r"C:\Users\ebene\.gemini\antigravity\brain\2db67651-86e5-45c4-be0d-274c66363da0\.user_uploaded"
SOURCE_IMAGE_PNG = os.path.join(USER_UPLOADED_DIR, "media_1786502775912.png")
SOURCE_IMAGE_JPG = os.path.join(USER_UPLOADED_DIR, "media_1786502775935.jpg")

PROJECT_ROOT = r"c:\company\truthworld"

def ensure_dir(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)

def generate_icons():
    img_rgba = Image.open(SOURCE_IMAGE_PNG).convert("RGBA")
    img_jpg = Image.open(SOURCE_IMAGE_JPG).convert("RGB")

    print(f"Loaded source PNG size: {img_rgba.size}, JPG size: {img_jpg.size}")

    # 1. Flutter Assets
    flutter_assets = [
        ("assets/app_logo.png", 512, True),
        ("assets/app_logo_transparent.png", 512, True),
        ("assets/app_logo_512.png", 512, True),
        ("assets/logo.png", 512, True),
        ("assets/icons/app_logo.png", 512, True),
    ]

    for rel_path, size, use_rgba in flutter_assets:
        target_path = os.path.join(PROJECT_ROOT, rel_path)
        ensure_dir(target_path)
        src = img_rgba if use_rgba else img_jpg
        resized = src.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(target_path, "PNG")
        print(f"Saved Flutter Asset: {target_path} ({size}x{size})")

    # 2. Android Mipmaps
    android_mipmaps = [
        ("android/app/src/main/res/mipmap-mdpi/ic_launcher.png", 48),
        ("android/app/src/main/res/mipmap-hdpi/ic_launcher.png", 72),
        ("android/app/src/main/res/mipmap-xhdpi/ic_launcher.png", 96),
        ("android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png", 144),
        ("android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png", 192),
    ]

    for rel_path, size in android_mipmaps:
        target_path = os.path.join(PROJECT_ROOT, rel_path)
        ensure_dir(target_path)
        resized = img_rgba.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(target_path, "PNG")
        print(f"Saved Android Mipmap: {target_path} ({size}x{size})")

    # 3. iOS Icons
    ios_icons = [
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", 1024),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png", 20),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png", 40),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png", 60),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png", 29),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png", 58),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png", 87),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png", 40),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png", 80),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png", 120),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png", 120),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png", 180),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png", 76),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png", 152),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png", 167),
    ]

    for rel_path, size in ios_icons:
        target_path = os.path.join(PROJECT_ROOT, rel_path)
        ensure_dir(target_path)
        resized = img_rgba.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(target_path, "PNG")
        print(f"Saved iOS Icon: {target_path} ({size}x{size})")

    # 4. iOS Launch Images
    ios_launch = [
        ("ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png", 256),
        ("ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png", 512),
        ("ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png", 768),
    ]

    for rel_path, size in ios_launch:
        target_path = os.path.join(PROJECT_ROOT, rel_path)
        ensure_dir(target_path)
        resized = img_rgba.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(target_path, "PNG")
        print(f"Saved iOS LaunchImage: {target_path} ({size}x{size})")

    # 5. Web Icons & Favicon
    web_icons = [
        ("web/favicon.png", 64),
        ("web/icons/Icon-192.png", 192),
        ("web/icons/Icon-512.png", 512),
        ("web/icons/Icon-maskable-192.png", 192),
        ("web/icons/Icon-maskable-512.png", 512),
    ]

    for rel_path, size in web_icons:
        target_path = os.path.join(PROJECT_ROOT, rel_path)
        ensure_dir(target_path)
        resized = img_rgba.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(target_path, "PNG")
        print(f"Saved Web Icon: {target_path} ({size}x{size})")

    # Web OG Image (1200x630)
    og_path = os.path.join(PROJECT_ROOT, "web/icons/og-image.png")
    ensure_dir(og_path)
    og_img = Image.new("RGBA", (1200, 630), (13, 0, 20, 255))
    logo_for_og = img_rgba.resize((400, 400), Image.Resampling.LANCZOS)
    og_img.paste(logo_for_og, (400, 115), logo_for_og)
    og_img.save(og_path, "PNG")
    print(f"Saved Web OG Image: {og_path} (1200x630)")

    # 6. Admin Portal Assets
    admin_assets = [
        ("admin-portal/public/favicon.png", 64),
        ("admin-portal/src/assets/logo.png", 256),
    ]

    for rel_path, size in admin_assets:
        target_path = os.path.join(PROJECT_ROOT, rel_path)
        ensure_dir(target_path)
        resized = img_rgba.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(target_path, "PNG")
        print(f"Saved Admin Asset: {target_path} ({size}x{size})")

    print("\n--- All logo & icon assets generated successfully! ---")

if __name__ == "__main__":
    generate_icons()
