import os
import math
import subprocess
from PIL import Image, ImageDraw, ImageFilter

def create_squircle_mask(size, margin, radius):
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    box = [(margin, margin), (size - margin, size - margin)]
    draw.rounded_rectangle(box, radius=radius, fill=255)
    return mask

def create_luxury_canvas(S=2048):
    margin = 180
    w = S - 2 * margin
    radius = 380
    squircle_box = [(margin, margin), (margin + w, margin + w)]
    
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    
    # 1. macOS dock drop shadow
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_s = ImageDraw.Draw(shadow)
    draw_s.rounded_rectangle([(margin + 12, margin + 26), (margin + w - 12, margin + w + 26)], radius=radius, fill=(0, 0, 0, 160))
    draw_s.rounded_rectangle([(margin + 20, margin + 46), (margin + w - 20, margin + w + 46)], radius=radius, fill=(0, 0, 0, 100))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=46))
    img.alpha_composite(shadow)
    
    # 2. Pure Matte Obsidian Background
    mask = create_squircle_mask(S, margin, radius)
    bg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_bg = ImageDraw.Draw(bg)
    
    cx, cy = S // 2, S // 2
    for y in range(margin, margin + w):
        t = (y - margin) / w
        r = int(22 * (1 - t) + 11 * t)
        g = int(27 * (1 - t) + 13 * t)
        b = int(34 * (1 - t) + 16 * t)
        draw_bg.line([(margin, y), (margin + w, y)], fill=(r, g, b, 255))
        
    # Ambient OLED Aurora Glow
    glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([(cx - 520, cy - 360), (cx + 520, cy + 480)], fill=(0, 230, 120, 28))
    bg.alpha_composite(glow.filter(ImageFilter.GaussianBlur(radius=120)))
    bg.putalpha(mask)
    img.alpha_composite(bg)
    
    # 3. Micro Bezel Rim (1px hairline)
    rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle(squircle_box, radius=radius, outline=(255, 255, 255, 28), width=3)
    rim.putalpha(mask)
    img.alpha_composite(rim)
    
    return img

def compute_streamline_geometry(S=2048):
    """
    SINGLE SOURCE OF TRUTH:
    Minimalist High-Tech Arrow-Smile
    - Eyes: Two sleek, rounded tech pill nodes
    - Smile: Smooth left rounded terminal + confident smile arc + sleek upward arrowhead at right
    - ZERO strange horns or clunky double corners
    """
    cx, cy = S // 2, S // 2 - 10
    
    # 1. EYES: Two high-tech pills
    eye_spacing = 290
    eye_y = cy - 150
    ew = 56
    eh = 120
    
    eyes = []
    for side in (-1, 1):
        ecx = cx + side * eye_spacing
        box = [(ecx - ew, eye_y - eh), (ecx + ew, eye_y + eh)]
        eyes.append({'box': box, 'cx': ecx, 'cy': eye_y, 'ew': ew, 'eh': eh})
        
    # 2. SMILE ARROW:
    # Golden ratio smile arc
    mouth_cy = cy + 90
    mouth_rx = 560
    mouth_ry = 380
    
    deg_start = 28
    deg_end = 144
    
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
        # Ribbon thickness: 95px at base, 75px near ends
        thick = 75 + 40 * t
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_ribbon = pts_outer + pts_inner
    
    # Left end center (perfect smooth rounded cap)
    lx_mid = (pts_outer[0][0] + pts_inner[-1][0]) / 2
    ly_mid = (pts_outer[0][1] + pts_inner[-1][1]) / 2
    cap_radius = (75) / 2 # 37.5
    
    # Right end center (aerodynamic tech arrowhead pointing up-right ↗)
    rx_mid = (pts_outer[-1][0] + pts_inner[0][0]) / 2
    ry_mid = (pts_outer[-1][1] + pts_inner[0][1]) / 2
    
    # Arrowhead geometry
    r_tip = (rx_mid + 85, ry_mid - 160)
    r_barb_out = (rx_mid + 160, ry_mid + 16)
    r_notch = (rx_mid + 20, ry_mid - 16)
    r_barb_in = (rx_mid - 85, ry_mid + 28)
    arrow_poly = [r_tip, r_barb_in, r_notch, r_barb_out]
    
    return {
        'eyes': eyes,
        'smile_ribbon': smile_ribbon,
        'pts_outer': pts_outer,
        'lx_mid': lx_mid,
        'ly_mid': ly_mid,
        'cap_radius': cap_radius,
        'arrow_poly': arrow_poly,
        'r_tip': r_tip,
        'r_notch': r_notch,
        'r_barb_out': r_barb_out,
        'r_barb_in': r_barb_in,
    }

def render_dock_icon(target_size=1024):
    S = 2048
    geom = compute_streamline_geometry(S)
    img = create_luxury_canvas(S)
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # Eyes
    for eye in geom['eyes']:
        box = eye['box']
        # Contact shadow
        esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(esh).rounded_rectangle([(b[0], b[1] + 24) for b in box], radius=eye['ew'], fill=(0, 20, 10, 160))
        layer.alpha_composite(esh.filter(ImageFilter.GaussianBlur(radius=20)))
        
        # Fill Electric Mint
        draw.rounded_rectangle(box, radius=eye['ew'], fill=(80, 255, 185, 255))
        # Specular highlight
        draw.line([(eye['cx'] - 14, eye['cy'] - eye['eh'] + 24), (eye['cx'] - 14, eye['cy'] + eye['eh'] - 24)], fill=(255, 255, 255, 200), width=8)
        
    # Mouth shadow
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(msh).polygon([(p[0], p[1] + 30) for p in geom['smile_ribbon']], fill=(0, 25, 12, 180))
    ImageDraw.Draw(msh).polygon([(p[0], p[1] + 30) for p in geom['arrow_poly']], fill=(0, 25, 12, 180))
    ImageDraw.Draw(msh).ellipse([
        (geom['lx_mid'] - geom['cap_radius'], geom['ly_mid'] - geom['cap_radius'] + 30),
        (geom['lx_mid'] + geom['cap_radius'], geom['ly_mid'] + geom['cap_radius'] + 30)
    ], fill=(0, 25, 12, 180))
    layer.alpha_composite(msh.filter(ImageFilter.GaussianBlur(radius=30)))
    
    # Smile ribbon
    draw.polygon(geom['smile_ribbon'], fill=(0, 226, 110, 255))
    # Left smooth rounded cap
    draw.ellipse([
        (geom['lx_mid'] - geom['cap_radius'], geom['ly_mid'] - geom['cap_radius']),
        (geom['lx_mid'] + geom['cap_radius'], geom['ly_mid'] + geom['cap_radius'])
    ], fill=(0, 226, 110, 255))
    
    # High-tech arrowhead on right
    draw.polygon([geom['r_tip'], geom['r_notch'], geom['r_barb_out']], fill=(20, 218, 134, 255))
    draw.polygon([geom['r_tip'], geom['r_barb_in'], geom['r_notch']], fill=(85, 255, 190, 255))
    draw.line([geom['r_barb_in'], geom['r_tip'], geom['r_barb_out']], fill=(255, 255, 255, 240), width=8)
    draw.line([geom['r_tip'], geom['r_notch']], fill=(255, 255, 255, 180), width=5)
    
    # Smile outer curve highlight
    draw.line(geom['pts_outer'], fill=(255, 255, 255, 185), width=8)
    
    img.alpha_composite(layer)
    return img.resize((target_size, target_size), Image.Resampling.LANCZOS)

def render_tray_icon(target_size=72):
    S = 2048
    geom = compute_streamline_geometry(S)
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # Exact same elements in solid pure white
    for eye in geom['eyes']:
        draw.rounded_rectangle(eye['box'], radius=eye['ew'], fill=(255, 255, 255, 255))
        
    draw.polygon(geom['smile_ribbon'], fill=(255, 255, 255, 255))
    draw.ellipse([
        (geom['lx_mid'] - geom['cap_radius'], geom['ly_mid'] - geom['cap_radius']),
        (geom['lx_mid'] + geom['cap_radius'], geom['ly_mid'] + geom['cap_radius'])
    ], fill=(255, 255, 255, 255))
    draw.polygon(geom['arrow_poly'], fill=(255, 255, 255, 255))
    
    # Tight crop
    bbox = layer.getbbox()
    bw = bbox[2] - bbox[0]
    bh = bbox[3] - bbox[1]
    dim = max(bw, bh)
    bcx = (bbox[0] + bbox[2]) // 2
    bcy = (bbox[1] + bbox[3]) // 2
    
    pad = int(dim * 0.04)
    crop_box = (
        bcx - dim // 2 - pad,
        bcy - dim // 2 - pad,
        bcx + dim // 2 + pad,
        bcy + dim // 2 + pad,
    )
    cropped = layer.crop(crop_box)
    return cropped.resize((target_size, target_size), Image.Resampling.LANCZOS)

dock = render_dock_icon(1024)
tray = render_tray_icon(72)
dock.save('/tmp/kazumi_concept_test/streamline_dock.png')
tray.save('/tmp/kazumi_concept_test/streamline_tray.png')
print("Streamline icons generated!")
