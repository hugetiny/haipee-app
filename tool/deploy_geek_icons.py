import os
import subprocess
from PIL import Image, ImageDraw, ImageFilter

def create_squircle_mask(size, margin, radius):
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    box = [(margin, margin), (size - margin, size - margin)]
    draw.rounded_rectangle(box, radius=radius, fill=255)
    return mask

def generate_clean_geek_dock_icon(target_size=1024):
    """
    Elevated Origami Layer Concept (Top-Tier Graphic Design):
    - Layer 1: Pure Matte Obsidian Squircle (#121418 -> #0C0D10)
    - Layer 2: Big Downward Arrow (Download ⬇) in rich Cyber Emerald (#00EE78 / #00B84D)
               with faceted lighting and micro-bevels.
    - Layer 3: Soft ambient contact shadow beneath the inner arrow.
    - Layer 4: Floating Elevated Upward Arrow (Upload ⬆) in Electric Mint & Ice Jade
               with faceted prismatic lighting, center spine highlight, and micro-bevels.
    - ZERO black hole, ZERO crude black cutouts, ZERO background glare/halos.
    """
    S = 2048
    cx, cy = S // 2, S // 2
    margin = 180
    w = S - 2 * margin
    radius = 380
    squircle_box = [(margin, margin), (margin + w, margin + w)]
    
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    
    # 1. macOS dock drop shadow
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_s = ImageDraw.Draw(shadow)
    draw_s.rounded_rectangle(
        [(margin + 12, margin + 26), (margin + w - 12, margin + w + 26)], 
        radius=radius, 
        fill=(0, 0, 0, 120)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=42))
    img.alpha_composite(shadow)
    
    # 2. Pure Matte Obsidian Background
    mask = create_squircle_mask(S, margin, radius)
    bg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_bg = ImageDraw.Draw(bg)
    for y in range(margin, margin + w):
        t = (y - margin) / w
        r = int(20 * (1 - t) + 12 * t)
        g = int(24 * (1 - t) + 14 * t)
        b = int(30 * (1 - t) + 18 * t)
        draw_bg.line([(margin, y), (margin + w, y)], fill=(r, g, b, 255))
    bg.putalpha(mask)
    img.alpha_composite(bg)
    
    # 3. Micro Bezel Rim (1px hairline)
    rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_rim = ImageDraw.Draw(rim)
    draw_rim.rounded_rectangle(squircle_box, radius=radius, outline=(255, 255, 255, 22), width=3)
    rim.putalpha(mask)
    img.alpha_composite(rim)
    
    arrow_y = cy + 20
    
    # 4. Outer Downward Arrow (Download ⬇)
    outer_stem = 260
    outer_wing = 540
    outer_top = arrow_y - 560
    outer_top_notch = outer_top + 45
    outer_shoulder = arrow_y + 80
    outer_wing_tip = arrow_y + 140
    outer_bottom_tip = arrow_y + 600
    
    left_outer = [
        (cx, outer_top_notch),
        (cx - outer_stem, outer_top),
        (cx - outer_stem, outer_shoulder),
        (cx - outer_wing, outer_wing_tip),
        (cx, outer_bottom_tip),
    ]
    right_outer = [
        (cx, outer_top_notch),
        (cx + outer_stem, outer_top),
        (cx + outer_stem, outer_shoulder),
        (cx + outer_wing, outer_wing_tip),
        (cx, outer_bottom_tip),
    ]
    
    outer_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_out = ImageDraw.Draw(outer_layer)
    draw_out.polygon(left_outer, fill=(0, 238, 120, 255))
    draw_out.polygon(right_outer, fill=(0, 186, 78, 255))
    draw_out.line([(cx, outer_top_notch), (cx, outer_bottom_tip)], fill=(255, 255, 255, 50), width=3)
    draw_out.line([(cx - outer_stem, outer_top), (cx, outer_top_notch)], fill=(255, 255, 255, 120), width=5)
    draw_out.line([(cx - outer_wing, outer_wing_tip), (cx, outer_bottom_tip)], fill=(255, 255, 255, 100), width=5)
    img.alpha_composite(outer_layer)
    
    # 5. Elevated Upward Arrow Geometry (Upload ⬆)
    in_stem = 95
    in_wing = 210
    in_top = arrow_y - 320
    in_shoulder = arrow_y - 20
    in_wing_tip = arrow_y + 30
    in_bottom = arrow_y + 380
    in_bottom_notch = in_bottom - 35
    
    in_poly = [
        (cx, in_top),
        (cx + in_wing, in_wing_tip),
        (cx + in_stem, in_shoulder),
        (cx + in_stem, in_bottom),
        (cx, in_bottom_notch),
        (cx - in_stem, in_bottom),
        (cx - in_stem, in_shoulder),
        (cx - in_wing, in_wing_tip),
    ]
    
    in_left = [
        (cx, in_top),
        (cx - in_wing, in_wing_tip),
        (cx - in_stem, in_shoulder),
        (cx - in_stem, in_bottom),
        (cx, in_bottom_notch),
    ]
    in_right = [
        (cx, in_top),
        (cx + in_wing, in_wing_tip),
        (cx + in_stem, in_shoulder),
        (cx + in_stem, in_bottom),
        (cx, in_bottom_notch),
    ]
    
    # Realistic soft contact shadow cast by the elevated arrow onto the base arrow
    inner_shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_is = ImageDraw.Draw(inner_shadow)
    shadow_offset_y = 18
    in_poly_shadow = [(p[0], p[1] + shadow_offset_y) for p in in_poly]
    draw_is.polygon(in_poly_shadow, fill=(0, 20, 10, 160))
    inner_shadow = inner_shadow.filter(ImageFilter.GaussianBlur(radius=22))
    img.alpha_composite(inner_shadow)
    
    # Floating Elevated Upward Arrow
    inner_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_in = ImageDraw.Draw(inner_layer)
    # Left facet: Crisp Luminous Electric Mint (#50FFB9)
    draw_in.polygon(in_left, fill=(80, 255, 185, 255))
    # Right facet: Shaded Mint Cyan (#14D787)
    draw_in.polygon(in_right, fill=(20, 215, 135, 255))
    # Elegant center ridge
    draw_in.line([(cx, in_top), (cx, in_bottom_notch)], fill=(255, 255, 255, 160), width=4)
    # Wing highlights
    draw_in.line([(cx - in_wing, in_wing_tip), (cx, in_top)], fill=(255, 255, 255, 180), width=5)
    # Subtle perimeter stroke
    draw_in.polygon(in_poly, outline=(255, 255, 255, 60), width=2)
    img.alpha_composite(inner_layer)
    
    return img.resize((target_size, target_size), Image.Resampling.LANCZOS)

def generate_clean_tray_icon(target_size=72):
    """
    Generates a clean monochrome template tray icon for macOS menu bar.
    """
    S = 512
    cx, cy = S // 2, S // 2
    
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    arrow_y = cy + 10
    
    # Outer Downward Arrow (Solid White)
    outer_stem = 65
    outer_wing = 145
    outer_top = arrow_y - 150
    outer_top_notch = outer_top + 12
    outer_shoulder = arrow_y + 20
    outer_wing_tip = arrow_y + 35
    outer_bottom_tip = arrow_y + 160
    
    outer_poly = [
        (cx, outer_top_notch),
        (cx - outer_stem, outer_top),
        (cx - outer_stem, outer_shoulder),
        (cx - outer_wing, outer_wing_tip),
        (cx, outer_bottom_tip),
        (cx + outer_wing, outer_wing_tip),
        (cx + outer_stem, outer_shoulder),
        (cx + outer_stem, outer_top),
    ]
    draw.polygon(outer_poly, fill=(255, 255, 255, 255))
    
    # Inner Upward Arrow (Clean Cutout - Transparent)
    in_stem = 24
    in_wing = 55
    in_top = arrow_y - 80
    in_shoulder = arrow_y - 10
    in_wing_tip = arrow_y + 6
    in_bottom = arrow_y + 90
    in_bottom_notch = in_bottom - 10
    
    in_poly = [
        (cx, in_top),
        (cx + in_wing, in_wing_tip),
        (cx + in_stem, in_shoulder),
        (cx + in_stem, in_bottom),
        (cx, in_bottom_notch),
        (cx - in_stem, in_bottom),
        (cx - in_stem, in_shoulder),
        (cx - in_wing, in_wing_tip),
    ]
    draw.polygon(in_poly, fill=(0, 0, 0, 0))
    
    final_tray = img.resize((target_size, target_size), Image.Resampling.LANCZOS)
    return final_tray

def compile_icns(master_png, output_icns_path):
    iconset_dir = "/tmp/kazumi_app.iconset"
    os.makedirs(iconset_dir, exist_ok=True)
    
    sizes = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]
    
    for filename, sz in sizes:
        dst = os.path.join(iconset_dir, filename)
        resized = master_png.resize((sz, sz), Image.Resampling.LANCZOS)
        resized.save(dst, format="PNG")
        
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", output_icns_path], check=True)
    print(f"Compiled icns to {output_icns_path}")

def deploy_all_icons(base_dir):
    print("Generating elevated origami master dock icon (1024x1024)...")
    master_1024 = generate_clean_geek_dock_icon(1024)
    
    print("Generating macOS status bar tray icon (72x72)...")
    tray_icon = generate_clean_tray_icon(72)
    
    # 1. Save macOS tray icon
    tray_path = os.path.join(base_dir, 'assets/images/logo/tray_icon_macos.png')
    tray_icon.save(tray_path, format='PNG')
    print(f"Saved {tray_path}")
    
    # 2. Save core logo assets
    logo_dir = os.path.join(base_dir, 'assets/images/logo')
    master_1024.save(os.path.join(logo_dir, 'logo_rounded.png'), format='PNG')
    master_1024.save(os.path.join(logo_dir, 'logo_android.png'), format='PNG')
    master_1024.save(os.path.join(logo_dir, 'logo_ios.png'), format='PNG')
    
    logo_linux = master_1024.resize((512, 512), Image.Resampling.LANCZOS)
    logo_linux.save(os.path.join(logo_dir, 'logo_linux.png'), format='PNG')
    
    ico_sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    master_1024.save(os.path.join(logo_dir, 'logo_windows.ico'), format='ICO', sizes=ico_sizes)
    master_1024.save(os.path.join(logo_dir, 'logo_lanczos.ico'), format='ICO', sizes=ico_sizes)
    print("Updated all assets in assets/images/logo/")
    
    # 3. macOS AppIcon asset catalog
    macos_xcassets = os.path.join(base_dir, 'macos/Runner/Assets.xcassets/AppIcon.appiconset')
    icon_sizes = {
        'app_icon_16.png': 16,
        'app_icon_32.png': 32,
        'app_icon_64.png': 64,
        'app_icon_128.png': 128,
        'app_icon_256.png': 256,
        'app_icon_512.png': 512,
        'app_icon_1024.png': 1024,
    }
    for filename, sz in icon_sizes.items():
        dst_path = os.path.join(macos_xcassets, filename)
        if sz == 1024:
            master_1024.save(dst_path, format='PNG')
        else:
            resized = master_1024.resize((sz, sz), Image.Resampling.LANCZOS)
            resized.save(dst_path, format='PNG')
        print(f"Saved {dst_path} ({sz}x{sz})")

    # 4. Compile AppIcon.icns into built bundles
    app_icns_paths = [
        os.path.join(base_dir, 'build/macos/Build/Products/Debug/kazumi.app/Contents/Resources/AppIcon.icns'),
        os.path.join(base_dir, 'build/macos/Build/Products/Release/kazumi.app/Contents/Resources/AppIcon.icns'),
    ]
    for p in app_icns_paths:
        if os.path.exists(os.path.dirname(p)):
            compile_icns(master_1024, p)

if __name__ == '__main__':
    project_root = '/Users/a12/projects/kazumi'
    deploy_all_icons(project_root)
    print("High-end elevated origami icons successfully deployed!")
