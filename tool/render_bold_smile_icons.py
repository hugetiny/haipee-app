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
    
    # 1. macOS dock drop shadow
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_s = ImageDraw.Draw(shadow)
    draw_s.rounded_rectangle(
        [(margin + 12, margin + 28), (margin + w - 12, margin + w + 28)], 
        radius=radius, 
        fill=(0, 0, 0, 150)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=42))
    img.alpha_composite(shadow)
    
    # 2. Pure Matte Obsidian Background (#14161E -> #0A0C0F)
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
    
    # 3. Micro Bezel Rim (1px hairline)
    rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_rim = ImageDraw.Draw(rim)
    draw_rim.rounded_rectangle(squircle_box, radius=radius, outline=(255, 255, 255, 24), width=3)
    rim.putalpha(mask)
    img.alpha_composite(rim)
    
    return img

def render_bold_origami_anime_smile(target_size=1024):
    """
    DESIGN 1: Bold Origami Anime Smile (Top-tier Japanese / Apple Cyber Aesthetic)
    - Substantial presence: Occupies ~68% of the frame, perfectly balanced.
    - EYES: Two bold, faceted upward chevron arrows (^ ^).
      - Left facet: Crisp Luminous Electric Mint (#55FFB8).
      - Right facet: Shaded Mint Jade (#16D886).
      - Center spine highlight & micro-bevels.
    - SMILE: A bold, wide, confident parabolic smile with an integrated upward arrow dimple on the right cheek,
      and an inward download curvature on the left cheek.
      - Body: Cyber Emerald gradient (#00EE78 -> #00B84D).
      - Faceted top rim highlight, realistic ambient contact shadow.
    """
    S = 2048
    canvas = create_obsidian_canvas(S)
    cx, cy = S // 2, S // 2 - 15  # optical center
    
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # =========================================================================
    # EYES: Bold, Substantial Upward Origami Chevrons (^ ^)
    # =========================================================================
    eye_y = cy - 220
    eye_spacing = 330
    eye_span = 200     # broad, substantial wings
    eye_h = 160        # tall, energetic
    notch_h = 60       # deep crisp inner notch
    
    for side in (-1, 1):
        ecx = cx + side * eye_spacing
        
        top_tip = (ecx, eye_y - 40)
        r_outer = (ecx + eye_span, eye_y + eye_h)
        r_inner = (ecx + eye_span - 65, eye_y + eye_h + 45)
        bottom_notch = (ecx, eye_y + notch_h)
        l_inner = (ecx - eye_span + 65, eye_y + eye_h + 45)
        l_outer = (ecx - eye_span, eye_y + eye_h)
        
        poly_full = [top_tip, r_outer, r_inner, bottom_notch, l_inner, l_outer]
        facet_left = [top_tip, bottom_notch, l_inner, l_outer]
        facet_right = [top_tip, r_outer, r_inner, bottom_notch]
        
        # Ambient drop shadow
        esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        draw_esh = ImageDraw.Draw(esh)
        draw_esh.polygon([(p[0], p[1] + 24) for p in poly_full], fill=(0, 20, 10, 160))
        esh = esh.filter(ImageFilter.GaussianBlur(radius=22))
        layer.alpha_composite(esh)
        
        # Draw facets
        draw.polygon(facet_left, fill=(85, 255, 187, 255))
        draw.polygon(facet_right, fill=(22, 216, 134, 255))
        
        # Crisp white spine & top highlights
        draw.line([l_outer, top_tip, r_outer], fill=(255, 255, 255, 220), width=8)
        draw.line([top_tip, bottom_notch], fill=(255, 255, 255, 180), width=5)

    # =========================================================================
    # SMILE: Bold, Radiant Parabolic Smile Ribbon with Integrated Arrow
    # =========================================================================
    mouth_cy = cy + 140
    mouth_rx = 600       # wide, generous smile
    mouth_ry = 420       # deep, warm, happy dip
    
    deg_start = 24
    deg_end = 156
    
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
        
        # Center is thick & warm (135px), gently tapering towards cheeks (105px)
        t = math.sin(rad)
        thick = 100 + 42 * t
        
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_ribbon = pts_outer + pts_inner
    
    # Left cheek: Rounded, soft organic dimple
    # Right cheek: Integrated bold UPWARD ARROWHEAD (Upload Dimple)
    rx_base = pts_outer[-1]
    rx_c, ry_c = rx_base[0], rx_base[1]
    
    # Bold arrowhead at ~40 degree angle
    tip = (rx_c + 85, ry_c - 85)
    r_wing = (rx_c + 75, ry_c + 70)
    inner_notch = (rx_c - 25, ry_c + 20)
    l_wing = (rx_c - 85, ry_c - 45)
    
    arrow_poly = [tip, r_wing, inner_notch, l_wing]
    
    # Ambient shadow for smile
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_msh = ImageDraw.Draw(msh)
    draw_msh.polygon([(p[0], p[1] + 28) for p in smile_ribbon], fill=(0, 25, 12, 180))
    draw_msh.polygon([(p[0], p[1] + 28) for p in arrow_poly], fill=(0, 25, 12, 180))
    msh = msh.filter(ImageFilter.GaussianBlur(radius=32))
    layer.alpha_composite(msh)
    
    # Draw smile body (Cyber Emerald)
    draw.polygon(smile_ribbon, fill=(0, 228, 112, 255))
    draw.polygon(arrow_poly, fill=(0, 245, 125, 255))
    
    # Upper rim highlight on smile
    draw.line(pts_outer, fill=(255, 255, 255, 180), width=8)
    draw.line([l_wing, tip, r_wing], fill=(255, 255, 255, 220), width=8)
    
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

def render_dual_arrow_loop_smile(target_size=1024):
    """
    DESIGN 2: The "Dual-Arrow Continuous Loop Smile"
    - The ENTIRE smile is formed by the two arrows:
      - Left side: A bold, stylized DOWNWARD Arrow (Download ⬇).
      - Center: Flowing smoothly into a wide, happy smile curve.
      - Right side: Rising proudly into an UPWARD Arrow (Upload ⬆).
      - Eyes: Two sleek rounded rectangular nodes with white neon pupil highlights.
    - Literal 1:1 synthesis: The download arrow and upload arrow ARE the smile.
    """
    S = 2048
    canvas = create_obsidian_canvas(S)
    cx, cy = S // 2, S // 2 - 20
    
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # Eyes: Dual Sleek Pill Capsules
    eye_y = cy - 200
    eye_spacing = 310
    ew = 60
    eh = 130
    
    for side in (-1, 1):
        ecx = cx + side * eye_spacing
        box = [(ecx - ew, eye_y - eh), (ecx + ew, eye_y + eh)]
        
        esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        draw_esh = ImageDraw.Draw(esh)
        draw_esh.rounded_rectangle([(b[0], b[1] + 22) for b in box], radius=ew, fill=(0, 20, 10, 150))
        esh = esh.filter(ImageFilter.GaussianBlur(radius=20))
        layer.alpha_composite(esh)
        
        draw.rounded_rectangle(box, radius=ew, fill=(80, 255, 185, 255))
        draw.line([(ecx - 14, eye_y - eh + 24), (ecx - 14, eye_y + eh - 24)], fill=(255, 255, 255, 200), width=8)

    # Smile Ribbon with BOTH Arrowheads
    mouth_cy = cy + 130
    mouth_rx = 600
    mouth_ry = 420
    
    pts_outer = []
    pts_inner = []
    
    for deg in range(30, 151, 2):
        rad = math.radians(deg)
        x = cx - mouth_rx * math.cos(rad)
        y = mouth_cy + mouth_ry * math.sin(rad)
        nx = -math.cos(rad)
        ny = math.sin(rad)
        nl = math.sqrt(nx*nx + ny*ny)
        nx /= nl
        ny /= nl
        t = math.sin(rad)
        thick = 95 + 40 * t
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_ribbon = pts_outer + pts_inner
    
    # Left Arrowhead (Pointing DOWN / inward - Download)
    lx = pts_outer[0][0]
    ly = pts_outer[0][1]
    left_arrow = [
        (lx - 50, ly + 120),  # Tip pointing down
        (lx - 120, ly - 45),
        (lx - 35, ly - 20),
        (lx + 55, ly - 20),
        (lx + 110, ly - 45),
    ]
    
    # Right Arrowhead (Pointing UP / outward - Upload)
    rx = pts_outer[-1][0]
    ry = pts_outer[-1][1]
    right_arrow = [
        (rx + 60, ry - 120),  # Tip pointing up
        (rx + 120, ry + 45),
        (rx + 35, ry + 20),
        (rx - 55, ry + 20),
        (rx - 110, ry + 45),
    ]
    
    # Ambient shadow
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_msh = ImageDraw.Draw(msh)
    draw_msh.polygon([(p[0], p[1] + 28) for p in smile_ribbon], fill=(0, 25, 12, 180))
    draw_msh.polygon([(p[0], p[1] + 28) for p in left_arrow], fill=(0, 25, 12, 180))
    draw_msh.polygon([(p[0], p[1] + 28) for p in right_arrow], fill=(0, 25, 12, 180))
    msh = msh.filter(ImageFilter.GaussianBlur(radius=32))
    layer.alpha_composite(msh)
    
    draw.polygon(smile_ribbon, fill=(0, 226, 110, 255))
    draw.polygon(left_arrow, fill=(0, 205, 95, 255))
    draw.polygon(right_arrow, fill=(60, 255, 175, 255))
    
    draw.line(pts_outer, fill=(255, 255, 255, 170), width=8)
    
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

def render_interlocking_arrow_emblem(target_size=1024):
    """
    DESIGN 3: "The Origami Chevron Smile Face" (Chevrons + Central Down Chevron)
    - Eyes: Two bold upward chevrons (^ ^)
    - Nose / Forehead: Central downward chevron (v) creating the download anchor
    - Mouth: Smooth, full smiling arc (‿)
    - Together, it creates an unforgettable, iconic Japanese Cyber-Totem smile!
    """
    S = 2048
    canvas = create_obsidian_canvas(S)
    cx, cy = S // 2, S // 2 - 15
    
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # Eyes: Dual Upward Chevrons (^ ^)
    eye_y = cy - 220
    eye_spacing = 330
    eye_span = 190
    eye_h = 150
    notch_h = 55
    
    for side in (-1, 1):
        ecx = cx + side * eye_spacing
        top_tip = (ecx, eye_y - 35)
        r_outer = (ecx + eye_span, eye_y + eye_h)
        r_inner = (ecx + eye_span - 60, eye_y + eye_h + 40)
        bottom_notch = (ecx, eye_y + notch_h)
        l_inner = (ecx - eye_span + 60, eye_y + eye_h + 40)
        l_outer = (ecx - eye_span, eye_y + eye_h)
        
        poly = [top_tip, r_outer, r_inner, bottom_notch, l_inner, l_outer]
        
        esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        draw_esh = ImageDraw.Draw(esh)
        draw_esh.polygon([(p[0], p[1] + 24) for p in poly], fill=(0, 20, 10, 160))
        esh = esh.filter(ImageFilter.GaussianBlur(radius=20))
        layer.alpha_composite(esh)
        
        draw.polygon([top_tip, bottom_notch, l_inner, l_outer], fill=(85, 255, 187, 255))
        draw.polygon([top_tip, r_outer, r_inner, bottom_notch], fill=(22, 216, 134, 255))
        draw.line([l_outer, top_tip, r_outer], fill=(255, 255, 255, 220), width=8)
        draw.line([top_tip, bottom_notch], fill=(255, 255, 255, 180), width=5)

    # Downward Chevron Nose Anchor
    nose_y = cy - 20
    nw = 90
    nh = 75
    notch_n = 28
    
    nose_poly = [
        (cx, nose_y + nh),
        (cx + nw, nose_y - 15),
        (cx + nw - 32, nose_y - 45),
        (cx, nose_y + notch_n),
        (cx - nw + 32, nose_y - 45),
        (cx - nw, nose_y - 15),
    ]
    
    nsh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_nsh = ImageDraw.Draw(nsh)
    draw_nsh.polygon([(p[0], p[1] + 16) for p in nose_poly], fill=(0, 20, 10, 140))
    nsh = nsh.filter(ImageFilter.GaussianBlur(radius=16))
    layer.alpha_composite(nsh)
    
    draw.polygon([(cx, nose_y + nh), (cx, nose_y + notch_n), (cx - nw + 32, nose_y - 45), (cx - nw, nose_y - 15)], fill=(60, 250, 165, 255))
    draw.polygon([(cx, nose_y + nh), (cx + nw, nose_y - 15), (cx + nw - 32, nose_y - 45), (cx, nose_y + notch_n)], fill=(20, 210, 130, 255))
    draw.line([(cx - nw, nose_y - 15), (cx, nose_y + nh), (cx + nw, nose_y - 15)], fill=(255, 255, 255, 200), width=6)

    # Full Curved Smile Ribbon
    mouth_cy = cy + 140
    mouth_rx = 580
    mouth_ry = 400
    
    pts_outer = []
    pts_inner = []
    
    for deg in range(22, 159, 2):
        rad = math.radians(deg)
        x = cx - mouth_rx * math.cos(rad)
        y = mouth_cy + mouth_ry * math.sin(rad)
        nx = -math.cos(rad)
        ny = math.sin(rad)
        nl = math.sqrt(nx*nx + ny*ny)
        nx /= nl
        ny /= nl
        t = math.sin(rad)
        thick = 95 + 38 * t
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_ribbon = pts_outer + pts_inner
    
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_msh = ImageDraw.Draw(msh)
    draw_msh.polygon([(p[0], p[1] + 28) for p in smile_ribbon], fill=(0, 25, 12, 180))
    msh = msh.filter(ImageFilter.GaussianBlur(radius=30))
    layer.alpha_composite(msh)
    
    draw.polygon(smile_ribbon, fill=(0, 226, 110, 255))
    draw.line(pts_outer, fill=(255, 255, 255, 180), width=8)
    
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

if __name__ == '__main__':
    out_dir = '/tmp/kazumi_bold_smiles'
    os.makedirs(out_dir, exist_ok=True)
    render_bold_origami_anime_smile(1024).save(os.path.join(out_dir, 'bold_1_anime_smile.png'))
    render_dual_arrow_loop_smile(1024).save(os.path.join(out_dir, 'bold_2_loop_smile.png'))
    render_interlocking_arrow_emblem(1024).save(os.path.join(out_dir, 'bold_3_chevron_face.png'))
    print("Bold smile icons generated in", out_dir)
