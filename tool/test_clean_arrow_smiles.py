import os
import math
from PIL import Image, ImageDraw, ImageFilter

def make_dark_canvas(S=1024):
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    margin = 80
    w = S - 2 * margin
    radius = 180
    mask = Image.new('L', (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([(margin, margin), (margin + w, margin + w)], radius=radius, fill=255)
    
    bg = Image.new('RGBA', (S, S), (20, 24, 32, 255))
    draw_bg = ImageDraw.Draw(bg)
    for y in range(margin, margin + w):
        t = (y - margin) / w
        r = int(22 * (1 - t) + 11 * t)
        g = int(27 * (1 - t) + 13 * t)
        b = int(35 * (1 - t) + 16 * t)
        draw_bg.line([(margin, y), (margin + w, y)], fill=(r, g, b, 255))
        
    glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([(S//2 - 250, S//2 - 180), (S//2 + 250, S//2 + 240)], fill=(0, 230, 120, 30))
    bg.alpha_composite(glow.filter(ImageFilter.GaussianBlur(radius=60)))
    bg.putalpha(mask)
    img.alpha_composite(bg)
    
    # 1px rim
    rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle([(margin, margin), (margin + w, margin + w)], radius=radius, outline=(255, 255, 255, 28), width=2)
    rim.putalpha(mask)
    img.alpha_composite(rim)
    return img

def render_concept_1_streamline_arrow_smile(S=1024, is_tray=False):
    """
    CONCEPT 1: The High-Tech Streamlined Smile-Arrow
    - 嘴角绝无怪异的角！
    - 左侧：圆润、优雅、极简的弧线起点（如同跑车进气道或流体起点），纯净平滑；
    - 底部：饱满自信的极简微笑道（Smile Arc）；
    - 右侧：自然流体延伸，化作一枚极其锐利、简洁、充满速度感与科技感的单向扬升箭头（Upload / Smile ↗）；
    - 双眼：两枚科技感十足的胶囊光斑明眸（Luminous Tech Capsules）。
    """
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0)) if is_tray else make_dark_canvas(S)
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cx, cy = S // 2, S // 2 - 10
    
    # 1. EYES: Two high-tech rounded pills
    eye_spacing = 145
    eye_y = cy - 75
    ew = 28
    eh = 58
    
    for side in (-1, 1):
        ecx = cx + side * eye_spacing
        box = [(ecx - ew, eye_y - eh), (ecx + ew, eye_y + eh)]
        
        if not is_tray:
            esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
            ImageDraw.Draw(esh).rounded_rectangle([(b[0], b[1] + 12) for b in box], radius=ew, fill=(0, 20, 10, 150))
            layer.alpha_composite(esh.filter(ImageFilter.GaussianBlur(radius=10)))
            draw.rounded_rectangle(box, radius=ew, fill=(80, 255, 185, 255))
            # specular line
            draw.line([(ecx - 7, eye_y - eh + 12), (ecx - 7, eye_y + eh - 12)], fill=(255, 255, 255, 180), width=4)
        else:
            draw.rounded_rectangle(box, radius=ew, fill=(255, 255, 255, 255))
            
    # 2. SMILE ARROW:
    # Starts at deg 28 on left (smooth rounded cap), sweeps to deg 148 on right (arrowhead)
    mouth_cy = cy + 45
    mouth_rx = 270
    mouth_ry = 185
    
    pts_outer = []
    pts_inner = []
    
    for deg in range(28, 145, 2):
        rad = math.radians(deg)
        x = cx - mouth_rx * math.cos(rad)
        y = mouth_cy + mouth_ry * math.sin(rad)
        nx = -math.cos(rad)
        ny = math.sin(rad)
        nl = math.sqrt(nx*nx + ny*ny)
        nx /= nl
        ny /= nl
        t = math.sin(rad)
        # Ribbon thickness: 46px at base, 36px near ends
        thick = 36 + 18 * t
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    # Left end: perfectly rounded smooth cap (NO strange corner!)
    # We can create a half-circle on the left connecting pts_outer[0] and pts_inner[-1]
    lx_mid = (pts_outer[0][0] + pts_inner[-1][0]) / 2
    ly_mid = (pts_outer[0][1] + pts_inner[-1][1]) / 2
    
    # Right end: Streamlined, high-tech integrated arrowhead (Upload ↗)
    rx_mid = (pts_outer[-1][0] + pts_inner[0][0]) / 2
    ry_mid = (pts_outer[-1][1] + pts_inner[0][1]) / 2
    
    # Arrowhead geometry along the tangent direction
    # Tangent at deg 145: dx > 0, dy < 0 (pointing up-right)
    r_tip = (rx_mid + 42, ry_mid - 78)           # Crisp aerodynamic tip
    r_barb_out = (rx_mid + 78, ry_mid + 8)        # Outer barb
    r_notch = (rx_mid + 10, ry_mid - 8)          # Inner notch
    r_barb_in = (rx_mid - 42, ry_mid + 12)        # Inner barb
    arrow_poly = [r_tip, r_barb_in, r_notch, r_barb_out]
    
    smile_ribbon = pts_outer + pts_inner
    
    if not is_tray:
        msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(msh).polygon([(p[0], p[1] + 16) for p in smile_ribbon], fill=(0, 25, 12, 180))
        ImageDraw.Draw(msh).polygon([(p[0], p[1] + 16) for p in arrow_poly], fill=(0, 25, 12, 180))
        ImageDraw.Draw(msh).ellipse([(lx_mid - 20, ly_mid - 4), (lx_mid + 20, ly_mid + 36)], fill=(0, 25, 12, 180))
        layer.alpha_composite(msh.filter(ImageFilter.GaussianBlur(radius=16)))
        
        # Smile ribbon (Cyber Emerald)
        draw.polygon(smile_ribbon, fill=(0, 226, 110, 255))
        # Rounded cap on left end
        draw.ellipse([(lx_mid - 18, ly_mid - 18), (lx_mid + 18, ly_mid + 18)], fill=(0, 226, 110, 255))
        
        # Faceted high-tech arrowhead on right
        draw.polygon([r_tip, r_notch, r_barb_out], fill=(20, 218, 134, 255))
        draw.polygon([r_tip, r_barb_in, r_notch], fill=(85, 255, 190, 255))
        draw.line([r_barb_in, r_tip, r_barb_out], fill=(255, 255, 255, 230), width=4)
        draw.line([r_tip, r_notch], fill=(255, 255, 255, 170), width=3)
        draw.line(pts_outer, fill=(255, 255, 255, 170), width=4)
    else:
        draw.polygon(smile_ribbon, fill=(255, 255, 255, 255))
        draw.ellipse([(lx_mid - 20, ly_mid - 20), (lx_mid + 20, ly_mid + 20)], fill=(255, 255, 255, 255))
        draw.polygon(arrow_poly, fill=(255, 255, 255, 255))
        
    img.alpha_composite(layer)
    return img

os.makedirs('/tmp/kazumi_concept_test', exist_ok=True)
c1_dock = render_concept_1_streamline_arrow_smile(1024, is_tray=False)
c1_dock.save('/tmp/kazumi_concept_test/concept1_dock.png')
c1_tray = render_concept_1_streamline_arrow_smile(1024, is_tray=True)
c1_tray.save('/tmp/kazumi_concept_test/concept1_tray.png')

print("Concept 1 generated!")
