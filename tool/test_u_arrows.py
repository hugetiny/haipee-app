import os
import math
from PIL import Image, ImageDraw

def render_u_arrows():
    im = Image.new('RGBA', (600, 600), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    cx, cy = 300, 300
    
    # 1. Smile curve at bottom: U-arc
    # from x=160, y=260 down to y=420, up to x=440, y=260
    draw.arc([(150, 180), (450, 420)], start=25, end=155, fill=(80, 255, 185, 255), width=28)
    
    # 2. Right arm: Arrow pointing UP (Upload ⬆)
    # Starts from x=430, y=260, goes straight up to y=150
    draw.line([(430, 260), (430, 160)], fill=(80, 255, 185, 255), width=28)
    # Upward arrowhead
    draw.polygon([(430, 100), (475, 180), (430, 155), (385, 180)], fill=(80, 255, 185, 255))
    
    # 3. Left arm: What about Left arm?
    # Option A: Left arm starts at y=100, goes DOWN to y=260 with downward arrowhead?
    draw.line([(170, 100), (170, 200)], fill=(80, 255, 185, 255), width=28)
    # Downward arrowhead
    draw.polygon([(170, 270), (215, 190), (170, 215), (125, 190)], fill=(80, 255, 185, 255))
    
    # 4. Eyes: Two cheerful eyes
    draw.arc([(210, 180), (270, 230)], start=190, end=350, fill=(80, 255, 185, 255), width=16)
    draw.arc([(330, 180), (390, 230)], start=190, end=350, fill=(80, 255, 185, 255), width=16)
    
    return im

im = render_u_arrows()
small = im.resize((50, 50), Image.Resampling.LANCZOS)
for y in range(50):
    row = ''
    for x in range(50):
        p = small.getpixel((x, y))
        row += '█' if p[1] > 120 else ('░' if p[3] > 30 else ' ')
    if '█' in row or '░' in row:
        print(f'{y:2d}: {row}')
