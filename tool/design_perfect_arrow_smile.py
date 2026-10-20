import os
import math
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
    
    # 1. macOS dock drop shadow
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_s = ImageDraw.Draw(shadow)
    draw_s.rounded_rectangle(
        [(margin + 12, margin + 28), (margin + w - 12, margin + w + 28)], 
        radius=radius, 
        fill=(0, 0, 0, 160)
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
        r = int(22 * (1 - t) + 10 * t)
        g = int(27 * (1 - t) + 12 * t)
        b = int(34 * (1 - t) + 15 * t)
        draw_bg.line([(margin, y), (margin + w, y)], fill=(r, g, b, 255))
        
    # Ambient Aurora Glow
    glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_glow = ImageDraw.Draw(glow)
    draw_glow.ellipse([(cx - 500, cy - 350), (cx + 500, cy + 500)], fill=(0, 230, 120, 28))
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

def render_arrow_smile_logo(target_size=1024, is_tray=False):
    """
    KAZUMI P2P ARROW-SMILE:
    - 明确清晰的「上下箭头」：
      - 左侧：极具识别度的下行箭头（Download ⬇），代表汲取、下载
      - 右侧：挺拔昂扬的上行箭头（Upload ⬆），代表播种、分享
    - 完美的「笑脸」合成：
      - 两箭头通过底部黄金微笑道（Smile Arc ‿）流畅贯通成一体
      - 上方配以一对清澈有神采的笑眼（Smiling Arc Eyes ◠ ◠）
    """
    S = 2048
    cx, cy = S // 2, S // 2 - 15
    
    if is_tray:
        # Tray icon is monochrome white template on transparent
        img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    else:
        img = create_luxury_obsidian_canvas(S)
        
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # =========================================================================
    # 1. EYES: Two smiling anime eyes (◠ ◠)
    # =========================================================================
    eye_spacing = 300
    eye_y = cy - 200
    eye_rx = 160
    eye_ry = 90
    eye_thick = 70 if not is_tray else 90
    
    for side in (-1, 1):
        ecx = cx + side * eye_spacing
        pts_eye_outer = []
        pts_eye_inner = []
        # Upper arc from 195 deg to 345 deg
        for deg in range(195, 346, 3):
            rad = math.radians(deg)
            ox = ecx + eye_rx * math.cos(rad)
            oy = eye_y + eye_ry * math.sin(rad)
            
            # normal pointing outward (upward)
            nx = math.cos(rad)
            ny = math.sin(rad)
            
            t = math.sin(math.radians(deg - 180)) # 0 to 1
            cur_th = eye_thick * (0.65 + 0.45 * t)
            
            pts_eye_outer.append((ox - nx * (cur_th / 2), oy - ny * (cur_th / 2)))
            pts_eye_inner.insert(0, (ox + nx * (cur_th / 2), oy + ny * (cur_th / 2)))
            
        eye_poly = pts_eye_outer + pts_eye_inner
        
        if not is_tray:
            # Soft shadow
            esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
            draw_esh = ImageDraw.Draw(esh)
            draw_esh.polygon([(p[0], p[1] + 24) for p in eye_poly], fill=(0, 20, 10, 160))
            esh = esh.filter(ImageFilter.GaussianBlur(radius=20))
            layer.alpha_composite(esh)
            
            draw.polygon(eye_poly, fill=(80, 255, 185, 255))
            # Top specular line
            draw.line(pts_eye_outer, fill=(255, 255, 255, 230), width=8)
        else:
            draw.polygon(eye_poly, fill=(255, 255, 255, 255))
            
    # =========================================================================
    # 2. THE SMILE RIBBON + UP/DOWN ARROWS (⬇ ➔ ‿ ➔ ⬆)
    # =========================================================================
    mouth_cy = cy + 120
    mouth_rx = 580
    mouth_ry = 420
    
    # Left ribbon starts at deg 35, curves down to deg 145
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
        # Ribbon thickness: 110px at base, 80px near ends
        thick = (82 + 40 * t) if not is_tray else (115 + 45 * t)
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_ribbon = pts_outer + pts_inner
    
    # -------------------------------------------------------------------------
    # LEFT ARROW: Bold Downward Arrow (Download ⬇)
    # -------------------------------------------------------------------------
    # Left end of ribbon is at pts_outer[0] and pts_inner[-1]
    lx_mid = (pts_outer[0][0] + pts_inner[-1][0]) / 2
    ly_mid = (pts_outer[0][1] + pts_inner[-1][1]) / 2
    
    # Downward arrow tip points strongly DOWN (⬇)
    # Barb angles designed for unmistakable arrow readability
    l_tip = (lx_mid - 70, ly_mid + 160)          # Pointing DOWN
    l_barb_out = (lx_mid - 150, ly_mid - 10)     # Outer barb
    l_notch = (lx_mid - 10, ly_mid + 30)         # Inner notch
    l_barb_in = (lx_mid + 75, ly_mid - 30)       # Inner barb
    left_arrow_poly = [l_tip, l_barb_out, l_notch, l_barb_in]
    
    # -------------------------------------------------------------------------
    # RIGHT ARROW: Bold Upward Arrow (Upload ⬆)
    # -------------------------------------------------------------------------
    # Right end of ribbon is at pts_outer[-1] and pts_inner[0]
    rx_mid = (pts_outer[-1][0] + pts_inner[0][0]) / 2
    ry_mid = (pts_outer[-1][1] + pts_inner[0][1]) / 2
    
    # Upward arrow tip points strongly UP (⬆)
    r_tip = (rx_mid + 70, ry_mid - 160)          # Pointing UP
    r_barb_out = (rx_mid + 150, ry_mid + 10)     # Outer barb
    r_notch = (rx_mid + 10, ry_mid - 30)         # Inner notch
    r_barb_in = (rx_mid - 75, ry_mid + 30)       # Inner barb
    right_arrow_poly = [r_tip, r_barb_in, r_notch, r_barb_out]
    
    # -------------------------------------------------------------------------
    # RENDER SMILE & ARROWS
    # -------------------------------------------------------------------------
    if not is_tray:
        # Drop shadow for mouth and arrows
        msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        draw_msh = ImageDraw.Draw(msh)
        draw_msh.polygon([(p[0], p[1] + 30) for p in smile_ribbon], fill=(0, 25, 12, 180))
        draw_msh.polygon([(p[0], p[1] + 30) for p in left_arrow_poly], fill=(0, 25, 12, 180))
        draw_msh.polygon([(p[0], p[1] + 30) for p in right_arrow_poly], fill=(0, 25, 12, 180))
        msh = msh.filter(ImageFilter.GaussianBlur(radius=30))
        layer.alpha_composite(msh)
        
        # Smile ribbon (Gradient Cyber Emerald)
        draw.polygon(smile_ribbon, fill=(0, 226, 110, 255))
        
        # Left Arrow (Download ⬇): Two-tone faceted green
        draw.polygon([l_tip, l_barb_out, l_notch], fill=(0, 196, 90, 255))
        draw.polygon([l_tip, l_notch, l_barb_in], fill=(50, 245, 140, 255))
        draw.line([l_barb_out, l_tip, l_barb_in], fill=(255, 255, 255, 220), width=8)
        draw.line([l_tip, l_notch], fill=(255, 255, 255, 150), width=5)
        
        # Right Arrow (Upload ⬆): Two-tone faceted Electric Mint
        draw.polygon([r_tip, r_notch, r_barb_out], fill=(20, 218, 134, 255))
        draw.polygon([r_tip, r_barb_in, r_notch], fill=(85, 255, 190, 255))
        draw.line([r_barb_in, r_tip, r_barb_out], fill=(255, 255, 255, 240), width=8)
        draw.line([r_tip, r_notch], fill=(255, 255, 255, 180), width=5)
        
        # Outer rim highlight on smile curve
        draw.line(pts_outer, fill=(255, 255, 255, 180), width=8)
        
        img.alpha_composite(layer)
        return img.resize((target_size, target_size), Image.Resampling.LANCZOS)
    else:
        # Monochrome Solid White for macOS Tray Icon
        draw.polygon(smile_ribbon, fill=(255, 255, 255, 255))
        draw.polygon(left_arrow_poly, fill=(255, 255, 255, 255))
        draw.polygon(right_arrow_poly, fill=(255, 255, 255, 255))
        
        # Crop tightly to bounding box with small 5% padding so it occupies full tray height
        bbox = layer.getbbox()
        # Make it square based on bbox
        bw = bbox[2] - bbox[0]
        bh = bbox[3] - bbox[1]
        dim = max(bw, bh)
        bcx = (bbox[0] + bbox[2]) // 2
        bcy = (bbox[1] + bbox[3]) // 2
        
        pad = int(dim * 0.08) # 8% optical margin
        crop_box = (
            bcx - dim // 2 - pad,
            bcy - dim // 2 - pad,
            bcx + dim // 2 + pad,
            bcy + dim // 2 + pad,
        )
        cropped = layer.crop(crop_box)
        return cropped.resize((target_size, target_size), Image.Resampling.LANCZOS)

if __name__ == '__main__':
    os.makedirs('/tmp/kazumi_preview', exist_ok=True)
    dock_icon = render_arrow_smile_logo(1024, is_tray=False)
    dock_icon.save('/tmp/kazumi_preview/dock_icon_1024.png')
    
    tray_icon = render_arrow_smile_logo(72, is_tray=True)
    tray_icon.save('/tmp/kazumi_preview/tray_icon_72.png')
    print("Preview icons generated in /tmp/kazumi_preview!")
