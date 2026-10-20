import os
import math
from PIL import Image, ImageDraw, ImageFilter

def create_squircle_mask(size, margin, radius):
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    box = [(margin, margin), (size - margin, size - margin)]
    draw.rounded_rectangle(box, radius=radius, fill=255)
    return mask

def create_obsidian_canvas(size=2048):
    S = size
    margin = 180
    w = S - 2 * margin
    radius = 380
    squircle_box = [(margin, margin), (margin + w, margin + w)]
    
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    
    # macOS dock drop shadow
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_s = ImageDraw.Draw(shadow)
    draw_s.rounded_rectangle(
        [(margin + 12, margin + 28), (margin + w - 12, margin + w + 28)], 
        radius=radius, 
        fill=(0, 0, 0, 160)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=42))
    img.alpha_composite(shadow)
    
    # Pure Matte Obsidian Background
    mask = create_squircle_mask(S, margin, radius)
    bg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_bg = ImageDraw.Draw(bg)
    for y in range(margin, margin + w):
        t = (y - margin) / w
        r = int(22 * (1 - t) + 11 * t)
        g = int(26 * (1 - t) + 13 * t)
        b = int(32 * (1 - t) + 16 * t)
        draw_bg.line([(margin, y), (margin + w, y)], fill=(r, g, b, 255))
    bg.putalpha(mask)
    img.alpha_composite(bg)
    
    # Micro Bezel Rim (1px hairline)
    rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_rim = ImageDraw.Draw(rim)
    draw_rim.rounded_rectangle(squircle_box, radius=radius, outline=(255, 255, 255, 26), width=3)
    rim.putalpha(mask)
    img.alpha_composite(rim)
    
    return img

def render_unified_dual_arrow_smile(eye_style='capsule', target_size=1024):
    """
    Renders a unified P2P Smile Mark:
    - The Smile ribbon connects:
      - Left terminal: Streamlined Downward Arrow (Download ⬇)
      - Center: Parabolic golden smile curve (‿)
      - Right terminal: Streamlined Upward Arrow (Upload ⬆)
    - Eyes:
      - 'capsule': Two sleek modern pill nodes with neon reflections (Apple / Discord aesthetic)
      - 'chevron': Two faceted anime upward chevrons (^ ^)
      - 'wink': Left chevron (^), Right winking arrow (v)
    """
    S = 2048
    canvas = create_obsidian_canvas(S)
    cx, cy = S // 2, S // 2 - 10
    
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # =========================================================================
    # PART 1: EYES
    # =========================================================================
    eye_spacing = 260
    eye_y = cy - 140
    
    if eye_style == 'capsule':
        ew = 56
        eh = 120
        for side in (-1, 1):
            ecx = cx + side * eye_spacing
            box = [(ecx - ew, eye_y - eh), (ecx + ew, eye_y + eh)]
            
            # Ambient shadow
            esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
            draw_esh = ImageDraw.Draw(esh)
            draw_esh.rounded_rectangle([(b[0], b[1] + 20) for b in box], radius=ew, fill=(0, 20, 10, 150))
            esh = esh.filter(ImageFilter.GaussianBlur(radius=18))
            layer.alpha_composite(esh)
            
            # Fill capsule with luminous Electric Mint
            draw.rounded_rectangle(box, radius=ew, fill=(80, 255, 185, 255))
            # Subtle vertical specular highlight
            draw.line([(ecx - 14, eye_y - eh + 22), (ecx - 14, eye_y + eh - 22)], fill=(255, 255, 255, 200), width=8)

    elif eye_style == 'chevron':
        span = 165
        h = 125
        notch = 45
        for side in (-1, 1):
            ecx = cx + side * eye_spacing
            top_tip = (ecx, eye_y - 25)
            r_outer = (ecx + span, eye_y + h)
            r_inner = (ecx + span - 52, eye_y + h + 35)
            bottom_notch = (ecx, eye_y + notch)
            l_inner = (ecx - span + 52, eye_y + h + 35)
            l_outer = (ecx - span, eye_y + h)
            
            poly = [top_tip, r_outer, r_inner, bottom_notch, l_inner, l_outer]
            
            esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
            draw_esh = ImageDraw.Draw(esh)
            draw_esh.polygon([(p[0], p[1] + 20) for p in poly], fill=(0, 20, 10, 150))
            esh = esh.filter(ImageFilter.GaussianBlur(radius=18))
            layer.alpha_composite(esh)
            
            draw.polygon([top_tip, bottom_notch, l_inner, l_outer], fill=(85, 255, 187, 255))
            draw.polygon([top_tip, r_outer, r_inner, bottom_notch], fill=(24, 218, 136, 255))
            draw.line([l_outer, top_tip, r_outer], fill=(255, 255, 255, 230), width=8)
            draw.line([top_tip, bottom_notch], fill=(255, 255, 255, 180), width=5)

    # =========================================================================
    # PART 2: THE UNIFIED DUAL-ARROW SMILE STREAM (⬇ ➔ ‿ ➔ ⬆)
    # =========================================================================
    mouth_cy = cy + 90
    mouth_rx = 520
    mouth_ry = 340
    
    # We sample the parabolic curve from degree 32 to 148
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
        # Ribbon thickness: 110px at center, 75px at cheeks
        thick = 75 + 38 * t
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_ribbon = pts_outer + pts_inner
    
    # Left Terminal: Downward Arrowhead (Download ⬇)
    # Origin at left ribbon end
    lx_mid = (pts_outer[0][0] + pts_inner[-1][0]) / 2
    ly_mid = (pts_outer[0][1] + pts_inner[-1][1]) / 2
    
    # Arrow pointing down & slightly in
    l_tip = (lx_mid - 45, ly_mid + 115)       # Downward tip
    l_outer_wing = (lx_mid - 110, ly_mid - 30)
    l_notch = (lx_mid - 15, ly_mid - 5)
    l_inner_wing = (lx_mid + 75, ly_mid - 25)
    
    left_arrow_poly = [l_tip, l_outer_wing, l_notch, l_inner_wing]
    
    # Right Terminal: Upward Arrowhead (Upload ⬆)
    rx_mid = (pts_outer[-1][0] + pts_inner[0][0]) / 2
    ry_mid = (pts_outer[-1][1] + pts_inner[0][1]) / 2
    
    # Arrow pointing up & slightly out
    r_tip = (rx_mid + 45, ry_mid - 115)       # Upward tip
    r_outer_wing = (rx_mid + 110, ry_mid + 30)
    r_notch = (rx_mid + 15, ry_mid + 5)
    r_inner_wing = (rx_mid - 75, ry_mid + 25)
    
    right_arrow_poly = [r_tip, r_outer_wing, r_notch, r_inner_wing]
    
    # Composite drop shadow for smile + arrowheads
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_msh = ImageDraw.Draw(msh)
    draw_msh.polygon([(p[0], p[1] + 26) for p in smile_ribbon], fill=(0, 25, 12, 180))
    draw_msh.polygon([(p[0], p[1] + 26) for p in left_arrow_poly], fill=(0, 25, 12, 180))
    draw_msh.polygon([(p[0], p[1] + 26) for p in right_arrow_poly], fill=(0, 25, 12, 180))
    msh = msh.filter(ImageFilter.GaussianBlur(radius=28))
    layer.alpha_composite(msh)
    
    # Draw smile ribbon & arrowheads
    draw.polygon(smile_ribbon, fill=(0, 226, 110, 255))
    draw.polygon(left_arrow_poly, fill=(0, 205, 96, 255))
    draw.polygon(right_arrow_poly, fill=(50, 255, 168, 255))
    
    # Highlight lines
    draw.line(pts_outer, fill=(255, 255, 255, 170), width=8)
    draw.line([l_outer_wing, l_tip, l_inner_wing], fill=(255, 255, 255, 210), width=7)
    draw.line([r_inner_wing, r_tip, r_outer_wing], fill=(255, 255, 255, 220), width=7)
    
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

if __name__ == '__main__':
    out_dir = '/tmp/kazumi_unified'
    os.makedirs(out_dir, exist_ok=True)
    render_unified_dual_arrow_smile('capsule', 1024).save(os.path.join(out_dir, 'unified_capsule.png'))
    render_unified_dual_arrow_smile('chevron', 1024).save(os.path.join(out_dir, 'unified_chevron.png'))
    print("Unified dual arrow smiles generated in", out_dir)
