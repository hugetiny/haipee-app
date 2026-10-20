import os
import subprocess
from PIL import Image, ImageDraw, ImageFilter
from test_unified_single_source import compute_master_glyph_polygons

def create_squircle_mask(size, margin, radius):
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    box = [(margin, margin), (size - margin, size - margin)]
    draw.rounded_rectangle(box, radius=radius, fill=255)
    return mask

def render_unified_dock_icon(target_size=1024):
    S = 2048
    geom = compute_master_glyph_polygons(S)
    
    margin = 180
    w = S - 2 * margin
    radius = 380
    squircle_box = [(margin, margin), (margin + w, margin + w)]
    
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    
    # 1. Dock Drop Shadow
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_s = ImageDraw.Draw(shadow)
    draw_s.rounded_rectangle([(margin + 12, margin + 26), (margin + w - 12, margin + w + 26)], radius=radius, fill=(0, 0, 0, 160))
    draw_s.rounded_rectangle([(margin + 20, margin + 46), (margin + w - 20, margin + w + 46)], radius=radius, fill=(0, 0, 0, 100))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=46))
    img.alpha_composite(shadow)
    
    # 2. Pure Matte Obsidian Background
    mask = create_squircle_mask(S, margin, radius)
    bg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_bg = ImageDraw.Draw(bg)
    
    cx, cy = S // 2, S // 2
    for y in range(margin, margin + w):
        t = (y - margin) / w
        r = int(22 * (1 - t) + 11 * t)
        g = int(27 * (1 - t) + 13 * t)
        b = int(34 * (1 - t) + 16 * t)
        draw_bg.line([(margin, y), (margin + w, y)], fill=(r, g, b, 255))
        
    glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([(cx - 520, cy - 360), (cx + 520, cy + 480)], fill=(0, 230, 120, 28))
    bg.alpha_composite(glow.filter(ImageFilter.GaussianBlur(radius=120)))
    bg.putalpha(mask)
    img.alpha_composite(bg)
    
    # 3. Micro Bezel Rim (1px hairline)
    rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle(squircle_box, radius=radius, outline=(255, 255, 255, 28), width=3)
    rim.putalpha(mask)
    img.alpha_composite(rim)
    
    # 4. Glyph Layer
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # Eyes contact shadow & fill
    for eye in (geom['left_eye'], geom['right_eye']):
        esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(esh).polygon([(p[0], p[1] + 24) for p in eye], fill=(0, 20, 10, 160))
        layer.alpha_composite(esh.filter(ImageFilter.GaussianBlur(radius=20)))
        draw.polygon(eye, fill=(80, 255, 185, 255))
        
    # Mouth & Arrows contact shadow
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_m = ImageDraw.Draw(msh)
    draw_m.polygon([(p[0], p[1] + 30) for p in geom['smile_ribbon']], fill=(0, 25, 12, 180))
    draw_m.polygon([(p[0], p[1] + 30) for p in geom['left_arrow']], fill=(0, 25, 12, 180))
    draw_m.polygon([(p[0], p[1] + 30) for p in geom['right_arrow']], fill=(0, 25, 12, 180))
    layer.alpha_composite(msh.filter(ImageFilter.GaussianBlur(radius=32)))
    
    # Smile ribbon (Cyber Emerald)
    draw.polygon(geom['smile_ribbon'], fill=(0, 226, 110, 255))
    
    # Left Downward Arrow (Download ⬇): Two-tone faceted styling
    draw.polygon([geom['l_tip'], geom['l_barb_out'], geom['l_notch']], fill=(0, 196, 92, 255))
    draw.polygon([geom['l_tip'], geom['l_notch'], geom['l_barb_in']], fill=(55, 248, 142, 255))
    draw.line([geom['l_barb_out'], geom['l_tip'], geom['l_barb_in']], fill=(255, 255, 255, 230), width=8)
    draw.line([geom['l_tip'], geom['l_notch']], fill=(255, 255, 255, 160), width=5)
    
    # Right Upward Arrow (Upload ⬆): Two-tone faceted styling
    draw.polygon([geom['r_tip'], geom['r_notch'], geom['r_barb_out']], fill=(20, 218, 134, 255))
    draw.polygon([geom['r_tip'], geom['r_barb_in'], geom['r_notch']], fill=(85, 255, 190, 255))
    draw.line([geom['r_barb_in'], geom['r_tip'], geom['r_barb_out']], fill=(255, 255, 255, 240), width=8)
    draw.line([geom['r_tip'], geom['r_notch']], fill=(255, 255, 255, 180), width=5)
    
    draw.line(geom['smile_outer'], fill=(255, 255, 255, 185), width=8)
    img.alpha_composite(layer)
    return img.resize((target_size, target_size), Image.Resampling.LANCZOS)

def render_unified_tray_icon(target_size=72):
    """
    Renders macOS status bar (Tray) icon using the EXACT same geometry as the Dock icon:
    - Pure white monochrome template
    - Tightly cropped to 92% of the canvas height/width so it appears large & prominent in the menu bar!
    """
    S = 2048
    geom = compute_master_glyph_polygons(S)
    
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # Draw exact same elements in solid pure white
    draw.polygon(geom['left_eye'], fill=(255, 255, 255, 255))
    draw.polygon(geom['right_eye'], fill=(255, 255, 255, 255))
    draw.polygon(geom['smile_ribbon'], fill=(255, 255, 255, 255))
    draw.polygon(geom['left_arrow'], fill=(255, 255, 255, 255))
    draw.polygon(geom['right_arrow'], fill=(255, 255, 255, 255))
    
    # Tight crop based on bbox
    bbox = layer.getbbox()
    bw = bbox[2] - bbox[0]
    bh = bbox[3] - bbox[1]
    dim = max(bw, bh)
    bcx = (bbox[0] + bbox[2]) // 2
    bcy = (bbox[1] + bbox[3]) // 2
    
    pad = int(dim * 0.04) # 4% optical margin
    crop_box = (
        bcx - dim // 2 - pad,
        bcy - dim // 2 - pad,
        bcx + dim // 2 + pad,
        bcy + dim // 2 + pad,
    )
    cropped = layer.crop(crop_box)
    return cropped.resize((target_size, target_size), Image.Resampling.LANCZOS)

def deploy():
    print("🎨 [1/5] Rendering 1024x1024 Master P2P Arrow-Smile Dock Icon (Single Source)...")
    dock_icon = render_unified_dock_icon(1024)
    dock_icon.save("assets/images/logo/logo_rounded.png")
    dock_icon.save("assets/images/logo/logo_linux.png")
    dock_icon.save("assets/images/logo/logo_android.png")
    dock_icon.save("assets/images/logo/logo_ios.png")
    
    print("🎨 [2/5] Rendering macOS Tray Icon from IDENTICAL Geometry...")
    tray_icon = render_unified_tray_icon(72)
    tray_icon.save("assets/images/logo/tray_icon_macos.png")
    
    print("🎨 [3/5] Generating Windows ICOs...")
    dock_icon.save("assets/images/logo/logo_windows.ico", format='ICO', sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    dock_icon.save("assets/images/logo/logo_lanczos.ico", format='ICO', sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    
    print("🎨 [4/5] Deploying macOS AppIcon.appiconset...")
    appiconset_dir = "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    for s in sizes:
        resized = dock_icon.resize((s, s), Image.Resampling.LANCZOS)
        resized.save(os.path.join(appiconset_dir, f"app_icon_{s}.png"))
        
    print("🎨 [5/5] Compiling macOS .icns with iconutil...")
    iconset_dir = "/tmp/AppIcon.iconset"
    os.makedirs(iconset_dir, exist_ok=True)
    icon_map = {
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
    for filename, s in icon_map.items():
        dock_icon.resize((s, s), Image.Resampling.LANCZOS).save(os.path.join(iconset_dir, filename))
        
    icns_path = "build/macos/Build/Products/Debug/kazumi.app/Contents/Resources/AppIcon.icns"
    if os.path.exists(os.path.dirname(icns_path)):
        subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", icns_path], check=True)
        print("  -> Updated build .icns at", icns_path)
        
    print("✅ All icons deployed successfully with 100% unified geometry!")

if __name__ == '__main__':
    deploy()
