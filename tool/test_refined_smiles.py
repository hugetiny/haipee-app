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
        fill=(0, 0, 0, 150)
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
    
    # Micro Bezel Rim
    rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_rim = ImageDraw.Draw(rim)
    draw_rim.rounded_rectangle(squircle_box, radius=radius, outline=(255, 255, 255, 24), width=3)
    rim.putalpha(mask)
    img.alpha_composite(rim)
    
    return img

def render_refined_1_harmonious_cyber_smile(target_size=1024):
    """
    Refined 1: Golden Ratio Anime Chevron Smile (^ ‿ ^)
    - Tighter, warmer, perfectly balanced facial proportions.
    - Eyes: Two faceted upward chevron arrows (^ ^) in Electric Mint.
    - Mouth: A bold, warm parabolic smile with dual lifting cheek dimples.
    """
    S = 2048
    canvas = create_obsidian_canvas(S)
    cx, cy = S // 2, S // 2
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # EYES: Golden Ratio Proportions
    eye_y = cy - 150
    eye_spacing = 260   # Brought closer (260 vs 330)
    eye_span = 175
    eye_h = 135
    notch_h = 50
    
    for side in (-1, 1):
        ecx = cx + side * eye_spacing
        top_tip = (ecx, eye_y - 30)
        r_outer = (ecx + eye_span, eye_y + eye_h)
        r_inner = (ecx + eye_span - 55, eye_y + eye_h + 38)
        bottom_notch = (ecx, eye_y + notch_h)
        l_inner = (ecx - eye_span + 55, eye_y + eye_h + 38)
        l_outer = (ecx - eye_span, eye_y + eye_h)
        
        poly_full = [top_tip, r_outer, r_inner, bottom_notch, l_inner, l_outer]
        facet_left = [top_tip, bottom_notch, l_inner, l_outer]
        facet_right = [top_tip, r_outer, r_inner, bottom_notch]
        
        esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        draw_esh = ImageDraw.Draw(esh)
        draw_esh.polygon([(p[0], p[1] + 20) for p in poly_full], fill=(0, 20, 10, 160))
        esh = esh.filter(ImageFilter.GaussianBlur(radius=18))
        layer.alpha_composite(esh)
        
        draw.polygon(facet_left, fill=(85, 255, 187, 255))
        draw.polygon(facet_right, fill=(24, 218, 136, 255))
        draw.line([l_outer, top_tip, r_outer], fill=(255, 255, 255, 230), width=8)
        draw.line([top_tip, bottom_notch], fill=(255, 255, 255, 180), width=5)

    # MOUTH: Full, Radiant Smile Arc (Brought closer to eyes: cy + 120)
    mouth_cy = cy + 100
    mouth_rx = 520
    mouth_ry = 340
    
    deg_start = 22
    deg_end = 158
    
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
        thick = 96 + 36 * t
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_ribbon = pts_outer + pts_inner
    
    # Cheek dimples: Dual lifted arrowheads at cheeks (Smiling Cheeks)
    # Right cheek:
    rx_c, ry_c = pts_outer[-1][0], pts_outer[-1][1]
    tip_r = (rx_c + 65, ry_c - 70)
    wing_r1 = (rx_c + 55, ry_c + 50)
    wing_r2 = (rx_c - 20, ry_c + 15)
    wing_r3 = (rx_c - 60, ry_c - 35)
    r_dimple = [tip_r, wing_r1, wing_r2, wing_r3]
    
    # Left cheek:
    lx_c, ly_c = pts_outer[0][0], pts_outer[0][1]
    tip_l = (lx_c - 65, ly_c - 70)
    wing_l1 = (lx_c - 55, ly_c + 50)
    wing_l2 = (lx_c + 20, ly_c + 15)
    wing_l3 = (lx_c + 60, ly_c - 35)
    l_dimple = [tip_l, wing_l1, wing_l2, wing_l3]
    
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_msh = ImageDraw.Draw(msh)
    draw_msh.polygon([(p[0], p[1] + 26) for p in smile_ribbon], fill=(0, 25, 12, 180))
    draw_msh.polygon([(p[0], p[1] + 26) for p in r_dimple], fill=(0, 25, 12, 180))
    draw_msh.polygon([(p[0], p[1] + 26) for p in l_dimple], fill=(0, 25, 12, 180))
    msh = msh.filter(ImageFilter.GaussianBlur(radius=28))
    layer.alpha_composite(msh)
    
    draw.polygon(smile_ribbon, fill=(0, 228, 112, 255))
    draw.polygon(r_dimple, fill=(0, 245, 125, 255))
    draw.polygon(l_dimple, fill=(0, 245, 125, 255))
    
    draw.line(pts_outer, fill=(255, 255, 255, 170), width=8)
    draw.line([wing_r3, tip_r, wing_r1], fill=(255, 255, 255, 210), width=6)
    draw.line([wing_l3, tip_l, wing_l1], fill=(255, 255, 255, 210), width=6)
    
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

def render_refined_2_winking_p2p(target_size=1024):
    """
    Refined 2: "The Winking P2P Anime Smile" (^ ‿ v)
    - Left Eye: Upward Chevron ^ (Upload ⬆)
    - Right Eye: Winking Downward Chevron v (Download ⬇)
    - Mouth: Joyful, confident smile arc (‿)
    - Meaning: The download arrow and upload arrow form a winking anime face!
    """
    S = 2048
    canvas = create_obsidian_canvas(S)
    cx, cy = S // 2, S // 2
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    eye_spacing = 260
    eye_span = 165
    eye_h = 125
    notch_h = 45
    
    # Left Eye: Upward Chevron ^ (Upload)
    ecx = cx - eye_spacing
    eye_y = cy - 150
    top_tip = (ecx, eye_y - 30)
    r_outer = (ecx + eye_span, eye_y + eye_h)
    r_inner = (ecx + eye_span - 52, eye_y + eye_h + 35)
    bottom_notch = (ecx, eye_y + notch_h)
    l_inner = (ecx - eye_span + 52, eye_y + eye_h + 35)
    l_outer = (ecx - eye_span, eye_y + eye_h)
    poly_left = [top_tip, r_outer, r_inner, bottom_notch, l_inner, l_outer]
    
    esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_esh = ImageDraw.Draw(esh)
    draw_esh.polygon([(p[0], p[1] + 20) for p in poly_left], fill=(0, 20, 10, 160))
    esh = esh.filter(ImageFilter.GaussianBlur(radius=18))
    layer.alpha_composite(esh)
    
    draw.polygon([top_tip, bottom_notch, l_inner, l_outer], fill=(85, 255, 187, 255))
    draw.polygon([top_tip, r_outer, r_inner, bottom_notch], fill=(24, 218, 136, 255))
    draw.line([l_outer, top_tip, r_outer], fill=(255, 255, 255, 230), width=8)
    
    # Right Eye: Winking Downward Chevron v (Download)
    ecx_r = cx + eye_spacing
    eye_yr = cy - 150
    # Inverted Chevron pointing down:
    bot_tip = (ecx_r, eye_yr + eye_h + 10)
    r_top_out = (ecx_r + eye_span, eye_yr - 15)
    r_top_in = (ecx_r + eye_span - 52, eye_yr - 50)
    top_notch_r = (ecx_r, eye_yr + eye_h - notch_h)
    l_top_in = (ecx_r - eye_span + 52, eye_yr - 50)
    l_top_out = (ecx_r - eye_span, eye_yr - 15)
    poly_right = [bot_tip, r_top_out, r_top_in, top_notch_r, l_top_in, l_top_out]
    
    esh2 = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_esh2 = ImageDraw.Draw(esh2)
    draw_esh2.polygon([(p[0], p[1] + 20) for p in poly_right], fill=(0, 20, 10, 160))
    esh2 = esh2.filter(ImageFilter.GaussianBlur(radius=18))
    layer.alpha_composite(esh2)
    
    draw.polygon([bot_tip, top_notch_r, l_top_in, l_top_out], fill=(85, 255, 187, 255))
    draw.polygon([bot_tip, r_top_out, r_top_in, top_notch_r], fill=(24, 218, 136, 255))
    draw.line([l_top_out, bot_tip, r_top_out], fill=(255, 255, 255, 230), width=8)
    
    # Mouth: Same bold radiant smile
    mouth_cy = cy + 100
    mouth_rx = 520
    mouth_ry = 340
    deg_start = 22
    deg_end = 158
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
        thick = 96 + 36 * t
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_ribbon = pts_outer + pts_inner
    
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_msh = ImageDraw.Draw(msh)
    draw_msh.polygon([(p[0], p[1] + 26) for p in smile_ribbon], fill=(0, 25, 12, 180))
    msh = msh.filter(ImageFilter.GaussianBlur(radius=28))
    layer.alpha_composite(msh)
    
    draw.polygon(smile_ribbon, fill=(0, 228, 112, 255))
    draw.line(pts_outer, fill=(255, 255, 255, 170), width=8)
    
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

if __name__ == '__main__':
    out_dir = '/tmp/kazumi_refined'
    os.makedirs(out_dir, exist_ok=True)
    render_refined_1_harmonious_cyber_smile(1024).save(os.path.join(out_dir, 'refined_1_harmonious.png'))
    render_refined_2_winking_p2p(1024).save(os.path.join(out_dir, 'refined_2_winking.png'))
    print("Refined smiles generated in", out_dir)
