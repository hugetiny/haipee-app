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

def render_concept_emblem_E(target_size=1024):
    """
    Concept E: "The Smiling Arrow Totem" (Current Logo Morph)
    - Take the exact structural layout of the current icon:
      - Outer shape: Downward Arrow body in Cyber Emerald (#00EE78 / #00B84D).
        Instead of a sharp aggressive V-tip, its lower wings curve into a warm, confident SMILE!
      - Inner shape: Elevated Upward Arrow in Electric Mint (#55FFB8).
        Elevated with realistic drop shadow and faceted 3D lighting.
      - Together, the outer downward arrow's smile curve cradles the inner upward arrow,
        forming a unified, high-tech, smiling arrow emblem!
    """
    S = 2048
    canvas = create_obsidian_canvas(S)
    cx, cy = S // 2, S // 2 + 10
    
    # 1. Outer Arrow with Smiling Bottom Arc
    # Upper stem:
    stem_w = 260
    stem_top = cy - 580
    stem_notch = stem_top + 45
    shoulder_y = cy + 40
    
    # Lower wings curve smoothly into a smile
    # Let's construct the polygon for left and right facets of outer smiling arrow
    outer_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_out = ImageDraw.Draw(outer_layer)
    
    # We sample the bottom smile curve
    # Left wing tip: (cx - 520, cy + 120)
    # Right wing tip: (cx + 520, cy + 120)
    # Bottom apex: (cx, cy + 540) - rounded smile
    smile_pts_left = []
    smile_pts_right = []
    
    rx = 480
    ry = 380
    center_y = cy + 160
    
    for deg in range(30, 91, 2):
        rad = math.radians(deg)
        x = cx - rx * math.cos(rad)
        y = center_y + ry * math.sin(rad)
        smile_pts_left.append((x, y))
        
    for deg in range(90, 151, 2):
        rad = math.radians(deg)
        x = cx - rx * math.cos(rad)
        y = center_y + ry * math.sin(rad)
        smile_pts_right.append((x, y))
        
    left_poly = [
        (cx, stem_notch),
        (cx - stem_w, stem_top),
        (cx - stem_w, shoulder_y),
        (cx - 520, shoulder_y + 80),
    ] + smile_pts_left + [(cx, center_y + ry)]
    
    right_poly = [
        (cx, stem_notch),
        (cx + stem_w, stem_top),
        (cx + stem_w, shoulder_y),
        (cx + 520, shoulder_y + 80),
    ] + smile_pts_right[::-1] + [(cx, center_y + ry)]
    
    full_poly = left_poly + right_poly[::-1]
    
    # Outer drop shadow
    out_sh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_osh = ImageDraw.Draw(out_sh)
    draw_osh.polygon([(p[0], p[1] + 28) for p in full_poly], fill=(0, 25, 12, 170))
    out_sh = out_sh.filter(ImageFilter.GaussianBlur(radius=32))
    canvas.alpha_composite(out_sh)
    
    # Draw facets
    draw_out.polygon(left_poly, fill=(0, 238, 120, 255))
    draw_out.polygon(right_poly, fill=(0, 186, 78, 255))
    draw_out.line([(cx, stem_notch), (cx, center_y + ry)], fill=(255, 255, 255, 60), width=3)
    draw_out.line([(cx - stem_w, stem_top), (cx, stem_notch)], fill=(255, 255, 255, 140), width=6)
    canvas.alpha_composite(outer_layer)
    
    # 2. Elevated Upward Arrow (Upload ⬆)
    in_stem = 95
    in_wing = 210
    in_top = cy - 300
    in_shoulder = cy + 0
    in_wing_tip = cy + 50
    in_bottom = cy + 340
    in_notch = in_bottom - 35
    
    in_left = [
        (cx, in_top),
        (cx - in_wing, in_wing_tip),
        (cx - in_stem, in_shoulder),
        (cx - in_stem, in_bottom),
        (cx, in_notch),
    ]
    in_right = [
        (cx, in_top),
        (cx + in_wing, in_wing_tip),
        (cx + in_stem, in_shoulder),
        (cx + in_stem, in_bottom),
        (cx, in_notch),
    ]
    in_poly = [
        (cx, in_top),
        (cx + in_wing, in_wing_tip),
        (cx + in_stem, in_shoulder),
        (cx + in_stem, in_bottom),
        (cx, in_notch),
        (cx - in_stem, in_bottom),
        (cx - in_stem, in_shoulder),
        (cx - in_wing, in_wing_tip),
    ]
    
    in_sh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_ish = ImageDraw.Draw(in_sh)
    draw_ish.polygon([(p[0], p[1] + 20) for p in in_poly], fill=(0, 20, 10, 160))
    in_sh = in_sh.filter(ImageFilter.GaussianBlur(radius=22))
    canvas.alpha_composite(in_sh)
    
    in_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_in = ImageDraw.Draw(in_layer)
    draw_in.polygon(in_left, fill=(80, 255, 185, 255))
    draw_in.polygon(in_right, fill=(20, 215, 135, 255))
    draw_in.line([(cx, in_top), (cx, in_notch)], fill=(255, 255, 255, 160), width=4)
    draw_in.line([(cx - in_wing, in_wing_tip), (cx, in_top)], fill=(255, 255, 255, 180), width=5)
    canvas.alpha_composite(in_layer)
    
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

def render_concept_emblem_F(target_size=1024):
    """
    Concept F: "The Kazumi Joyful Smile Loop" (Two Arrows forming a Happy Smile Ring)
    - Two curved aerodynamic arrows in dynamic orbital balance:
      - Upper/left arrow (⬇) plunges down into the loop
      - Lower/right arrow (⬆) curves across in a joyful, radiant smile!
      - Center: Two stylish glowing eye capsules.
    """
    S = 2048
    canvas = create_obsidian_canvas(S)
    cx, cy = S // 2, S // 2 - 20
    
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # Two anime smiling eyes: Sleek curved arcs (⌒ ⌒)
    # Happy squinting anime eyes!
    eye_y = cy - 140
    spacing = 280
    erx = 120
    ery = 70
    
    for side in (-1, 1):
        ecx = cx + side * spacing
        bbox = [(ecx - erx, eye_y - ery), (ecx + erx, eye_y + ery)]
        # Curved upward arc (smiling closed eye)
        draw.arc(bbox, start=200, end=340, fill=(80, 255, 185, 255), width=38)
        
    # The Smile: Sweeping bold smile arrow
    mouth_cy = cy + 80
    mouth_rx = 520
    mouth_ry = 360
    
    # Parabolic smile ribbon
    pts_outer = []
    pts_inner = []
    for deg in range(25, 156, 2):
        rad = math.radians(deg)
        x = cx - mouth_rx * math.cos(rad)
        y = mouth_cy + mouth_ry * math.sin(rad)
        nx = -math.cos(rad)
        ny = math.sin(rad)
        nl = math.sqrt(nx*nx + ny*ny)
        nx /= nl
        ny /= nl
        t = math.sin(rad)
        thick = 90 + 36 * t
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_poly = pts_outer + pts_inner
    
    # Left cheek: Downward arrow dimple
    # Right cheek: Upward arrow dimple
    rx_base = pts_outer[-1]
    rx, ry = rx_base[0], rx_base[1]
    r_arrow = [
        (rx + 65, ry - 75),  # Tip pointing up-right
        (rx + 60, ry + 55),
        (rx - 25, ry + 15),
        (rx - 65, ry - 40),
    ]
    
    lx_base = pts_outer[0]
    lx, ly = lx_base[0], lx_base[1]
    l_arrow = [
        (lx - 65, ly - 75),  # Tip pointing up-left
        (lx - 60, ly + 55),
        (lx + 25, ly + 15),
        (lx + 65, ly - 40),
    ]
    
    # Ambient shadow
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_msh = ImageDraw.Draw(msh)
    draw_msh.polygon([(p[0], p[1] + 28) for p in smile_poly], fill=(0, 25, 12, 180))
    draw_msh.polygon([(p[0], p[1] + 28) for p in r_arrow], fill=(0, 25, 12, 180))
    draw_msh.polygon([(p[0], p[1] + 28) for p in l_arrow], fill=(0, 25, 12, 180))
    msh = msh.filter(ImageFilter.GaussianBlur(radius=30))
    layer.alpha_composite(msh)
    
    draw.polygon(smile_poly, fill=(0, 226, 110, 255))
    draw.polygon(r_arrow, fill=(0, 245, 125, 255))
    draw.polygon(l_arrow, fill=(0, 245, 125, 255))
    draw.line(pts_outer, fill=(255, 255, 255, 170), width=8)
    
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

if __name__ == '__main__':
    out_dir = '/tmp/kazumi_emblems'
    os.makedirs(out_dir, exist_ok=True)
    render_concept_emblem_E(1024).save(os.path.join(out_dir, 'emblem_E.png'))
    render_concept_emblem_F(1024).save(os.path.join(out_dir, 'emblem_F.png'))
    print("Emblems E and F generated in", out_dir)
