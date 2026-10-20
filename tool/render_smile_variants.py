import os
import math
from PIL import Image, ImageDraw, ImageFilter

def create_squircle_mask(size, margin, radius):
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    box = [(margin, margin), (size - margin, size - margin)]
    draw.rounded_rectangle(box, radius=radius, fill=255)
    return mask

def create_base_canvas(size=2048):
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
        fill=(0, 0, 0, 140)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=42))
    img.alpha_composite(shadow)
    
    # 2. Pure Matte Obsidian Background (#14171E -> #0A0C0F)
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

def render_variant_1_anime_chevrons(target_size=1024):
    """
    Variant 1: "The Anime P2P Smile" (^ ‿ ^)
    - Eyes: Two sleek geometric upward chevron arrows (^ ^) in Electric Mint (#4EFFB2).
      Faceted lighting with center spine highlight.
    - Mouth: A broad, joyful, sweeping curved smile in Cyber Emerald (#00DC6C -> #00B84D).
      Right cheek terminates in an upward arrow dimple (uploading joy),
      Left cheek balances with smooth corner.
    - Soft ambient drop shadows behind all elements.
    """
    S = 2048
    canvas = create_base_canvas(S)
    cx, cy = S // 2, S // 2
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # EYES: Chevrons (^ ^)
    eye_y = cy - 140
    eye_spacing = 260
    eye_span = 140
    eye_h = 110
    
    for side in (-1, 1):
        ecx = cx + side * eye_spacing
        pts_left = [
            (ecx, eye_y - 25),
            (ecx - eye_span, eye_y + eye_h),
            (ecx - eye_span + 45, eye_y + eye_h + 35),
            (ecx, eye_y + 35),
        ]
        pts_right = [
            (ecx, eye_y - 25),
            (ecx + eye_span, eye_y + eye_h),
            (ecx + eye_span - 45, eye_y + eye_h + 35),
            (ecx, eye_y + 35),
        ]
        full_eye = [
            (ecx, eye_y - 25),
            (ecx + eye_span, eye_y + eye_h),
            (ecx + eye_span - 45, eye_y + eye_h + 35),
            (ecx, eye_y + 35),
            (ecx - eye_span + 45, eye_y + eye_h + 35),
            (ecx - eye_span, eye_y + eye_h),
        ]
        # Drop shadow for eye
        esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        draw_esh = ImageDraw.Draw(esh)
        draw_esh.polygon([(p[0], p[1] + 18) for p in full_eye], fill=(0, 20, 10, 150))
        esh = esh.filter(ImageFilter.GaussianBlur(radius=18))
        layer.alpha_composite(esh)
        
        # Faceted fill: left facet slightly lighter, right facet rich mint
        draw.polygon(pts_left, fill=(90, 255, 195, 255))
        draw.polygon(pts_right, fill=(35, 230, 145, 255))
        # Top ridge highlight
        draw.line([(ecx - eye_span, eye_y + eye_h), (ecx, eye_y - 25), (ecx + eye_span, eye_y + eye_h)], 
                  fill=(255, 255, 255, 200), width=6)
        draw.line([(ecx, eye_y - 25), (ecx, eye_y + 35)], fill=(255, 255, 255, 150), width=4)

    # MOUTH: Parabolic smile with arrow accent
    mouth_cy = cy + 80
    mouth_rx = 480
    mouth_ry = 340
    thickness = 88
    
    start_deg = 18
    end_deg = 162
    
    points_top = []
    points_bot = []
    
    for deg in range(start_deg, end_deg + 1, 2):
        rad = math.radians(deg)
        x = cx - mouth_rx * math.cos(rad)
        y = mouth_cy + mouth_ry * math.sin(rad)
        nx = -math.cos(rad)
        ny = math.sin(rad)
        nl = math.sqrt(nx*nx + ny*ny)
        nx /= nl
        ny /= nl
        points_top.append((x - nx * (thickness / 2), y - ny * (thickness / 2)))
        points_bot.insert(0, (x + nx * (thickness / 2), y + ny * (thickness / 2)))
    
    # Let's attach an upward-pointing arrowhead to the right terminal!
    rx_mid = points_top[len(points_top)-1][0]
    ry_mid = points_top[len(points_top)-1][1]
    
    arrow_head = [
        (rx_mid + 85, ry_mid - 70),  # Tip pointing up-right
        (rx_mid + 50, ry_mid + 90),
        (rx_mid - 40, ry_mid + 40),
        (rx_mid - 75, ry_mid - 65),
    ]
    
    smile_poly = points_top + points_bot
    
    # Shadow
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_msh = ImageDraw.Draw(msh)
    draw_msh.polygon([(p[0], p[1] + 24) for p in smile_poly], fill=(0, 25, 12, 170))
    msh = msh.filter(ImageFilter.GaussianBlur(radius=26))
    layer.alpha_composite(msh)
    
    # Draw smile body (Cyber Emerald)
    draw.polygon(smile_poly, fill=(0, 225, 105, 255))
    
    # Upper rim highlight on smile
    draw.line(points_top, fill=(255, 255, 255, 140), width=5)
    
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

def render_variant_2_flow_arrows_smile(target_size=1024):
    """
    Variant 2: "The Continuous Up-Down Loop Smile"
    - The logo IS the two arrows flowing into a smile:
      - Left side: A crisp DOWNWARD arrow (Download ⬇) dipping into the smile
      - Center: Flowing smoothly into a wide, happy smile curve (‿)
      - Right side: Rising up and terminating in an UPWARD arrow (Upload ⬆)
    - Above it: Two sparkling minimalist eyes.
    - Pure conceptual perfection: Up arrow + Down arrow literally = Smile!
    """
    S = 2048
    canvas = create_base_canvas(S)
    cx, cy = S // 2, S // 2
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # Eyes: Sleek capsule pills with subtle bevels
    eye_y = cy - 150
    eye_offset = 250
    eye_w = 48
    eye_h = 100
    
    for side in (-1, 1):
        ecx = cx + side * eye_offset
        box = [(ecx - eye_w, eye_y - eye_h), (ecx + eye_w, eye_y + eye_h)]
        
        # Shadow
        esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        draw_esh = ImageDraw.Draw(esh)
        draw_esh.rounded_rectangle([(b[0], b[1] + 16) for b in [box[0], box[1]]], radius=eye_w, fill=(0, 20, 10, 140))
        esh = esh.filter(ImageFilter.GaussianBlur(radius=16))
        layer.alpha_composite(esh)
        
        draw.rounded_rectangle(box, radius=eye_w, fill=(80, 255, 185, 255))
        # Inner highlight
        draw.line([(ecx - 12, eye_y - eye_h + 20), (ecx - 12, eye_y + eye_h - 20)], fill=(255, 255, 255, 160), width=6)

    # Smile Stream: Left Down Arrow ➔ Smile Curve ➔ Right Up Arrow
    # Smile arc
    mouth_cy = cy + 100
    mouth_rx = 460
    mouth_ry = 320
    thickness = 80
    
    points_top = []
    points_bot = []
    for deg in range(30, 151, 2):
        rad = math.radians(deg)
        x = cx - mouth_rx * math.cos(rad)
        y = mouth_cy + mouth_ry * math.sin(rad)
        nx = -math.cos(rad)
        ny = math.sin(rad)
        nl = math.sqrt(nx*nx + ny*ny)
        nx /= nl
        ny /= nl
        points_top.append((x - nx * (thickness / 2), y - ny * (thickness / 2)))
        points_bot.insert(0, (x + nx * (thickness / 2), y + ny * (thickness / 2)))
        
    smile_poly = points_top + points_bot
    
    # Left Terminal: Downward Arrow (Download)
    # Right Terminal: Upward Arrow (Upload)
    lx = points_top[0][0]
    ly = points_top[0][1]
    
    # Left arrowhead pointing DOWN
    left_arrow = [
        (lx - 25, ly + 90),   # Bottom tip pointing down
        (lx - 90, ly - 35),
        (lx - 30, ly - 20),
        (lx + 45, ly - 20),
        (lx + 90, ly - 35),
    ]
    
    rx = points_top[-1][0]
    ry = points_top[-1][1]
    # Right arrowhead pointing UP
    right_arrow = [
        (rx + 25, ry - 90),   # Top tip pointing up
        (rx + 90, ry + 35),
        (rx + 30, ry + 20),
        (rx - 45, ry + 20),
        (rx - 90, ry + 35),
    ]
    
    # Combined shadow
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_msh = ImageDraw.Draw(msh)
    draw_msh.polygon([(p[0], p[1] + 20) for p in smile_poly], fill=(0, 25, 12, 160))
    draw_msh.polygon([(p[0], p[1] + 20) for p in left_arrow], fill=(0, 25, 12, 160))
    draw_msh.polygon([(p[0], p[1] + 20) for p in right_arrow], fill=(0, 25, 12, 160))
    msh = msh.filter(ImageFilter.GaussianBlur(radius=24))
    layer.alpha_composite(msh)
    
    # Draw shapes
    draw.polygon(smile_poly, fill=(0, 225, 105, 255))
    draw.polygon(left_arrow, fill=(0, 205, 95, 255))
    draw.polygon(right_arrow, fill=(50, 255, 165, 255))
    
    draw.line(points_top, fill=(255, 255, 255, 140), width=5)
    
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

def render_variant_3_interlocking_monogram(target_size=1024):
    """
    Variant 3: "Origami Chevron Face"
    - An elevated, layered mark:
      - Top layer: Downward Arrow (⬇) faceted in Cyber Emerald (#00EE78 / #00B84D)
      - But its bottom contour swoops into a smiling curve!
      - Floating inside it is an Upward Chevron (⬆) in Electric Mint (#50FFB9),
        forming an interconnected smiling face!
    """
    S = 2048
    canvas = create_base_canvas(S)
    cx, cy = S // 2, S // 2
    
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # Eyes: Dual Smiling Chevrons (^ ^)
    eye_y = cy - 150
    dist = 280
    span = 130
    h = 95
    
    for side in (-1, 1):
        ecx = cx + side * dist
        pts = [
            (ecx, eye_y - 20),
            (ecx + span, eye_y + h),
            (ecx + span - 40, eye_y + h + 30),
            (ecx, eye_y + 35),
            (ecx - span + 40, eye_y + h + 30),
            (ecx - span, eye_y + h),
        ]
        draw.polygon(pts, fill=(80, 255, 185, 255))
        draw.line([(ecx - span, eye_y + h), (ecx, eye_y - 20), (ecx + span, eye_y + h)], fill=(255, 255, 255, 200), width=6)
    
    # Smiling Mouth: Wide, elegant curved smiling arrow
    m_bbox = [(cx - 480, cy - 80), (cx + 480, cy + 520)]
    draw.arc(m_bbox, start=25, end=155, fill=(0, 230, 115, 255), width=85)
    
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

if __name__ == '__main__':
    os.makedirs('/tmp/kazumi_icons', exist_ok=True)
    render_variant_1_anime_chevrons(1024).save('/tmp/kazumi_icons/variant_1.png')
    render_variant_2_flow_arrows_smile(1024).save('/tmp/kazumi_icons/variant_2.png')
    render_variant_3_interlocking_monogram(1024).save('/tmp/kazumi_icons/variant_3.png')
    print("Variants 1, 2, 3 generated in /tmp/kazumi_icons/")
