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
        fill=(0, 0, 0, 130)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=42))
    img.alpha_composite(shadow)
    
    # 2. Pure Matte Obsidian Background (#13161C -> #0A0C0F)
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

def render_concept_A(target_size=1024):
    """
    Concept A: The "Dual-Arrow Synchronous Smile" (The P2P Smiling Face)
    - Eyes: Two sleek chevron arrows pointing UP (^ ^) - Electric Mint, illuminated facets
    - Mouth: A sweeping, confident curved smile arrow (⬇ ➔ ‿ ➔ ⬆)
      Flows from download (downward) across a joyful smile curve and ascends into an upward arrow (upload)!
    - Result: Highly iconic, friendly, professional, looks like a top-tier anime/streaming brand!
    """
    S = 2048
    canvas = create_base_canvas(S)
    cx, cy = S // 2, S // 2
    
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # Eyes: Two stylized upward chevrons (^ ^)
    eye_y = cy - 130
    eye_dist = 280
    eye_w = 130
    eye_h = 110
    eye_stroke = 52
    
    for side in (-1, 1):
        ecx = cx + side * eye_dist
        # Draw chevron eye as polygon for sharp high-end faceted look
        # Apex is at (ecx, eye_y)
        # Left leg: (ecx - eye_w, eye_y + eye_h)
        # Right leg: (ecx + eye_w, eye_y + eye_h)
        poly = [
            (ecx, eye_y - 20),
            (ecx + eye_w + 15, eye_y + eye_h),
            (ecx + eye_w - 35, eye_y + eye_h + 25),
            (ecx, eye_y + 35),
            (ecx - eye_w + 35, eye_y + eye_h + 25),
            (ecx - eye_w - 15, eye_y + eye_h),
        ]
        # Soft shadow behind eyes
        eye_sh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        draw_esh = ImageDraw.Draw(eye_sh)
        draw_esh.polygon([(p[0], p[1] + 16) for p in poly], fill=(0, 20, 10, 140))
        eye_sh = eye_sh.filter(ImageFilter.GaussianBlur(radius=16))
        layer.alpha_composite(eye_sh)
        
        # Faceted draw
        draw.polygon(poly, fill=(80, 255, 185, 255))
        # Top highlight spine
        draw.line([(ecx - eye_w - 15, eye_y + eye_h), (ecx, eye_y - 20), (ecx + eye_w + 15, eye_y + eye_h)], 
                  fill=(255, 255, 255, 180), width=6)

    # Mouth: Sweeping parabolic smile with arrow terminals
    # Mouth starts at left cheek, swoops down to cy + 340, rises up to right cheek cy + 120
    # Center mouth arc
    mouth_cy = cy + 60
    mouth_rx = 460
    mouth_ry = 320
    
    # Create high-res polygon for smile ribbon
    points_top = []
    points_bot = []
    
    thickness = 85
    start_deg = 20
    end_deg = 160
    
    for deg in range(start_deg, end_deg + 1, 2):
        rad = math.radians(deg)
        x = cx - mouth_rx * math.cos(rad)
        y = mouth_cy + mouth_ry * math.sin(rad)
        # Normal vector pointing outward
        nx = -math.cos(rad)
        ny = math.sin(rad)
        # Length normalize
        nl = math.sqrt(nx*nx + ny*ny)
        nx /= nl
        ny /= nl
        
        points_top.append((x - nx * (thickness / 2), y - ny * (thickness / 2)))
        points_bot.insert(0, (x + nx * (thickness / 2), y + ny * (thickness / 2)))
    
    smile_poly = points_top + points_bot
    
    # Smile shadow
    smile_sh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_ssh = ImageDraw.Draw(smile_sh)
    draw_ssh.polygon([(p[0], p[1] + 20) for p in smile_poly], fill=(0, 25, 12, 160))
    smile_sh = smile_sh.filter(ImageFilter.GaussianBlur(radius=24))
    layer.alpha_composite(smile_sh)
    
    # Fill smile ribbon with rich Cyber Emerald (#00EE78 -> #00B84D)
    draw.polygon(smile_poly, fill=(0, 225, 110, 255))
    
    # Right end: Upward Arrowhead (Upload Dimple)
    rx_tip = cx + mouth_rx * math.cos(math.radians(start_deg)) + 60
    ry_tip = mouth_cy + mouth_ry * math.sin(math.radians(start_deg)) - 80
    r_arrow = [
        (rx_tip, ry_tip), # Top-right tip
        (rx_tip - 160, ry_tip + 20),
        (rx_tip - 70, ry_tip + 90),
        (rx_tip + 30, ry_tip + 160),
    ]
    
    # Outer highlights on smile
    draw.line(points_top, fill=(255, 255, 255, 140), width=5)
    
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

def render_concept_B(target_size=1024):
    """
    Concept B: The "Unified Interlocking Arrow Smile"
    - An Upper Downward Arrow (⬇) and a Lower Upward-Smiling Crescent Arrow (⬆/‿)
      nest together so that their combination forms a smiling face mark.
    - Outer shape: Downward flow in Cyber Emerald.
    - Inner shape: Upward smiling crescent in Electric Mint.
    """
    S = 2048
    canvas = create_base_canvas(S)
    cx, cy = S // 2, S // 2
    
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # We construct a curved smile where the bottom IS an upward smiling arrow,
    # and the top has a downward arrow notch.
    # Like a friendly tech emblem!
    # Let's test a harmonious curved geometric smile mark:
    # Mouth arc:
    m_bbox = [(cx - 450, cy - 100), (cx + 450, cy + 500)]
    draw.arc(m_bbox, start=20, end=160, fill=(0, 230, 115, 255), width=100)
    
    # Eyes: Dual downward & upward arrow fusion or twin capsules
    # Let's draw capsule eyes tilted inward (friendly Japanese anime eyes)
    eye_y = cy - 120
    eye_offset = 260
    eye_w = 40
    eye_h = 130
    
    draw.rounded_rectangle([(cx - eye_offset - eye_w, eye_y - eye_h), (cx - eye_offset + eye_w, eye_y + eye_h)], radius=35, fill=(80, 255, 185, 255))
    draw.rounded_rectangle([(cx + eye_offset - eye_w, eye_y - eye_h), (cx + eye_offset + eye_w, eye_y + eye_h)], radius=35, fill=(80, 255, 185, 255))
    
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

def render_concept_C(target_size=1024):
    """
    Concept C: "The Origami Arrow Smile" (Direct evolution of the current icon!)
    In the CURRENT icon:
    - There was a big outer arrow pointing down.
    - And a small inner arrow pointing up.
    Now, to make it "synthesize into a smile":
    - The bottom of the outer down-arrow curves upward into a broad smiling cradle ⌣ !
    - The inner up-arrow floats above it like a happy smiling nose/spark, OR:
    - The outer arrow forms the head/smile and the inner chevron forms the eyes!
    """
    S = 2048
    canvas = create_base_canvas(S)
    cx, cy = S // 2, S // 2
    
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # 1. Smile Arrow (The main lower curved arrow)
    # A generous smile curve sweeping across the bottom
    mouth_cy = cy + 100
    mouth_rx = 520
    mouth_ry = 340
    
    # Draw smile as a tapered, flowing arrow
    # Left tip: rounded cheek start
    # Right tip: upward-pointing arrow (upload)
    # Bottom: gentle curve (download cradle)
    
    # Let's draw eyes:
    # Eye 1: Downward Arrow (⬇) on the left (Download eye)
    # Eye 2: Upward Arrow (⬆) on the right (Upload eye)
    # OR: Both eyes are upward chevrons (^ ^)
    eye_y = cy - 160
    dist = 260
    w = 110
    h = 90
    
    # Left chevron ^
    l_pts = [(cx - dist, eye_y - 20), (cx - dist + w, eye_y + h), (cx - dist - w, eye_y + h)]
    draw.polygon(l_pts, fill=(80, 255, 185, 255))
    
    # Right chevron ^
    r_pts = [(cx + dist, eye_y - 20), (cx + dist + w, eye_y + h), (cx + dist - w, eye_y + h)]
    draw.polygon(r_pts, fill=(80, 255, 185, 255))
    
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

if __name__ == '__main__':
    os.makedirs('/tmp/kazumi_icons', exist_ok=True)
    render_concept_A(1024).save('/tmp/kazumi_icons/concept_A.png')
    render_concept_B(1024).save('/tmp/kazumi_icons/concept_B.png')
    render_concept_C(1024).save('/tmp/kazumi_icons/concept_C.png')
    print("Concepts A, B, C saved to /tmp/kazumi_icons/")
