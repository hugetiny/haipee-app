import os
import math
from PIL import Image, ImageDraw, ImageFilter
from generate_master_smile import create_obsidian_canvas

def generate_variation_c_origami_smile(target_size=1024):
    """
    Variation C: "The Unified Arrow Smile Monogram"
    - The entire logo is a single iconic mark where:
      - A bold, curved smiling base (The Smile Arrow) curves upward with dual-faceted emerald lighting.
      - Above it, two sleek Chevron Eyes (^ ^) float with luminous electric mint glow.
      - In the center, a subtle descending arrow tip creates a 3D interlocking depth.
    """
    S = 2048
    canvas = create_obsidian_canvas(S)
    cx, cy = S // 2, S // 2 - 20
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # 1. Dual Chevron Eyes (^ ^)
    eye_y = cy - 150
    spacing = 280
    span = 135
    h = 105
    notch = 38
    
    for side in (-1, 1):
        ecx = cx + side * spacing
        top_tip = (ecx, eye_y - 25)
        r_outer = (ecx + span, eye_y + h)
        r_inner = (ecx + span - 42, eye_y + h + 28)
        bottom_notch = (ecx, eye_y + notch)
        l_inner = (ecx - span + 42, eye_y + h + 28)
        l_outer = (ecx - span, eye_y + h)
        
        poly = [top_tip, r_outer, r_inner, bottom_notch, l_inner, l_outer]
        
        # Soft shadow
        esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        draw_esh = ImageDraw.Draw(esh)
        draw_esh.polygon([(p[0], p[1] + 18) for p in poly], fill=(0, 20, 10, 140))
        esh = esh.filter(ImageFilter.GaussianBlur(radius=16))
        layer.alpha_composite(esh)
        
        # Facets
        draw.polygon([top_tip, bottom_notch, l_inner, l_outer], fill=(90, 255, 195, 255))
        draw.polygon([top_tip, r_outer, r_inner, bottom_notch], fill=(35, 225, 140, 255))
        draw.line([l_outer, top_tip, r_outer], fill=(255, 255, 255, 210), width=6)
        draw.line([top_tip, bottom_notch], fill=(255, 255, 255, 160), width=4)

    # 2. Downward Arrow floating into Smile (Central Nose / Flow Node)
    # A sleek, minimalist downward chevron in center
    nose_y = cy + 10
    nose_w = 65
    nose_h = 55
    nose_poly = [
        (cx, nose_y + nose_h),
        (cx - nose_w, nose_y),
        (cx - nose_w + 22, nose_y - 15),
        (cx, nose_y + 15),
        (cx + nose_w - 22, nose_y - 15),
        (cx + nose_w, nose_y),
    ]
    # Draw central down chevron
    draw.polygon(nose_poly, fill=(50, 240, 150, 255))
    draw.line([(cx - nose_w, nose_y), (cx, nose_y + nose_h), (cx + nose_w, nose_y)], fill=(255, 255, 255, 180), width=4)

    # 3. Sweeping Radiant Smile Arc
    mouth_cy = cy + 130
    mouth_rx = 500
    mouth_ry = 340
    thickness = 84
    
    pts_top = []
    pts_bot = []
    for deg in range(20, 161, 2):
        rad = math.radians(deg)
        x = cx - mouth_rx * math.cos(rad)
        y = mouth_cy + mouth_ry * math.sin(rad)
        nx = -math.cos(rad)
        ny = math.sin(rad)
        nl = math.sqrt(nx*nx + ny*ny)
        nx /= nl
        ny /= nl
        t = math.sin(rad)
        thick = 68 + 24 * t
        pts_top.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_bot.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_poly = pts_top + pts_bot
    
    # Shadow
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_msh = ImageDraw.Draw(msh)
    draw_msh.polygon([(p[0], p[1] + 24) for p in smile_poly], fill=(0, 25, 12, 170))
    msh = msh.filter(ImageFilter.GaussianBlur(radius=26))
    layer.alpha_composite(msh)
    
    # Fill smile
    draw.polygon(smile_poly, fill=(0, 225, 108, 255))
    draw.line(pts_top, fill=(255, 255, 255, 150), width=6)
    
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

def generate_variation_d_continuous_swoosh_smile(target_size=1024):
    """
    Variation D: "The Amazon-style P2P Flow Smile"
    - The smile ITSELF connects the download arrow (left) and upload arrow (right):
      - Left terminal: Arrowhead pointing down-inwards (Download ⬇)
      - Bottom: Beautiful parabolic smile curve (‿)
      - Right terminal: Arrowhead pointing up-outwards (Upload ⬆)
    - Above it: Twin geometric eyes (circle/capsule or chevron)
    - Meaning: 'Downloading and uploading creates seamless happiness'.
    """
    S = 2048
    canvas = create_obsidian_canvas(S)
    cx, cy = S // 2, S // 2 - 15
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # Eyes: Dual Sleek Pill Capsules with Mint Glow
    eye_y = cy - 140
    dist = 260
    ew = 44
    eh = 95
    
    for side in (-1, 1):
        ecx = cx + side * dist
        box = [(ecx - ew, eye_y - eh), (ecx + ew, eye_y + eh)]
        
        esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        draw_esh = ImageDraw.Draw(esh)
        draw_esh.rounded_rectangle([(b[0], b[1] + 16) for b in box], radius=ew, fill=(0, 20, 10, 140))
        esh = esh.filter(ImageFilter.GaussianBlur(radius=16))
        layer.alpha_composite(esh)
        
        draw.rounded_rectangle(box, radius=ew, fill=(80, 255, 185, 255))
        draw.line([(ecx - 10, eye_y - eh + 18), (ecx - 10, eye_y + eh - 18)], fill=(255, 255, 255, 180), width=6)

    # Smile Arc with BOTH Arrowheads (Left = Down ⬇, Right = Up ⬆)
    mouth_cy = cy + 100
    mouth_rx = 520
    mouth_ry = 360
    thickness = 88
    
    pts_top = []
    pts_bot = []
    
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
        thick = 72 + 28 * t
        pts_top.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_bot.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_poly = pts_top + pts_bot
    
    # Left Arrowhead (Pointing down / inwards)
    lx_base = pts_top[0]
    lx, ly = lx_base[0], lx_base[1]
    left_arrow = [
        (lx - 40, ly + 95),  # Tip pointing down
        (lx - 95, ly - 35),
        (lx - 25, ly - 15),
        (lx + 45, ly - 15),
        (lx + 90, ly - 35),
    ]
    
    # Right Arrowhead (Pointing up / outwards)
    rx_base = pts_top[-1]
    rx, ry = rx_base[0], rx_base[1]
    right_arrow = [
        (rx + 45, ry - 95),  # Tip pointing up
        (rx + 95, ry + 35),
        (rx + 25, ry + 15),
        (rx - 45, ry + 15),
        (rx - 90, ry + 35),
    ]
    
    # Shadow
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_msh = ImageDraw.Draw(msh)
    draw_msh.polygon([(p[0], p[1] + 24) for p in smile_poly], fill=(0, 25, 12, 170))
    draw_msh.polygon([(p[0], p[1] + 24) for p in left_arrow], fill=(0, 25, 12, 170))
    draw_msh.polygon([(p[0], p[1] + 24) for p in right_arrow], fill=(0, 25, 12, 170))
    msh = msh.filter(ImageFilter.GaussianBlur(radius=28))
    layer.alpha_composite(msh)
    
    # Draw body
    draw.polygon(smile_poly, fill=(0, 226, 110, 255))
    draw.polygon(left_arrow, fill=(0, 205, 95, 255))
    draw.polygon(right_arrow, fill=(55, 255, 170, 255))
    
    draw.line(pts_top, fill=(255, 255, 255, 150), width=6)
    
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

if __name__ == '__main__':
    out_dir = '/tmp/kazumi_master_smile'
    generate_variation_c_origami_smile(1024).save(os.path.join(out_dir, 'variation_C.png'))
    generate_variation_d_continuous_swoosh_smile(1024).save(os.path.join(out_dir, 'variation_D.png'))
    print("Variations C and D generated in", out_dir)
