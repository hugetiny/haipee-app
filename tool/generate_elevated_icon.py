import os
import math
from PIL import Image, ImageDraw, ImageFilter

def create_squircle_mask(size, margin, radius):
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    box = [(margin, margin), (size - margin, size - margin)]
    draw.rounded_rectangle(box, radius=radius, fill=255)
    return mask

def generate_elevated_origami_icon(size=2048):
    """
    Elevated Origami Layer Concept:
    - Layer 1: Pure Matte Obsidian Squircle (#121418 -> #0C0D10)
    - Layer 2: Big Downward Arrow (Download ⬇) in rich Cyber Emerald (#00EE78 / #00B84D)
    - Layer 3: Soft contact shadow beneath the inner arrow
    - Layer 4: Floating Elevated Upward Arrow (Upload ⬆) in Electric Mint & Ice Jade
      with faceted prismatic lighting, center spine, and micro-bevels.
    - Result: No black hole, no raw cutouts, pristine high-end hardware/Apple aesthetic.
    """
    S = size
    cx, cy = S // 2, S // 2
    margin = 180
    w = S - 2 * margin
    radius = 380
    squircle_box = [(margin, margin), (margin + w, margin + w)]
    
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    
    # 1. macOS dock drop shadow
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_s = ImageDraw.Draw(shadow)
    draw_s.rounded_rectangle(
        [(margin + 12, margin + 26), (margin + w - 12, margin + w + 26)], 
        radius=radius, 
        fill=(0, 0, 0, 120)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=42))
    img.alpha_composite(shadow)
    
    # 2. Pure Matte Obsidian Background
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
    
    # 3. Micro Bezel Rim (1px hairline)
    rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_rim = ImageDraw.Draw(rim)
    draw_rim.rounded_rectangle(squircle_box, radius=radius, outline=(255, 255, 255, 22), width=3)
    rim.putalpha(mask)
    img.alpha_composite(rim)
    
    arrow_y = cy + 20
    
    # 4. Outer Downward Arrow (Download ⬇)
    outer_stem = 260
    outer_wing = 540
    outer_top = arrow_y - 560
    outer_top_notch = outer_top + 45
    outer_shoulder = arrow_y + 80
    outer_wing_tip = arrow_y + 140
    outer_bottom_tip = arrow_y + 600
    
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
    
    outer_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_out = ImageDraw.Draw(outer_layer)
    draw_out.polygon(left_outer, fill=(0, 238, 120, 255))
    draw_out.polygon(right_outer, fill=(0, 186, 78, 255))
    draw_out.line([(cx, outer_top_notch), (cx, outer_bottom_tip)], fill=(255, 255, 255, 50), width=3)
    draw_out.line([(cx - outer_stem, outer_top), (cx, outer_top_notch)], fill=(255, 255, 255, 120), width=5)
    draw_out.line([(cx - outer_wing, outer_wing_tip), (cx, outer_bottom_tip)], fill=(255, 255, 255, 100), width=5)
    img.alpha_composite(outer_layer)
    
    # 5. Elevated Upward Arrow Geometry (Upload ⬆)
    in_stem = 95
    in_wing = 210
    in_top = arrow_y - 320
    in_shoulder = arrow_y - 20
    in_wing_tip = arrow_y + 30
    in_bottom = arrow_y + 380
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
    
    # Realistic soft contact shadow cast by the elevated arrow onto the base arrow
    inner_shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_is = ImageDraw.Draw(inner_shadow)
    # Offset shadow down slightly
    shadow_offset_y = 18
    in_poly_shadow = [(p[0], p[1] + shadow_offset_y) for p in in_poly]
    draw_is.polygon(in_poly_shadow, fill=(0, 20, 10, 160))
    inner_shadow = inner_shadow.filter(ImageFilter.GaussianBlur(radius=22))
    img.alpha_composite(inner_shadow)
    
    # Floating Elevated Upward Arrow
    inner_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_in = ImageDraw.Draw(inner_layer)
    # Left facet: Crisp Luminous Electric Mint (#6EE7B7 / #34FFA8)
    draw_in.polygon(in_left, fill=(80, 255, 185, 255))
    # Right facet: Shaded Mint Cyan (#10D680)
    draw_in.polygon(in_right, fill=(20, 215, 135, 255))
    # Elegant center ridge
    draw_in.line([(cx, in_top), (cx, in_bottom_notch)], fill=(255, 255, 255, 160), width=4)
    # Wing highlights
    draw_in.line([(cx - in_wing, in_wing_tip), (cx, in_top)], fill=(255, 255, 255, 180), width=5)
    # Subtle perimeter stroke
    draw_in.polygon(in_poly, outline=(255, 255, 255, 60), width=2)
    img.alpha_composite(inner_layer)
    
    return img.resize((1024, 1024), Image.Resampling.LANCZOS)

if __name__ == '__main__':
    out_dir = '/tmp/kazumi_icon_preview'
    os.makedirs(out_dir, exist_ok=True)
    icon = generate_elevated_origami_icon(2048)
    icon.save(os.path.join(out_dir, 'elevated_origami_icon.png'))
    print("Saved elevated origami icon!")
