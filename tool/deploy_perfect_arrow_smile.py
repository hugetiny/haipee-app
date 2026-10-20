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

def create_luxury_obsidian_canvas(S=2048):
    margin = 180
    w = S - 2 * margin
    radius = 380
    squircle_box = [(margin, margin), (margin + w, margin + w)]
    
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    
    # 1. macOS dock drop shadow (Dual-layer Gaussian blur)
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_s = ImageDraw.Draw(shadow)
    draw_s.rounded_rectangle(
        [(margin + 12, margin + 26), (margin + w - 12, margin + w + 26)], 
        radius=radius, 
        fill=(0, 0, 0, 160)
    )
    draw_s.rounded_rectangle(
        [(margin + 20, margin + 46), (margin + w - 20, margin + w + 46)], 
        radius=radius, 
        fill=(0, 0, 0, 100)
    )
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
        
    # Ambient Aurora Glow (OLED Emerald Depth)
    glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_glow = ImageDraw.Draw(glow)
    draw_glow.ellipse([(cx - 520, cy - 360), (cx + 520, cy + 480)], fill=(0, 230, 120, 28))
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
    
    return img

def render_master_dock_icon(target_size=1024):
    """
    KAZUMI P2P ARROW-SMILE (Apple Design Award Caliber Dock Icon):
    - 上下箭头核心概念：
      - 左侧端点：极具动感与辨识度的下行折面箭头（Download ⬇），代表汲取与下载
      - 右侧端点：自信挺拔昂扬的上行折面箭头（Upload ⬆），代表播种与分享
    - 温暖笑颜合成：
      - 上下箭头通过底部饱满有力的黄金微笑道（Smile Ribbon ‿）流畅连接，构成完整的微笑嘴形
      - 上方配以一对清澈有神采的折纸笑眼（Smiling Arc Eyes ◠ ◠）
    """
    S = 2048
    cx, cy = S // 2, S // 2 - 20
    img = create_luxury_obsidian_canvas(S)
    
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # -------------------------------------------------------------------------
    # 1. EYES: Two smiling anime eyes (◠ ◠)
    # -------------------------------------------------------------------------
    eye_spacing = 290
    eye_y = cy - 140
    eye_rx = 165
    eye_ry = 100
    eye_thick = 85
    
    for side in (-1, 1):
        ecx = cx + side * eye_spacing
        pts_eye_outer = []
        pts_eye_inner = []
        for deg in range(195, 346, 3):
            rad = math.radians(deg)
            ox = ecx + eye_rx * math.cos(rad)
            oy = eye_y + eye_ry * math.sin(rad)
            nx = math.cos(rad)
            ny = math.sin(rad)
            t = math.sin(math.radians(deg - 180))
            cur_th = eye_thick * (0.70 + 0.40 * t)
            pts_eye_outer.append((ox - nx * (cur_th / 2), oy - ny * (cur_th / 2)))
            pts_eye_inner.insert(0, (ox + nx * (cur_th / 2), oy + ny * (cur_th / 2)))
            
        eye_poly = pts_eye_outer + pts_eye_inner
        
        # Eye contact shadow
        esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        draw_esh = ImageDraw.Draw(esh)
        draw_esh.polygon([(p[0], p[1] + 24) for p in eye_poly], fill=(0, 20, 10, 160))
        esh = esh.filter(ImageFilter.GaussianBlur(radius=20))
        layer.alpha_composite(esh)
        
        # Eye fill with luminous Electric Mint
        draw.polygon(eye_poly, fill=(80, 255, 185, 255))
        # Top specular highlight line
        draw.line(pts_eye_outer, fill=(255, 255, 255, 230), width=8)
        
    # -------------------------------------------------------------------------
    # 2. SMILE RIBBON (Connecting Download ⬇ to Upload ⬆)
    # -------------------------------------------------------------------------
    mouth_cy = cy + 90
    mouth_rx = 560
    mouth_ry = 380
    
    deg_start = 32
    deg_end = 148
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
        thick = 90 + 44 * t
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_ribbon = pts_outer + pts_inner
    
    # -------------------------------------------------------------------------
    # 3. RIGHT ARROW: Bold Upward Arrow (Upload ⬆)
    # -------------------------------------------------------------------------
    rx = pts_outer[-1][0]
    ry = pts_outer[-1][1]
    rx_in = pts_inner[0][0]
    ry_in = pts_inner[0][1]
    rx_mid = (rx + rx_in) / 2
    ry_mid = (ry + ry_in) / 2
    
    # Upward tip pointing up and outward
    r_tip = (rx_mid + 75, ry_mid - 165)
    r_barb_out = (rx_mid + 155, ry_mid + 20)
    r_notch = (rx_mid + 15, ry_mid - 20)
    r_barb_in = (rx_mid - 80, ry_mid + 30)
    right_arrow_poly = [r_tip, r_barb_in, r_notch, r_barb_out]
    
    # -------------------------------------------------------------------------
    # 4. LEFT ARROW: Bold Downward Arrow (Download ⬇)
    # -------------------------------------------------------------------------
    lx = pts_outer[0][0]
    ly = pts_outer[0][1]
    lx_in = pts_inner[-1][0]
    ly_in = pts_inner[-1][1]
    lx_mid = (lx + lx_in) / 2
    ly_mid = (ly + ly_in) / 2
    
    # Downward tip pointing down and outward
    l_tip = (lx_mid - 75, ly_mid + 165)
    l_barb_out = (lx_mid - 155, ly_mid - 20)
    l_notch = (lx_mid - 15, ly_mid + 20)
    l_barb_in = (lx_mid + 80, ly_mid - 30)
    left_arrow_poly = [l_tip, l_barb_out, l_notch, l_barb_in]
    
    # -------------------------------------------------------------------------
    # 5. COMPOSITE DROPSHADOW & FACETS
    # -------------------------------------------------------------------------
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_msh = ImageDraw.Draw(msh)
    draw_msh.polygon([(p[0], p[1] + 30) for p in smile_ribbon], fill=(0, 25, 12, 180))
    draw_msh.polygon([(p[0], p[1] + 30) for p in left_arrow_poly], fill=(0, 25, 12, 180))
    draw_msh.polygon([(p[0], p[1] + 30) for p in right_arrow_poly], fill=(0, 25, 12, 180))
    msh = msh.filter(ImageFilter.GaussianBlur(radius=32))
    layer.alpha_composite(msh)
    
    # Smile ribbon (Cyber Emerald)
    draw.polygon(smile_ribbon, fill=(0, 226, 110, 255))
    
    # Left Downward Arrow (Download ⬇): Two-tone faceted styling
    draw.polygon([l_tip, l_barb_out, l_notch], fill=(0, 196, 92, 255))
    draw.polygon([l_tip, l_notch, l_barb_in], fill=(55, 248, 142, 255))
    draw.line([l_barb_out, l_tip, l_barb_in], fill=(255, 255, 255, 230), width=8)
    draw.line([l_tip, l_notch], fill=(255, 255, 255, 160), width=5)
    
    # Right Upward Arrow (Upload ⬆): Two-tone faceted styling
    draw.polygon([r_tip, r_notch, r_barb_out], fill=(20, 218, 134, 255))
    draw.polygon([r_tip, r_barb_in, r_notch], fill=(85, 255, 190, 255))
    draw.line([r_barb_in, r_tip, r_barb_out], fill=(255, 255, 255, 240), width=8)
    draw.line([r_tip, r_notch], fill=(255, 255, 255, 180), width=5)
    
    # Smile outer curve highlight
    draw.line(pts_outer, fill=(255, 255, 255, 185), width=8)
    
    img.alpha_composite(layer)
    return img.resize((target_size, target_size), Image.Resampling.LANCZOS)

def render_macos_tray_icon(target_size=72):
    """
    Renders the macOS status bar (Tray) icon:
    - Pure white monochrome template
    - High contrast, extra-thick strokes for micro readability
    - Tightly cropped to 92% of the canvas height/width so it appears large & prominent in the menu bar!
    """
    S = 2048
    cx, cy = S // 2, S // 2
    
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # 1. EYES: Bold smiling eyes
    eye_spacing = 280
    eye_y = cy - 110
    eye_rx = 150
    eye_ry = 95
    eye_thick = 110
    
    for side in (-1, 1):
        ecx = cx + side * eye_spacing
        pts_eye_outer = []
        pts_eye_inner = []
        for deg in range(195, 346, 3):
            rad = math.radians(deg)
            ox = ecx + eye_rx * math.cos(rad)
            oy = eye_y + eye_ry * math.sin(rad)
            nx = math.cos(rad)
            ny = math.sin(rad)
            t = math.sin(math.radians(deg - 180))
            cur_th = eye_thick * (0.75 + 0.35 * t)
            pts_eye_outer.append((ox - nx * (cur_th / 2), oy - ny * (cur_th / 2)))
            pts_eye_inner.insert(0, (ox + nx * (cur_th / 2), oy + ny * (cur_th / 2)))
        eye_poly = pts_eye_outer + pts_eye_inner
        draw.polygon(eye_poly, fill=(255, 255, 255, 255))
        
    # 2. SMILE RIBBON
    mouth_cy = cy + 80
    mouth_rx = 540
    mouth_ry = 360
    
    deg_start = 30
    deg_end = 150
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
        thick = 130 + 45 * t
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_ribbon = pts_outer + pts_inner
    
    # Left Arrow (Download ⬇): Pointing strongly Down
    lx_mid = (pts_outer[0][0] + pts_inner[-1][0]) / 2
    ly_mid = (pts_outer[0][1] + pts_inner[-1][1]) / 2
    l_tip = (lx_mid - 80, ly_mid + 180)
    l_barb_out = (lx_mid - 170, ly_mid - 20)
    l_notch = (lx_mid - 15, ly_mid + 25)
    l_barb_in = (lx_mid + 90, ly_mid - 35)
    left_arrow_poly = [l_tip, l_barb_out, l_notch, l_barb_in]
    
    # Right Arrow (Upload ⬆): Pointing strongly Up
    rx_mid = (pts_outer[-1][0] + pts_inner[0][0]) / 2
    ry_mid = (pts_outer[-1][1] + pts_inner[0][1]) / 2
    r_tip = (rx_mid + 80, ry_mid - 180)
    r_barb_out = (rx_mid + 170, ry_mid + 20)
    r_notch = (rx_mid + 15, ry_mid - 25)
    r_barb_in = (rx_mid - 90, ry_mid + 35)
    right_arrow_poly = [r_tip, r_barb_in, r_notch, r_barb_out]
    
    draw.polygon(smile_ribbon, fill=(255, 255, 255, 255))
    draw.polygon(left_arrow_poly, fill=(255, 255, 255, 255))
    draw.polygon(right_arrow_poly, fill=(255, 255, 255, 255))
    
    # Tightly crop to 92% of the canvas height/width so it appears large & prominent in the menu bar
    bbox = layer.getbbox()
    bw = bbox[2] - bbox[0]
    bh = bbox[3] - bbox[1]
    dim = max(bw, bh)
    bcx = (bbox[0] + bbox[2]) // 2
    bcy = (bbox[1] + bbox[3]) // 2
    
    pad = int(dim * 0.04) # 4% margin ensures the icon is bold and filling the menu bar
    crop_box = (
        bcx - dim // 2 - pad,
        bcy - dim // 2 - pad,
        bcx + dim // 2 + pad,
        bcy + dim // 2 + pad,
    )
    cropped = layer.crop(crop_box)
    return cropped.resize((target_size, target_size), Image.Resampling.LANCZOS)

def deploy():
    print("🎨 [1/5] Rendering 1024x1024 Master P2P Arrow-Smile Dock Icon...")
    dock_icon = render_master_dock_icon(1024)
    dock_icon.save("assets/images/logo/logo_rounded.png")
    dock_icon.save("assets/images/logo/logo_linux.png")
    dock_icon.save("assets/images/logo/logo_android.png")
    dock_icon.save("assets/images/logo/logo_ios.png")
    
    print("🎨 [2/5] Rendering High-Definition macOS Tray Icon (Template)...")
    tray_icon = render_macos_tray_icon(72)
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
        
    print("✅ All icons deployed successfully!")

if __name__ == '__main__':
    deploy()
