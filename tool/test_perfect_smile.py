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

def render_perfect_clean_anime_smile(target_size=1024):
    """
    Candidate 1: "The Pristine Anime Cyber Smile" (^ ‿ ^)
    - Eyes: Two faceted Electric Mint origami chevrons (^ ^).
      Represent the Upward Arrows (Upload ⬆ / High energy).
    - Mouth: A bold, beautifully tapered parabolic smile in Cyber Emerald (#00EE78 / #00B84D).
      Tapered elegantly at the cheeks, perfectly rounded terminals.
      Represents the Downward Arrow morphed into an upward-curving smile.
    - Super clean, iconic, zero visual clutter, 100% Apple Design Award aesthetic.
    """
    S = 2048
    canvas = create_obsidian_canvas(S)
    cx, cy = S // 2, S // 2 - 10
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # EYES: Two Faceted Upward Chevrons (^ ^)
    eye_y = cy - 140
    eye_spacing = 260
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
        
        # Soft shadow
        esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        draw_esh = ImageDraw.Draw(esh)
        draw_esh.polygon([(p[0], p[1] + 20) for p in poly_full], fill=(0, 20, 10, 160))
        esh = esh.filter(ImageFilter.GaussianBlur(radius=18))
        layer.alpha_composite(esh)
        
        # Facets
        draw.polygon(facet_left, fill=(85, 255, 187, 255))
        draw.polygon(facet_right, fill=(24, 218, 136, 255))
        draw.line([l_outer, top_tip, r_outer], fill=(255, 255, 255, 230), width=8)
        draw.line([top_tip, bottom_notch], fill=(255, 255, 255, 180), width=5)

    # MOUTH: Tapered Elegant Parabolic Smile
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
        # Tapering: 110px at center, 65px at cheeks
        thick = 65 + 48 * t
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_ribbon = pts_outer + pts_inner
    
    # Shadow
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_msh = ImageDraw.Draw(msh)
    draw_msh.polygon([(p[0], p[1] + 24) for p in smile_ribbon], fill=(0, 25, 12, 180))
    # Round caps shadow
    draw_msh.ellipse([(pts_outer[0][0] - 32, pts_outer[0][1] - 8), (pts_outer[0][0] + 32, pts_outer[0][1] + 56)], fill=(0, 25, 12, 180))
    draw_msh.ellipse([(pts_outer[-1][0] - 32, pts_outer[-1][1] - 8), (pts_outer[-1][0] + 32, pts_outer[-1][1] + 56)], fill=(0, 25, 12, 180))
    msh = msh.filter(ImageFilter.GaussianBlur(radius=28))
    layer.alpha_composite(msh)
    
    # Draw body
    draw.polygon(smile_ribbon, fill=(0, 228, 112, 255))
    # Smooth rounded end caps
    r_cap = 32
    c_left = pts_outer[0]
    c_right = pts_outer[-1]
    draw.ellipse([(c_left[0] - r_cap, c_left[1] - r_cap + 15), (c_left[0] + r_cap, c_left[1] + r_cap + 15)], fill=(0, 228, 112, 255))
    draw.ellipse([(c_right[0] - r_cap, c_right[1] - r_cap + 15), (c_right[0] + r_cap, c_right[1] + r_cap + 15)], fill=(0, 228, 112, 255))
    
    # Upper rim highlight
    draw.line(pts_outer, fill=(255, 255, 255, 180), width=8)
    
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

def render_amazon_arrow_smile(target_size=1024):
    """
    Candidate 2: "The Stream Arrow Smile"
    - Eyes: Two faceted Electric Mint origami chevrons (^ ^).
    - Mouth: The right cheek seamlessly resolves into a sleek upward arrow (Upload ⬆),
      like Amazon's famous smile arrow, but in cutting-edge Cyber Emerald!
    """
    S = 2048
    canvas = create_obsidian_canvas(S)
    cx, cy = S // 2, S // 2 - 10
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # EYES
    eye_y = cy - 140
    eye_spacing = 260
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

    # MOUTH: Parabolic smile ribbon with sleek integrated right arrowhead
    mouth_cy = cy + 100
    mouth_rx = 520
    mouth_ry = 340
    deg_start = 25
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
        thick = 65 + 48 * t
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_ribbon = pts_outer + pts_inner
    
    # Right arrow: Sweeps up along the curve's trajectory (~45 deg)
    rx_c, ry_c = pts_outer[-1][0], pts_outer[-1][1]
    tip = (rx_c + 55, ry_c - 75)
    r_barb = (rx_c + 75, ry_c + 35)
    notch = (rx_c + 10, ry_c + 20)
    l_barb = (rx_c - 55, ry_c - 15)
    arrow_poly = [tip, r_barb, notch, l_barb]
    
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_msh = ImageDraw.Draw(msh)
    draw_msh.polygon([(p[0], p[1] + 24) for p in smile_ribbon], fill=(0, 25, 12, 180))
    draw_msh.polygon([(p[0], p[1] + 24) for p in arrow_poly], fill=(0, 25, 12, 180))
    msh = msh.filter(ImageFilter.GaussianBlur(radius=28))
    layer.alpha_composite(msh)
    
    draw.polygon(smile_ribbon, fill=(0, 228, 112, 255))
    draw.polygon(arrow_poly, fill=(0, 245, 125, 255))
    
    # Left round cap
    c_left = pts_outer[0]
    draw.ellipse([(c_left[0] - 32, c_left[1] - 17), (c_left[0] + 32, c_left[1] + 47)], fill=(0, 228, 112, 255))
    
    draw.line(pts_outer, fill=(255, 255, 255, 180), width=8)
    draw.line([l_barb, tip, r_barb], fill=(255, 255, 255, 210), width=7)
    
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

if __name__ == '__main__':
    out_dir = '/tmp/kazumi_perfect'
    os.makedirs(out_dir, exist_ok=True)
    render_perfect_clean_anime_smile(1024).save(os.path.join(out_dir, 'perfect_clean.png'))
    render_amazon_arrow_smile(1024).save(os.path.join(out_dir, 'amazon_arrow.png'))
    print("Perfect smiles generated in", out_dir)
