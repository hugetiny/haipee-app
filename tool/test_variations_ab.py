import math
from PIL import Image, ImageDraw, ImageFilter

def render_variation_a(S=1024):
    """
    Variation A: Smooth Classic Arrow-Smile
    - Left side: Smooth rounded terminal cap
    - Center: Wide, optimistic parabolic smile curve
    - Right side: Sleek, high-tech integrated arrowhead (Upload ↗)
    - Eyes: Two modern rounded pill nodes
    """
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cx, cy = S // 2, S // 2
    
    # Eyes: Two sleek capsule pills
    ew, eh = 30, 60
    for side in (-1, 1):
        ecx = cx + side * 145
        box = [(ecx - ew, cy - 80 - eh), (ecx + ew, cy - 80 + eh)]
        draw.rounded_rectangle(box, radius=ew, fill=(255, 255, 255, 255))
        
    # Smile arc: from deg 25 to 145
    pts_outer = []
    pts_inner = []
    mouth_cy = cy + 40
    mouth_rx = 280
    mouth_ry = 190
    
    for deg in range(25, 142, 2):
        rad = math.radians(deg)
        x = cx - mouth_rx * math.cos(rad)
        y = mouth_cy + mouth_ry * math.sin(rad)
        nx = -math.cos(rad)
        ny = math.sin(rad)
        nl = math.sqrt(nx*nx + ny*ny)
        nx /= nl
        ny /= nl
        t = math.sin(rad)
        thick = 38 + 20 * t
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    lx_mid = (pts_outer[0][0] + pts_inner[-1][0]) / 2
    ly_mid = (pts_outer[0][1] + pts_inner[-1][1]) / 2
    
    rx_mid = (pts_outer[-1][0] + pts_inner[0][0]) / 2
    ry_mid = (pts_outer[-1][1] + pts_inner[0][1]) / 2
    
    # Arrowhead at right
    r_tip = (rx_mid + 45, ry_mid - 85)
    r_barb_out = (rx_mid + 85, ry_mid + 10)
    r_notch = (rx_mid + 12, ry_mid - 8)
    r_barb_in = (rx_mid - 45, ry_mid + 14)
    arrow = [r_tip, r_barb_in, r_notch, r_barb_out]
    
    draw.polygon(pts_outer + pts_inner, fill=(255, 255, 255, 255))
    draw.ellipse([(lx_mid - 19, ly_mid - 19), (lx_mid + 19, ly_mid + 19)], fill=(255, 255, 255, 255))
    draw.polygon(arrow, fill=(255, 255, 255, 255))
    
    img.alpha_composite(layer)
    return img

def render_variation_c(S=1024):
    """
    Variation C: The Flowing P2P Arrow-Smile (Descending Stream ➔ Smile ➔ Ascending Arrow)
    - Starts higher on the left, curving downward into the smile (Download flow ⬇)
    - Swoops through the warm smile
    - Ascends on the right and terminates in an aerodynamic arrow (Upload ⬆ ↗)
    - Zero weird corners, just one magnificent continuous tech curve
    - Eyes: Two expressive smiling arcs (◠ ◠)
    """
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cx, cy = S // 2, S // 2
    
    # Eyes: Two smiling arcs (◠ ◠)
    for side in (-1, 1):
        ecx = cx + side * 145
        pts_eye_outer = []
        pts_eye_inner = []
        for deg in range(195, 346, 3):
            rad = math.radians(deg)
            ox = ecx + 85 * math.cos(rad)
            oy = (cy - 75) + 52 * math.sin(rad)
            nx = math.cos(rad)
            ny = math.sin(rad)
            t = math.sin(math.radians(deg - 180))
            cur_th = 44 * (0.75 + 0.35 * t)
            pts_eye_outer.append((ox - nx * (cur_th / 2), oy - ny * (cur_th / 2)))
            pts_eye_inner.insert(0, (ox + nx * (cur_th / 2), oy + ny * (cur_th / 2)))
        draw.polygon(pts_eye_outer + pts_eye_inner, fill=(255, 255, 255, 255))
        
    # Smile arc: from deg 22 to 142
    pts_outer = []
    pts_inner = []
    mouth_cy = cy + 42
    mouth_rx = 275
    mouth_ry = 185
    
    for deg in range(22, 142, 2):
        rad = math.radians(deg)
        x = cx - mouth_rx * math.cos(rad)
        y = mouth_cy + mouth_ry * math.sin(rad)
        nx = -math.cos(rad)
        ny = math.sin(rad)
        nl = math.sqrt(nx*nx + ny*ny)
        nx /= nl
        ny /= nl
        t = math.sin(rad)
        thick = 38 + 20 * t
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    lx_mid = (pts_outer[0][0] + pts_inner[-1][0]) / 2
    ly_mid = (pts_outer[0][1] + pts_inner[-1][1]) / 2
    
    rx_mid = (pts_outer[-1][0] + pts_inner[0][0]) / 2
    ry_mid = (pts_outer[-1][1] + pts_inner[0][1]) / 2
    
    r_tip = (rx_mid + 45, ry_mid - 85)
    r_barb_out = (rx_mid + 85, ry_mid + 10)
    r_notch = (rx_mid + 12, ry_mid - 8)
    r_barb_in = (rx_mid - 45, ry_mid + 14)
    arrow = [r_tip, r_barb_in, r_notch, r_barb_out]
    
    draw.polygon(pts_outer + pts_inner, fill=(255, 255, 255, 255))
    draw.ellipse([(lx_mid - 19, ly_mid - 19), (lx_mid + 19, ly_mid + 19)], fill=(255, 255, 255, 255))
    draw.polygon(arrow, fill=(255, 255, 255, 255))
    
    img.alpha_composite(layer)
    return img

va = render_variation_a()
vc = render_variation_c()
va.save('/tmp/kazumi_concept_test/var_a.png')
vc.save('/tmp/kazumi_concept_test/var_c.png')
print("Variations A and C generated!")
