#!/usr/bin/env python3
"""
Haipee Multi-Platform Launcher Icon Generator
Generates unified black-background WALL-E icons across all 5 platforms:
- Android (Adaptive Icon Foreground + Background #000000 + Legacy Mipmaps)
- iOS (1024x1024 Opaque Square AppIcon + all device tiers)
- macOS (Big Sur Squircle with shadow & edge highlight + AppIcon.icns + xcassets)
- Windows (Multi-resolution .ico with 256/128/64/48/32/24/16 frames)
- Linux (1024x1024 and 512x512 square assets)
- Web (favicon.png, PWA icons, maskable icons)
"""

import io
import os
import subprocess
import shutil
import resvg_py
from PIL import Image, ImageDraw, ImageFilter

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SVG_PATH = os.path.join(REPO_ROOT, "assets/images/logo/logo.svg")
LOGO_DIR = os.path.join(REPO_ROOT, "assets/images/logo")

def generate_base_assets():
    with open(SVG_PATH, "r", encoding="utf-8") as f:
        svg_str = f.read()

    os.makedirs(LOGO_DIR, exist_ok=True)

    # 1. Full Square Black Icon (1024x1024) - For iOS, Android legacy, Linux
    square_icon = Image.new("RGBA", (1024, 1024), (0, 0, 0, 255))
    robot_h = 740
    robot_w = int(robot_h * 395 / 452)
    png_bytes = resvg_py.svg_to_bytes(svg_str, width=robot_w, height=robot_h)
    robot_img = Image.open(io.BytesIO(png_bytes)).convert("RGBA")
    ox = (1024 - robot_w) // 2
    oy = (1024 - robot_h) // 2
    square_icon.paste(robot_img, (ox, oy), robot_img)

    # Save logo_android.png (RGBA)
    android_path = os.path.join(LOGO_DIR, "logo_android.png")
    square_icon.save(android_path, format="PNG")
    print(f"✓ Saved {android_path}")

    # Save logo_linux.png (RGBA)
    linux_path = os.path.join(LOGO_DIR, "logo_linux.png")
    square_icon.save(linux_path, format="PNG")
    print(f"✓ Saved {linux_path}")

    # Save logo_ios.png (Strictly RGB, no alpha channel for App Store compliance)
    ios_icon = Image.new("RGB", (1024, 1024), (0, 0, 0))
    ios_icon.paste(square_icon, (0, 0), square_icon)
    ios_path = os.path.join(LOGO_DIR, "logo_ios.png")
    ios_icon.save(ios_path, format="PNG")
    print(f"✓ Saved {ios_path} (RGB no-alpha)")

    # 2. Android Adaptive Icon Foreground (1024x1024, transparent background, safe-zone WALL-E)
    # Scaled to height 490px so radius from center <= 313px (0 pixels clipped by 66dp circular mask)
    adapt_fg = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    fg_h = 490
    fg_w = int(fg_h * 395 / 452)
    fg_bytes = resvg_py.svg_to_bytes(svg_str, width=fg_w, height=fg_h)
    fg_robot = Image.open(io.BytesIO(fg_bytes)).convert("RGBA")
    fg_ox = (1024 - fg_w) // 2
    fg_oy = (1024 - fg_h) // 2
    adapt_fg.paste(fg_robot, (fg_ox, fg_oy), fg_robot)
    adapt_path = os.path.join(LOGO_DIR, "logo_adaptive_foreground.png")
    adapt_fg.save(adapt_path, format="PNG")
    print(f"✓ Saved {adapt_path}")

    # 3. macOS Squircle Icon (1024x1024, Big Sur rounded rect with black body, edge highlight & shadow)
    macos_icon = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    # Soft drop shadow
    shadow = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle([100, 110, 924, 934], radius=185, fill=(0, 0, 0, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    macos_icon.paste(shadow, (0, 0), shadow)

    # Black squircle body
    bdraw = ImageDraw.Draw(macos_icon)
    bdraw.rounded_rectangle([100, 100, 924, 924], radius=185, fill=(0, 0, 0, 255))
    # Subtle dark grey edge outline (Apple HIG contrast compliance)
    bdraw.rounded_rectangle([100, 100, 924, 924], radius=185, outline=(36, 36, 36, 255), width=2)

    # WALL-E inside squircle
    mac_h = 620
    mac_w = int(mac_h * 395 / 452)
    mac_bytes = resvg_py.svg_to_bytes(svg_str, width=mac_w, height=mac_h)
    mac_robot = Image.open(io.BytesIO(mac_bytes)).convert("RGBA")
    mox = (1024 - mac_w) // 2
    moy = (1024 - mac_h) // 2
    macos_icon.paste(mac_robot, (mox, moy), mac_robot)

    rounded_path = os.path.join(LOGO_DIR, "logo_rounded.png")
    macos_icon.save(rounded_path, format="PNG")
    print(f"✓ Saved {rounded_path}")

    # 4. Windows multi-frame ICO files
    ico_sizes = [(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (24, 24), (16, 16)]
    win_ico_path = os.path.join(LOGO_DIR, "logo_windows.ico")
    lanczos_ico_path = os.path.join(LOGO_DIR, "logo_lanczos.ico")
    macos_icon.save(win_ico_path, format="ICO", sizes=ico_sizes)
    macos_icon.save(lanczos_ico_path, format="ICO", sizes=ico_sizes)
    print(f"✓ Saved {win_ico_path} and {lanczos_ico_path}")

    # Tray icon for macOS (72x72)
    tray_img = macos_icon.resize((72, 72), Image.Resampling.LANCZOS)
    tray_path = os.path.join(LOGO_DIR, "tray_icon_macos.png")
    tray_img.save(tray_path, format="PNG")
    print(f"✓ Saved {tray_path}")

    return {
        "square": square_icon,
        "adaptive_fg": adapt_fg,
        "macos": macos_icon,
    }

def generate_direct_platform_icons(base_images):
    square_icon = base_images["square"]
    adapt_fg = base_images["adaptive_fg"]
    macos_icon = base_images["macos"]

    # -------------------------------------------------------------
    # Android Direct Generation (Mipmaps & Drawables)
    # -------------------------------------------------------------
    android_res = os.path.join(REPO_ROOT, "android/app/src/main/res")
    mipmap_densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in mipmap_densities.items():
        dir_path = os.path.join(android_res, folder)
        os.makedirs(dir_path, exist_ok=True)
        resized = square_icon.resize((size, size), Image.Resampling.LANCZOS)
        out_file = os.path.join(dir_path, "ic_launcher.png")
        resized.save(out_file, format="PNG")
        print(f"✓ Generated Android legacy: {out_file} ({size}x{size})")

    drawable_densities = {
        "drawable-mdpi": 108,
        "drawable-hdpi": 162,
        "drawable-xhdpi": 216,
        "drawable-xxhdpi": 324,
        "drawable-xxxhdpi": 432,
    }
    for folder, size in drawable_densities.items():
        dir_path = os.path.join(android_res, folder)
        os.makedirs(dir_path, exist_ok=True)
        # Foreground
        fg_resized = adapt_fg.resize((size, size), Image.Resampling.LANCZOS)
        fg_out = os.path.join(dir_path, "ic_launcher_foreground.png")
        fg_resized.save(fg_out, format="PNG")
        # Monochrome (same shape, used for Android 13 themed icons)
        mono_out = os.path.join(dir_path, "ic_launcher_monochrome.png")
        fg_resized.save(mono_out, format="PNG")
        print(f"✓ Generated Android adaptive: {fg_out} ({size}x{size})")

    # Update values/colors.xml
    colors_xml_path = os.path.join(android_res, "values/colors.xml")
    with open(colors_xml_path, "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#000000</color>\n</resources>\n')
    print(f"✓ Updated {colors_xml_path} background to #000000")

    # Update mipmap-anydpi-v26/ic_launcher.xml
    v26_xml_path = os.path.join(android_res, "mipmap-anydpi-v26/ic_launcher.xml")
    v26_content = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>
</adaptive-icon>
'''
    with open(v26_xml_path, "w", encoding="utf-8") as f:
        f.write(v26_content)
    print(f"✓ Updated {v26_xml_path} to clean adaptive-icon spec")

    # -------------------------------------------------------------
    # Windows Direct Generation
    # -------------------------------------------------------------
    win_res_dir = os.path.join(REPO_ROOT, "windows/runner/resources")
    os.makedirs(win_res_dir, exist_ok=True)
    win_ico_target = os.path.join(win_res_dir, "app_icon.ico")
    ico_sizes = [(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (24, 24), (16, 16)]
    macos_icon.save(win_ico_target, format="ICO", sizes=ico_sizes)
    print(f"✓ Generated Windows icon: {win_ico_target}")

    # -------------------------------------------------------------
    # macOS AppIcon.appiconset & AppIcon.icns Direct Generation
    # -------------------------------------------------------------
    macos_appiconset = os.path.join(REPO_ROOT, "macos/Runner/Assets.xcassets/AppIcon.appiconset")
    os.makedirs(macos_appiconset, exist_ok=True)
    mac_sizes = {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024,
    }
    for filename, size in mac_sizes.items():
        out_path = os.path.join(macos_appiconset, filename)
        resized = macos_icon.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(out_path, format="PNG")
        print(f"✓ Generated macOS xcasset: {out_path} ({size}x{size})")

    # Generate .icns using iconutil on macOS
    temp_iconset = os.path.join(REPO_ROOT, "macos/Runner/AppIcon.iconset")
    os.makedirs(temp_iconset, exist_ok=True)
    iconutil_map = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    for filename, size in iconutil_map.items():
        resized = macos_icon.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(os.path.join(temp_iconset, filename), format="PNG")

    macos_runner_icns = os.path.join(REPO_ROOT, "macos/Runner/AppIcon.icns")
    macos_res_dir = os.path.join(REPO_ROOT, "macos/Runner/Resources")
    os.makedirs(macos_res_dir, exist_ok=True)
    macos_res_icns = os.path.join(macos_res_dir, "AppIcon.icns")

    try:
        subprocess.run(["iconutil", "-c", "icns", temp_iconset, "-o", macos_runner_icns], check=True)
        shutil.copy2(macos_runner_icns, macos_res_icns)
        print(f"✓ Generated macOS binary ICNS via iconutil: {macos_runner_icns}")
    except Exception as e:
        print(f"! iconutil invocation skipped or failed: {e}")
    finally:
        shutil.rmtree(temp_iconset, ignore_errors=True)

    # -------------------------------------------------------------
    # iOS AppIcon.appiconset Direct Generation
    # -------------------------------------------------------------
    ios_appiconset = os.path.join(REPO_ROOT, "ios/Runner/Assets.xcassets/AppIcon.appiconset")
    os.makedirs(ios_appiconset, exist_ok=True)
    ios_sizes = {
        "Icon-App-1024x1024@1x.png": 1024,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-72x72@2x.png": 144,
        "Icon-App-72x72@1x.png": 72,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-57x57@2x.png": 114,
        "Icon-App-57x57@1x.png": 57,
        "Icon-App-50x50@2x.png": 100,
        "Icon-App-50x50@1x.png": 50,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@1x.png": 20,
    }
    for filename, size in ios_sizes.items():
        out_path = os.path.join(ios_appiconset, filename)
        # iOS AppIcon must be strictly opaque RGB without alpha
        resized_rgba = square_icon.resize((size, size), Image.Resampling.LANCZOS)
        resized_rgb = Image.new("RGB", (size, size), (0, 0, 0))
        resized_rgb.paste(resized_rgba, (0, 0), resized_rgba)
        resized_rgb.save(out_path, format="PNG")
        print(f"✓ Generated iOS xcasset: {out_path} ({size}x{size})")

    # -------------------------------------------------------------
    # Web Icons Direct Generation
    # -------------------------------------------------------------
    web_dir = os.path.join(REPO_ROOT, "web")
    web_icons_dir = os.path.join(web_dir, "icons")
    os.makedirs(web_icons_dir, exist_ok=True)
    
    # favicon
    square_icon.resize((32, 32), Image.Resampling.LANCZOS).save(os.path.join(web_dir, "favicon.png"), format="PNG")
    # PWA icons
    square_icon.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, "Icon-192.png"), format="PNG")
    square_icon.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, "Icon-512.png"), format="PNG")
    square_icon.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, "Icon-maskable-192.png"), format="PNG")
    square_icon.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, "Icon-maskable-512.png"), format="PNG")
    print(f"✓ Generated Web & PWA icons in {web_dir}")

if __name__ == "__main__":
    print("=" * 60)
    print("🚀 Generating Master Multi-Platform Icons from WALL-E SVG")
    print("=" * 60)
    base_imgs = generate_base_assets()
    generate_direct_platform_icons(base_imgs)
    print("=" * 60)
    print("✅ All platform assets generated successfully!")
    print("=" * 60)
