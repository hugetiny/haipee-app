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

def generate_master_smile_icon(target_size=1024):
    """
    MASTER DESIGN: The "Kazumi Cyber-Smile" (精密几何度合版)
    - 概念：将上行（Upload ⬆）与下行（Download ⬇）箭头，解构并重组为富有极高设计感的数码笑脸 (Cyber Smile)。
    - 双眼：两个充满活力、向上仰望的立体折纸折角箭头（Chevron Eyes ^ ^）。
           采用 Electric Mint (#4EFFB2) 与 Ice Jade (#14D787) 的棱面分光，带有高光中脊线。
    - 嘴角笑颜：一条饱满、自信上扬的微笑流线。
           中央微厚（饱满亲切），两侧优美收束上扬。
           右侧嘴角巧妙融入向上昂首的箭头尖喙（Upload Dimple），
           左侧嘴角以圆润流体线条收束，象征数据流入（Download Flow）。
    - 整体构图：黄金比例居中，带微光拟真接触阴影、无黑洞、无粗陋黑箭头、具有 Apple Design Award 级别的现代科技感。
    """
    S = 2048
    canvas = create_obsidian_canvas(S)
    cx, cy = S // 2, S // 2 - 10  # optical center slightly elevated
    
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # =========================================================================
    # PART 1: CHEVRON EYES (^ ^) - Upward Arrows as Happy Smiling Eyes
    # =========================================================================
    eye_y = cy - 140
    eye_spacing = 290
    eye_span = 145
    eye_h = 115
    notch_h = 42
    
    for side in (-1, 1):
        ecx = cx + side * eye_spacing
        
        # Faceted polygon vertices
        top_tip = (ecx, eye_y - 25)
        r_outer = (ecx + eye_span, eye_y + eye_h)
        r_inner = (ecx + eye_span - 48, eye_y + eye_h + 32)
        bottom_notch = (ecx, eye_y + notch_h)
        l_inner = (ecx - eye_span + 48, eye_y + eye_h + 32)
        l_outer = (ecx - eye_span, eye_y + eye_h)
        
        poly_full = [top_tip, r_outer, r_inner, bottom_notch, l_inner, l_outer]
        facet_left = [top_tip, bottom_notch, l_inner, l_outer]
        facet_right = [top_tip, r_outer, r_inner, bottom_notch]
        
        # Soft ambient occlusion / contact shadow
        esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        draw_esh = ImageDraw.Draw(esh)
        draw_esh.polygon([(p[0], p[1] + 20) for p in poly_full], fill=(0, 20, 10, 150))
        esh = esh.filter(ImageFilter.GaussianBlur(radius=18))
        layer.alpha_composite(esh)
        
        # Draw facets
        # Left facet: Luminous Electric Mint (#55FFBB)
        draw.polygon(facet_left, fill=(85, 255, 187, 255))
        # Right facet: Shaded Mint Cyan (#18D688)
        draw.polygon(facet_right, fill=(24, 214, 136, 255))
        
        # Center crest highlight & top perimeter highlights
        draw.line([l_outer, top_tip, r_outer], fill=(255, 255, 255, 210), width=6)
        draw.line([top_tip, bottom_notch], fill=(255, 255, 255, 170), width=4)

    # =========================================================================
    # PART 2: THE SMILE ARROW (⬇ ➔ ‿ ➔ ⬆)
    # A confident, beautiful parabolic curve with arrow dimple
    # =========================================================================
    mouth_cy = cy + 110
    mouth_rx = 520
    mouth_ry = 360
    
    # Parabola sampling from left cheek to right cheek
    deg_start = 20
    deg_end = 160
    
    pts_outer = []
    pts_inner = []
    
    for deg in range(deg_start, deg_end + 1, 2):
        rad = math.radians(deg)
        x = cx - mouth_rx * math.cos(rad)
        y = mouth_cy + mouth_ry * math.sin(rad)
        
        # Normalized normal pointing outward
        nx = -math.cos(rad)
        ny = math.sin(rad)
        nl = math.sqrt(nx*nx + ny*ny)
        nx /= nl
        ny /= nl
        
        # Center of smile is slightly thicker (96px), tapering towards cheeks (72px)
        t = math.sin(rad) # 1 at center, smaller at edges
        thick = 70 + 26 * t
        
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_ribbon = pts_outer + pts_inner
    
    # Right Dimple: Upward Arrowhead (Upload Dimple)
    # The right tip of the mouth rises up into an arrowhead
    rx_tip_base = pts_outer[-1]
    rx_c = rx_tip_base[0]
    ry_c = rx_tip_base[1]
    
    # Arrowhead geometry pointing diagonally up-right (~45 deg)
    arrow_tip = (rx_c + 60, ry_c - 60)
    arrow_right = (rx_c + 45, ry_c + 50)
    arrow_left = (rx_c - 55, ry_c - 40)
    
    arrowhead_pts = [
        arrow_tip,
        (rx_c + 55, ry_c + 40),
        (rx_c - 20, ry_c + 15),
        (rx_c - 65, ry_c - 30),
    ]
    
    # Left Dimple: Rounded elegant terminal
    # Ambient shadow for smile
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_msh = ImageDraw.Draw(msh)
    draw_msh.polygon([(p[0], p[1] + 24) for p in smile_ribbon], fill=(0, 25, 12, 170))
    draw_msh.polygon([(p[0], p[1] + 24) for p in arrowhead_pts], fill=(0, 25, 12, 170))
    msh = msh.filter(ImageFilter.GaussianBlur(radius=28))
    layer.alpha_composite(msh)
    
    # Fill smile ribbon with rich Cyber Emerald (#00EE78 / #00B84D)
    draw.polygon(smile_ribbon, fill=(0, 226, 110, 255))
    draw.polygon(arrowhead_pts, fill=(0, 238, 120, 255))
    
    # Upper rim highlight on smile
    draw.line(pts_outer, fill=(255, 255, 255, 160), width=6)
    draw.line([arrow_left, arrow_tip, arrow_right], fill=(255, 255, 255, 220), width=6)
    
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

def generate_smile_tray_icon(target_size=72):
    """
    Generates a matching monochrome template tray icon for macOS menu bar:
    Smiling Chevrons (^ ^) + Smile Arc (‿) in pure crisp vector-quality monochrome.
    """
    S = 512
    cx, cy = S // 2, S // 2 - 5
    
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Eyes: Dual Chevrons (^ ^)
    eye_y = cy - 45
    eye_spacing = 75
    span = 36
    h = 28
    notch = 10
    
    for side in (-1, 1):
        ecx = cx + side * eye_spacing
        poly = [
            (ecx, eye_y - 6),
            (ecx + span, eye_y + h),
            (ecx + span - 12, eye_y + h + 8),
            (ecx, eye_y + notch),
            (ecx - span + 12, eye_y + h + 8),
            (ecx - span, eye_y + h),
        ]
        draw.polygon(poly, fill=(255, 255, 255, 255))
        
    # Mouth Arc: Crisp clean smile curve
    m_bbox = [(cx - 130, cy - 30), (cx + 130, cy + 130)]
    draw.arc(m_bbox, start=25, end=155, fill=(255, 255, 255, 255), width=22)
    
    return img.resize((target_size, target_size), Image.Resampling.LANCZOS)

if __name__ == '__main__':
    out_dir = '/tmp/kazumi_master_smile'
    os.makedirs(out_dir, exist_ok=True)
    master = generate_master_smile_icon(1024)
    master.save(os.path.join(out_dir, 'master_1024.png'))
    tray = generate_smile_tray_icon(72)
    tray.save(os.path.join(out_dir, 'tray_72.png'))
    print("Master smile icon and tray generated successfully in", out_dir)
