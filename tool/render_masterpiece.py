import os
import math
from PIL import Image, ImageDraw, ImageFilter

def create_squircle_mask(size, margin, radius):
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    box = [(margin, margin), (size - margin, size - margin)]
    draw.rounded_rectangle(box, radius=radius, fill=255)
    return mask

def create_luxury_obsidian_canvas(size=2048):
    """
    Creates Apple HIG / Pro Display caliber matte obsidian squircle canvas:
    - Subtle radial gradient from deep space titanium (#151820) to obsidian (#0A0C0F)
    - Barely-there ambient emerald aurora glow in center (giving depth to the glyph)
    - macOS Dock shadow with dual-layer gaussian dispersion
    - 1px hairline micro-bezel with specular gradient
    """
    S = size
    margin = 180
    w = S - 2 * margin
    radius = 380
    squircle_box = [(margin, margin), (margin + w, margin + w)]
    
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    
    # 1. macOS Dock Drop Shadow (Dual layer: tight ambient + wide diffusion)
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_s = ImageDraw.Draw(shadow)
    # Deep tight shadow
    draw_s.rounded_rectangle(
        [(margin + 8, margin + 18), (margin + w - 8, margin + w + 18)], 
        radius=radius, 
        fill=(0, 0, 0, 160)
    )
    # Broad soft diffusion
    draw_s.rounded_rectangle(
        [(margin + 16, margin + 36), (margin + w - 16, margin + w + 36)], 
        radius=radius, 
        fill=(0, 0, 0, 100)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=46))
    img.alpha_composite(shadow)
    
    # 2. Pure Matte Obsidian Background
    mask = create_squircle_mask(S, margin, radius)
    bg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_bg = ImageDraw.Draw(bg)
    
    cx, cy = S // 2, S // 2
    for y in range(margin, margin + w):
        t = (y - margin) / w
        r = int(24 * (1 - t) + 10 * t)
        g = int(28 * (1 - t) + 12 * t)
        b = int(35 * (1 - t) + 15 * t)
        draw_bg.line([(margin, y), (margin + w, y)], fill=(r, g, b, 255))
        
    # Subtle inner ambient emerald aurora (10% opacity, gives luminous OLED punch)
    glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_glow = ImageDraw.Draw(glow)
    draw_glow.ellipse([(cx - 450, cy - 350), (cx + 450, cy + 500)], fill=(0, 230, 120, 28))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=120))
    bg.alpha_composite(glow)
    
    bg.putalpha(mask)
    img.alpha_composite(bg)
    
    # 3. Micro Bezel Rim (1px crisp specular edge)
    rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_rim = ImageDraw.Draw(rim)
    draw_rim.rounded_rectangle(squircle_box, radius=radius, outline=(255, 255, 255, 28), width=3)
    rim.putalpha(mask)
    img.alpha_composite(rim)
    
    return img

def render_kazumi_master_smile(target_size=1024):
    """
    KAZUMI CYBER-SMILE MASTERWORK (Apple Design Award Caliber)
    - Design Philosophy:
      1. EYES: Two bold, faceted upward origami chevrons (^ ^)
         - Representing Upload ⬆ and High Energy / Happy Anime Squint
         - Crisp 3D dual facets: Electric Mint (#55FFB9) & Ice Jade (#18D688)
         - Razor-sharp center spine highlight
      2. MOUTH: Unified Continuous Stream Smile (⬇ ➔ ‿ ➔ ⬆)
         - Left cheek: Aerodynamic Downward Arrowhead (Download ⬇)
         - Center: Deep, warm, perfectly weighted parabolic smile curve
         - Right cheek: Aerodynamic Upward Arrowhead (Upload ⬆)
         - Seamless aerodynamic integration (no crude welded tabs, smooth fluid tangency)
         - Faceted 3D dual lighting on both arrowheads and the ribbon!
      3. Zero crude black cutouts, zero empty wireframes, 100% iconic, memorable, warm.
    """
    S = 2048
    canvas = create_luxury_obsidian_canvas(S)
    cx, cy = S // 2, S // 2 - 20
    
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # =========================================================================
    # PART 1: THE EYES - DUAL FACETED CHEVRONS (^ ^)
    # =========================================================================
    eye_y = cy - 165
    eye_spacing = 280
    eye_span = 195
    eye_h = 148
    notch_h = 54
    
    for side in (-1, 1):
        ecx = cx + side * eye_spacing
        top_tip = (ecx, eye_y - 36)
        r_outer = (ecx + eye_span, eye_y + eye_h)
        r_inner = (ecx + eye_span - 60, eye_y + eye_h + 40)
        bottom_notch = (ecx, eye_y + notch_h)
        l_inner = (ecx - eye_span + 60, eye_y + eye_h + 40)
        l_outer = (ecx - eye_span, eye_y + eye_h)
        
        poly_full = [top_tip, r_outer, r_inner, bottom_notch, l_inner, l_outer]
        facet_left = [top_tip, bottom_notch, l_inner, l_outer]
        facet_right = [top_tip, r_outer, r_inner, bottom_notch]
        
        # Soft ambient occlusion shadow
        esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        draw_esh = ImageDraw.Draw(esh)
        draw_esh.polygon([(p[0], p[1] + 24) for p in poly_full], fill=(0, 20, 10, 160))
        esh = esh.filter(ImageFilter.GaussianBlur(radius=22))
        layer.alpha_composite(esh)
        
        # Faceted fill
        draw.polygon(facet_left, fill=(88, 255, 192, 255))
        draw.polygon(facet_right, fill=(20, 216, 132, 255))
        
        # Spine & top edge razor highlights
        draw.line([l_outer, top_tip, r_outer], fill=(255, 255, 255, 240), width=9)
        draw.line([top_tip, bottom_notch], fill=(255, 255, 255, 190), width=5)

    # =========================================================================
    # PART 2: THE UNIFIED DUAL-ARROW SMILE (⬇ ➔ ‿ ➔ ⬆)
    # =========================================================================
    mouth_cy = cy + 105
    mouth_rx = 570
    mouth_ry = 380
    
    # Generate smooth parabolic curve
    deg_start = 28
    deg_end = 152
    
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
        thick = 90 + 42 * t  # 132px at center, 90px at cheeks
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_ribbon = pts_outer + pts_inner
    
    # Seamless Aerodynamic Arrowheads:
    # -------------------------------------------------------------
    # Left Cheek: Downward Arrowhead (Download ⬇)
    lx_mid = (pts_outer[0][0] + pts_inner[-1][0]) / 2
    ly_mid = (pts_outer[0][1] + pts_inner[-1][1]) / 2
    
    l_tip = (lx_mid - 45, ly_mid + 125)           # Pointing down-inward
    l_outer_barb = (lx_mid - 125, ly_mid - 36)
    l_notch = (lx_mid - 15, ly_mid - 10)
    l_inner_barb = (lx_mid + 82, ly_mid - 32)
    
    l_arrow_left = [l_tip, l_outer_barb, l_notch]
    l_arrow_right = [l_tip, l_notch, l_inner_barb]
    l_arrow_full = [l_tip, l_outer_barb, l_notch, l_inner_barb]
    
    # -------------------------------------------------------------
    # Right Cheek: Upward Arrowhead (Upload ⬆)
    rx_mid = (pts_outer[-1][0] + pts_inner[0][0]) / 2
    ry_mid = (pts_outer[-1][1] + pts_inner[0][1]) / 2
    
    r_tip = (rx_mid + 45, ry_mid - 125)           # Pointing up-outward
    r_outer_barb = (rx_mid + 125, ry_mid + 36)
    r_notch = (rx_mid + 15, ry_mid + 10)
    r_inner_barb = (rx_mid - 82, ry_mid + 32)
    
    r_arrow_left = [r_tip, r_inner_barb, r_notch]
    r_arrow_right = [r_tip, r_notch, r_outer_barb]
    r_arrow_full = [r_tip, r_outer_barb, r_notch, r_inner_barb]
    
    # -------------------------------------------------------------
    # Soft Ambient Shadow for the whole smile
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_msh = ImageDraw.Draw(msh)
    draw_msh.polygon([(p[0], p[1] + 30) for p in smile_ribbon], fill=(0, 25, 12, 180))
    draw_msh.polygon([(p[0], p[1] + 30) for p in l_arrow_full], fill=(0, 25, 12, 180))
    draw_msh.polygon([(p[0], p[1] + 30) for p in r_arrow_full], fill=(0, 25, 12, 180))
    msh = msh.filter(ImageFilter.GaussianBlur(radius=32))
    layer.alpha_composite(msh)
    
    # Draw smile ribbon (Cyber Emerald #00EE78 -> #00BA50)
    draw.polygon(smile_ribbon, fill=(0, 226, 110, 255))
    
    # Draw faceted arrowheads
    # Left arrow facets
    draw.polygon(l_arrow_left, fill=(0, 240, 122, 255))
    draw.polygon(l_arrow_right, fill=(0, 192, 86, 255))
    draw.line([(l_outer_barb[0], l_outer_barb[1]), (l_tip[0], l_tip[1])], fill=(255, 255, 255, 220), width=7)
    draw.line([(l_notch[0], l_notch[1]), (l_tip[0], l_tip[1])], fill=(255, 255, 255, 170), width=4)
    
    # Right arrow facets
    draw.polygon(r_arrow_left, fill=(85, 255, 188, 255))
    draw.polygon(r_arrow_right, fill=(22, 218, 134, 255))
    draw.line([(r_inner_barb[0], r_inner_barb[1]), (r_tip[0], r_tip[1])], fill=(255, 255, 255, 240), width=8)
    draw.line([(r_notch[0], r_notch[1]), (r_tip[0], r_tip[1])], fill=(255, 255, 255, 180), width=4)
    
    # Upper rim highlight on smile ribbon
    draw.line(pts_outer, fill=(255, 255, 255, 185), width=9)
    
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

def render_kazumi_master_tray(target_size=72):
    """
    Renders clean monochrome vector-grade template tray icon for macOS status bar (72x72)
    """
    S = 512
    cx, cy = S // 2, S // 2 - 10
    
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # EYES: Chevrons (^ ^)
    eye_spacing = 72
    eye_y = cy - 40
    span = 44
    h = 34
    notch = 12
    
    for side in (-1, 1):
        ecx = cx + side * eye_spacing
        poly = [
            (ecx, eye_y - 8),
            (ecx + span, eye_y + h),
            (ecx + span - 14, eye_y + h + 10),
            (ecx, eye_y + notch),
            (ecx - span + 14, eye_y + h + 10),
            (ecx - span, eye_y + h),
        ]
        draw.polygon(poly, fill=(255, 255, 255, 255))
        
    # MOUTH: Parabolic smile with dual arrow terminals
    mouth_cy = cy + 24
    mouth_rx = 135
    mouth_ry = 90
    
    # Draw clean thick arc
    m_bbox = [(cx - mouth_rx, mouth_cy - mouth_ry), (cx + mouth_rx, mouth_cy + mouth_ry)]
    draw.arc(m_bbox, start=28, end=152, fill=(255, 255, 255, 255), width=24)
    
    # Right arrow tip (Upward ⬆)
    rx = cx + int(mouth_rx * math.cos(math.radians(28)))
    ry = mouth_cy + int(mouth_ry * math.sin(math.radians(28)))
    draw.polygon([(rx + 12, ry - 28), (rx + 28, ry + 10), (rx - 14, ry + 8)], fill=(255, 255, 255, 255))
    
    # Left arrow tip (Downward ⬇)
    lx = cx - int(mouth_rx * math.cos(math.radians(28)))
    ly = mouth_cy + int(mouth_ry * math.sin(math.radians(28)))
    draw.polygon([(lx - 12, ly + 28), (lx - 28, ly - 10), (lx + 14, ly - 8)], fill=(255, 255, 255, 255))
    
    return img.resize((target_size, target_size), Image.Resampling.LANCZOS)

if __name__ == '__main__':
    out_dir = '/tmp/kazumi_masterpiece'
    os.makedirs(out_dir, exist_ok=True)
    master = render_kazumi_master_smile(1024)
    master.save(os.path.join(out_dir, 'master_1024.png'))
    tray = render_kazumi_master_tray(72)
    tray.save(os.path.join(out_dir, 'tray_72.png'))
    print("Masterpiece generated in", out_dir)
