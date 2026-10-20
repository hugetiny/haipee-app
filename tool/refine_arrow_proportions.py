import os
import math
from PIL import Image, ImageDraw, ImageFilter

def render_compact_arrow_smile(eye_y_offset=-110, mouth_y_offset=80, is_tray=True, target_size=72):
    S = 2048
    cx, cy = S // 2, S // 2
    
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # 1. EYES: Two bold smiling anime eyes (◠ ◠)
    eye_spacing = 280
    eye_y = cy + eye_y_offset
    eye_rx = 150
    eye_ry = 95
    eye_thick = 110 # Extra bold for micro readability
    
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
        
    # 2. SMILE RIBBON + UP/DOWN ARROWS (⬇ ➔ ‿ ➔ ⬆)
    mouth_cy = cy + mouth_y_offset
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
        thick = 125 + 45 * t
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_ribbon = pts_outer + pts_inner
    
    # Left Arrow: Downward Arrow (Download ⬇)
    lx_mid = (pts_outer[0][0] + pts_inner[-1][0]) / 2
    ly_mid = (pts_outer[0][1] + pts_inner[-1][1]) / 2
    
    l_tip = (lx_mid - 75, ly_mid + 175)
    l_barb_out = (lx_mid - 165, ly_mid - 20)
    l_notch = (lx_mid - 15, ly_mid + 25)
    l_barb_in = (lx_mid + 85, ly_mid - 35)
    left_arrow_poly = [l_tip, l_barb_out, l_notch, l_barb_in]
    
    # Right Arrow: Upward Arrow (Upload ⬆)
    rx_mid = (pts_outer[-1][0] + pts_inner[0][0]) / 2
    ry_mid = (pts_outer[-1][1] + pts_inner[0][1]) / 2
    
    r_tip = (rx_mid + 75, ry_mid - 175)
    r_barb_out = (rx_mid + 165, ry_mid + 20)
    r_notch = (rx_mid + 15, ry_mid - 25)
    r_barb_in = (rx_mid - 85, ry_mid + 35)
    right_arrow_poly = [r_tip, r_barb_in, r_notch, r_barb_out]
    
    draw.polygon(smile_ribbon, fill=(255, 255, 255, 255))
    draw.polygon(left_arrow_poly, fill=(255, 255, 255, 255))
    draw.polygon(right_arrow_poly, fill=(255, 255, 255, 255))
    
    # Crop tightly
    bbox = layer.getbbox()
    bw = bbox[2] - bbox[0]
    bh = bbox[3] - bbox[1]
    dim = max(bw, bh)
    bcx = (bbox[0] + bbox[2]) // 2
    bcy = (bbox[1] + bbox[3]) // 2
    
    pad = int(dim * 0.04) # Very tight 4% margin for maximum size in menu bar!
    crop_box = (
        bcx - dim // 2 - pad,
        bcy - dim // 2 - pad,
        bcx + dim // 2 + pad,
        bcy + dim // 2 + pad,
    )
    cropped = layer.crop(crop_box)
    return cropped.resize((target_size, target_size), Image.Resampling.LANCZOS)

tray_compact = render_compact_arrow_smile(target_size=72)
tray_compact.save('/tmp/kazumi_preview/tray_compact_72.png')
print("Compact tray icon generated, bbox:", tray_compact.getbbox())
