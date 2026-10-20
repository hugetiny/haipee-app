import os
import math
import subprocess
from PIL import Image, ImageDraw, ImageFilter

def create_squircle_mask(size, margin, radius):
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    box = [(margin, margin), (size - margin, size - margin)]
    draw.rounded_rectangle(box, radius=radius, fill=255)
    return mask

def generate_cyber_smile_dock_icon(target_size=1024):
    """
    KAZUMI CYBER-SMILE (Apple Design Award Caliber Dock Icon)
    - 概念：将上行（Upload ⬆）与下行（Download ⬇）箭头，升华融合为极富现代设计感的数码笑颜。
    - 双眼：两个充满活力、向上的立体折纸折角箭头（Chevron Eyes ^ ^）。
           采用 Electric Mint (#55FFB8) 与 Jade Green (#16D886) 的棱面分光与中脊高光线。
    - 微笑：饱满自信的抛物线微笑道（Download Cradle ‿），左右两端化为昂扬上挑的箭头笑涡（Cheek Arrowheads ⬆ ⬆）。
    - 背景：Mac Pro 级曜石黑拟物磨砂压印，带有环境光接触阴影与微光祖母绿极光晕染，1px 高光倒角边框。
    """
    S = 2048
    margin = 180
    w = S - 2 * margin
    radius = 380
    squircle_box = [(margin, margin), (margin + w, margin + w)]
    
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    
    # 1. macOS Dock Drop Shadow (Dual-layer blur)
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_s = ImageDraw.Draw(shadow)
    draw_s.rounded_rectangle(
        [(margin + 8, margin + 18), (margin + w - 8, margin + w + 18)], 
        radius=radius, 
        fill=(0, 0, 0, 160)
    )
    draw_s.rounded_rectangle(
        [(margin + 16, margin + 36), (margin + w - 16, margin + w + 36)], 
        radius=radius, 
        fill=(0, 0, 0, 100)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=46))
    img.alpha_composite(shadow)
    
    # 2. Pure Matte Obsidian Background
    mask = create_squircle_mask(S, margin, radius)
    bg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_bg = ImageDraw.Draw(bg)
    
    cx, cy = S // 2, S // 2 - 20
    for y in range(margin, margin + w):
        t = (y - margin) / w
        r = int(24 * (1 - t) + 10 * t)
        g = int(28 * (1 - t) + 12 * t)
        b = int(35 * (1 - t) + 15 * t)
        draw_bg.line([(margin, y), (margin + w, y)], fill=(r, g, b, 255))
        
    # Ambient OLED Aurora Glow
    glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_glow = ImageDraw.Draw(glow)
    draw_glow.ellipse([(cx - 480, cy - 350), (cx + 480, cy + 500)], fill=(0, 230, 120, 28))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=120))
    bg.alpha_composite(glow)
    
    bg.putalpha(mask)
    img.alpha_composite(bg)
    
    # 3. Micro Bezel Rim (1px crisp edge)
    rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_rim = ImageDraw.Draw(rim)
    draw_rim.rounded_rectangle(squircle_box, radius=radius, outline=(255, 255, 255, 28), width=3)
    rim.putalpha(mask)
    img.alpha_composite(rim)
    
    # 4. Glyph Layer
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # =========================================================================
    # EYES: Dual Faceted Upward Chevrons (^ ^)
    # =========================================================================
    eye_y = cy - 165
    eye_spacing = 280
    eye_span = 195
    eye_h = 148
    notch_h = 54
    
    for side in (-1, 1):
        ecx = cx + side * eye_spacing
        top_tip = (ecx, eye_y - 36)
        r_outer = (ecx + eye_span, eye_y + eye_h)
        r_inner = (ecx + eye_span - 60, eye_y + eye_h + 40)
        bottom_notch = (ecx, eye_y + notch_h)
        l_inner = (ecx - eye_span + 60, eye_y + eye_h + 40)
        l_outer = (ecx - eye_span, eye_y + eye_h)
        
        poly_full = [top_tip, r_outer, r_inner, bottom_notch, l_inner, l_outer]
        facet_left = [top_tip, bottom_notch, l_inner, l_outer]
        facet_right = [top_tip, r_outer, r_inner, bottom_notch]
        
        # Soft ambient shadow
        esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        draw_esh = ImageDraw.Draw(esh)
        draw_esh.polygon([(p[0], p[1] + 24) for p in poly_full], fill=(0, 20, 10, 160))
        esh = esh.filter(ImageFilter.GaussianBlur(radius=22))
        layer.alpha_composite(esh)
        
        # Faceted draw
        draw.polygon(facet_left, fill=(88, 255, 192, 255))
        draw.polygon(facet_right, fill=(20, 216, 132, 255))
        draw.line([l_outer, top_tip, r_outer], fill=(255, 255, 255, 240), width=9)
        draw.line([top_tip, bottom_notch], fill=(255, 255, 255, 190), width=5)

    # =========================================================================
    # SMILE: Dual-Arrow Lifting Smile Ribbon (‿)
    # =========================================================================
    mouth_cy = cy + 105
    mouth_rx = 570
    mouth_ry = 380
    deg_start = 28
    deg_end = 152
    
    pts_outer = []
    pts_inner = []
    
    for deg in range(deg_start, deg_end + 1, 2):
        rad = math.radians(deg)
        x = cx - mouth_rx * math.cos(rad)
        y = mouth_cy + mouth_ry * math.sin(rad)
        nx = -math.cos(rad)
        ny = math.sin(rad)
        nl = math.sqrt(nx*nx + ny*ny)
        nx /= nl
        ny /= nl
        t = math.sin(rad)
        thick = 90 + 42 * t
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_ribbon = pts_outer + pts_inner
    
    # Cheek arrowheads lifting up on both sides (Upload dimples)
    rx_mid = (pts_outer[-1][0] + pts_inner[0][0]) / 2
    ry_mid = (pts_outer[-1][1] + pts_inner[0][1]) / 2
    r_tip = (rx_mid + 45, ry_mid - 125)
    r_barb_out = (rx_mid + 125, ry_mid + 36)
    r_notch = (rx_mid + 15, ry_mid + 10)
    r_barb_in = (rx_mid - 82, ry_mid + 32)
    r_arrow = [r_tip, r_barb_out, r_notch, r_barb_in]
    
    lx_mid = (pts_outer[0][0] + pts_inner[-1][0]) / 2
    ly_mid = (pts_outer[0][1] + pts_inner[-1][1]) / 2
    l_tip = (lx_mid - 45, ly_mid - 125)
    l_barb_out = (lx_mid - 125, ly_mid + 36)
    l_notch = (lx_mid - 15, ly_mid + 10)
    l_barb_in = (lx_mid + 82, ly_mid + 32)
    l_arrow = [l_tip, l_barb_out, l_notch, l_barb_in]
    
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_msh = ImageDraw.Draw(msh)
    draw_msh.polygon([(p[0], p[1] + 30) for p in smile_ribbon], fill=(0, 25, 12, 180))
    draw_msh.polygon([(p[0], p[1] + 30) for p in l_arrow], fill=(0, 25, 12, 180))
    draw_msh.polygon([(p[0], p[1] + 30) for p in r_arrow], fill=(0, 25, 12, 180))
    msh = msh.filter(ImageFilter.GaussianBlur(radius=32))
    layer.alpha_composite(msh)
    
    draw.polygon(smile_ribbon, fill=(0, 226, 110, 255))
    draw.polygon([l_tip, l_notch, l_barb_in], fill=(85, 255, 188, 255))
    draw.polygon([l_tip, l_barb_out, l_notch], fill=(22, 218, 134, 255))
    draw.line([(l_barb_in[0], l_barb_in[1]), (l_tip[0], l_tip[1])], fill=(255, 255, 255, 240), width=8)
    
    draw.polygon([r_tip, r_barb_in, r_notch], fill=(85, 255, 188, 255))
    draw.polygon([r_tip, r_notch, r_barb_out], fill=(22, 218, 134, 255))
    draw.line([(r_barb_in[0], r_barb_in[1]), (r_tip[0], r_tip[1])], fill=(255, 255, 255, 240), width=8)
    
    draw.line(pts_outer, fill=(255, 255, 255, 185), width=9)
    img.alpha_composite(layer)
    
    return img.resize((target_size, target_size), Image.Resampling.LANCZOS)

def generate_cyber_smile_tray_icon(target_size=72):
    """
    Renders clean monochrome vector-grade template tray icon for macOS status bar (72x72)
    """
    S = 512
    cx, cy = S // 2, S // 2 - 10
    
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # EYES: Chevrons (^ ^)
    eye_spacing = 72
    eye_y = cy - 40
    span = 44
    h = 34
    notch = 12
    
    for side in (-1, 1):
        ecx = cx + side * eye_spacing
        poly = [
            (ecx, eye_y - 8),
            (ecx + span, eye_y + h),
            (ecx + span - 14, eye_y + h + 10),
            (ecx, eye_y + notch),
            (ecx - span + 14, eye_y + h + 10),
            (ecx - span, eye_y + h),
        ]
        draw.polygon(poly, fill=(255, 255, 255, 255))
        
    # MOUTH: Parabolic smile with dual upward lifting arrows
    mouth_cy = cy + 24
    mouth_rx = 135
    mouth_ry = 90
    
    m_bbox = [(cx - mouth_rx, mouth_cy - mouth_ry), (cx + mouth_rx, mouth_cy + mouth_ry)]
    draw.arc(m_bbox, start=28, end=152, fill=(255, 255, 255, 255), width=24)
    
    # Right arrow tip (Upward ⬆)
    rx = cx + int(mouth_rx * math.cos(math.radians(28)))
    ry = mouth_cy + int(mouth_ry * math.sin(math.radians(28)))
    draw.polygon([(rx + 12, ry - 28), (rx + 28, ry + 10), (rx - 14, ry + 8)], fill=(255, 255, 255, 255))
    
    # Left arrow tip (Upward ⬆)
    lx = cx - int(mouth_rx * math.cos(math.radians(28)))
    ly = mouth_cy + int(mouth_ry * math.sin(math.radians(28)))
    draw.polygon([(lx - 12, ly - 28), (lx - 28, ly + 10), (lx + 14, ly + 8)], fill=(255, 255, 255, 255))
    
    return img.resize((target_size, target_size), Image.Resampling.LANCZOS)

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

def deploy_all_cyber_smile_icons(base_dir):
    print("Generating Kazumi Cyber-Smile master dock icon (1024x1024)...")
    master_1024 = generate_cyber_smile_dock_icon(1024)
    
    print("Generating macOS status bar tray icon (72x72)...")
    tray_icon = generate_cyber_smile_tray_icon(72)
    
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

    # 4. Compile AppIcon.icns into built macOS bundles
    app_icns_paths = [
        os.path.join(base_dir, 'build/macos/Build/Products/Debug/kazumi.app/Contents/Resources/AppIcon.icns'),
        os.path.join(base_dir, 'build/macos/Build/Products/Release/kazumi.app/Contents/Resources/AppIcon.icns'),
    ]
    for p in app_icns_paths:
        if os.path.exists(os.path.dirname(p)):
            compile_icns(master_1024, p)

if __name__ == '__main__':
    project_root = '/Users/a12/projects/kazumi'
    deploy_all_cyber_smile_icons(project_root)
    print("Kazumi Cyber-Smile successfully deployed across all platforms!")
