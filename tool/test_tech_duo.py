import os
import math
from PIL import Image, ImageDraw, ImageFilter

def create_squircle_mask(size, margin, radius):
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    box = [(margin, margin), (size - margin, size - margin)]
    draw.rounded_rectangle(box, radius=radius, fill=255)
    return mask

def generate_perfect_tech_duo(size=2048):
    S = size
    cx, cy = S // 2, S // 2
    margin = 180
    w = S - 2 * margin
    radius = 380
    squircle_box = [(margin, margin), (margin + w, margin + w)]
    
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    
    # Realistic macOS Dock Drop Shadow
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_s = ImageDraw.Draw(shadow)
    draw_s.rounded_rectangle([(margin + 12, margin + 26), (margin + w - 12, margin + w + 26)], 
                             radius=radius, fill=(0, 0, 0, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=42))
    img.alpha_composite(shadow)
    
    # Pure Clean Obsidian Squircle Background (#121418 -> #0C0D10)
    # Completely clean, NO glare, NO halo, NO noise
    mask = create_squircle_mask(S, margin, radius)
    bg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_bg = ImageDraw.Draw(bg)
    for y in range(margin, margin + w):
        t = (y - margin) / w
        r = int(20 * (1 - t) + 12 * t)
        g = int(24 * (1 - t) + 14 * t)
        b = int(30 * (1 - t) + 18 * t)
        draw_bg.line([(margin, y), (margin + w, y)], fill=(r, g, b, 255))
    bg.putalpha(mask)
    img.alpha_composite(bg)
    
    # Micro Bezel Rim (1px hairline)
    rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_rim = ImageDraw.Draw(rim)
    draw_rim.rounded_rectangle(squircle_box, radius=radius, outline=(255, 255, 255, 22), width=3)
    rim.putalpha(mask)
    img.alpha_composite(rim)
    
    arrow_y = cy + 20
    
    # Outer Downward Arrow (Download ⬇)
    outer_stem = 260
    outer_wing = 540
    outer_top = arrow_y - 560
    outer_top_notch = outer_top + 45
    outer_shoulder = arrow_y + 80
    outer_wing_tip = arrow_y + 140
    outer_bottom_tip = arrow_y + 600
    
    # Outer Polygon
    left_outer = [
        (cx, outer_top_notch),
        (cx - outer_stem, outer_top),
        (cx - outer_stem, outer_shoulder),
        (cx - outer_wing, outer_wing_tip),
        (cx, outer_bottom_tip),
    ]
    right_outer = [
        (cx, outer_top_notch),
        (cx + outer_stem, outer_top),
        (cx + outer_stem, outer_shoulder),
        (cx + outer_wing, outer_wing_tip),
        (cx, outer_bottom_tip),
    ]
    
    # Void Cutout Polygon (The dark channel inside outer arrow)
    cutout_stem = 160
    cutout_wing = 290
    cutout_top = arrow_y - 410
    cutout_shoulder = arrow_y + 50
    cutout_wing_tip = arrow_y + 100
    cutout_bottom = arrow_y + 440
    cutout_bottom_notch = cutout_bottom - 45
    
    void_poly = [
        (cx, cutout_top),
        (cx + cutout_wing, cutout_wing_tip),
        (cx + cutout_stem, cutout_shoulder),
        (cx + cutout_stem, cutout_bottom),
        (cx, cutout_bottom_notch),
        (cx - cutout_stem, cutout_bottom),
        (cx - cutout_stem, cutout_shoulder),
        (cx - cutout_wing, cutout_wing_tip),
    ]
    
    # Inner Upward Arrow Polygon (Upload ⬆)
    # Perfectly centered in the void, with uniform dark space surrounding it
    in_stem = 85
    in_wing = 190
    in_top = arrow_y - 300
    in_shoulder = arrow_y - 30
    in_wing_tip = arrow_y + 20
    in_bottom = arrow_y + 350
    in_bottom_notch = in_bottom - 35
    
    in_poly = [
        (cx, in_top),
        (cx + in_wing, in_wing_tip),
        (cx + in_stem, in_shoulder),
        (cx + in_stem, in_bottom),
        (cx, in_bottom_notch),
        (cx - in_stem, in_bottom),
        (cx - in_stem, in_shoulder),
        (cx - in_wing, in_wing_tip),
    ]
    
    in_left = [
        (cx, in_top),
        (cx - in_wing, in_wing_tip),
        (cx - in_stem, in_shoulder),
        (cx - in_stem, in_bottom),
        (cx, in_bottom_notch),
    ]
    in_right = [
        (cx, in_top),
        (cx + in_wing, in_wing_tip),
        (cx + in_stem, in_shoulder),
        (cx + in_stem, in_bottom),
        (cx, in_bottom_notch),
    ]
    
    arrow_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_a = ImageDraw.Draw(arrow_layer)
    
    # Outer Downward Arrow: High-contrast Tech Emerald Green
    draw_a.polygon(left_outer, fill=(0, 238, 120, 255))
    draw_a.polygon(right_outer, fill=(0, 195, 85, 255))
    draw_a.line([(cx, outer_top_notch), (cx, outer_bottom_tip)], fill=(255, 255, 255, 60), width=3)
    
    # Cutout Void (Matte Dark to match background)
    draw_a.polygon(void_poly, fill=(14, 17, 22, 255))
    
    # Inner Upward Arrow: Electric Mint / Cyber Jade (#00FF88 / #6EE7B7 or matching tech green)
    # Let's make it vivid tech green with subtle contrast
    draw_a.polygon(in_left, fill=(50, 255, 160, 255))
    draw_a.polygon(in_right, fill=(0, 230, 130, 255))
    draw_a.line([(cx, in_top), (cx, in_bottom_notch)], fill=(255, 255, 255, 90), width=3)
    
    img.alpha_composite(arrow_layer)
    return img.resize((1024, 1024), Image.Resampling.LANCZOS)

if __name__ == '__main__':
    out_dir = '/tmp/kazumi_icon_preview'
    icon = generate_perfect_tech_duo(2048)
    icon.save(os.path.join(out_dir, "perfect_tech_duo.png"))
    print("Saved perfect tech duo icon!")
