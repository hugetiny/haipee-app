import os
import math
from PIL import Image, ImageDraw

def render_tangent_smile():
    im = Image.new('RGBA', (600, 600), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    cx, cy = 300, 300
    
    # Eyes: Two friendly smiling arcs (◠ ◠)
    eye_spacing = 90
    eye_y = cy - 60
    for side in (-1, 1):
        ecx = cx + side * eye_spacing
        draw.arc([(ecx - 45, eye_y - 30), (ecx + 45, eye_y + 30)], start=200, end=340, fill=(80, 255, 185, 255), width=20)
        
    # Smile ribbon:
    # Mouth center = cy + 40, rx = 180, ry = 130
    pts = []
    for deg in range(35, 146, 3):
        rad = math.radians(deg)
        x = cx - 180 * math.cos(rad)
        y = cy + 40 + 130 * math.sin(rad)
        pts.append((x, y))
        
    for i in range(len(pts) - 1):
        draw.line([pts[i], pts[i+1]], fill=(80, 255, 185, 255), width=26)
        
    # Right end: points UP-RIGHT (⬆ ↗ Upload)
    rx, ry = pts[-1]
    # tangent direction is roughly (dx = +1, dy = -1.2)
    # Arrow tip
    r_tip = (rx + 40, ry - 55)
    r_barb_out = (rx + 50, ry + 15)
    r_notch = (rx + 8, ry - 5)
    r_barb_in = (rx - 30, ry + 12)
    draw.polygon([r_tip, r_barb_out, r_notch, r_barb_in], fill=(80, 255, 185, 255))
    
    # Left end: points DOWN-LEFT (⬇ ↙ Download)
    lx, ly = pts[0]
    # tangent direction is roughly (dx = -1, dy = +1.2)
    l_tip = (lx - 40, ly + 55)
    l_barb_out = (lx - 50, ly - 15)
    l_notch = (lx - 8, ly + 5)
    l_barb_in = (lx + 30, ly - 12)
    draw.polygon([l_tip, l_barb_out, l_notch, l_barb_in], fill=(80, 255, 185, 255))
    
    return im

im = render_tangent_smile()
small = im.resize((50, 50), Image.Resampling.LANCZOS)
for y in range(50):
    row = ''
    for x in range(50):
        p = small.getpixel((x, y))
        row += '█' if p[1] > 120 else ('░' if p[3] > 30 else ' ')
    if '█' in row or '░' in row:
        print(f'{y:2d}: {row}')
