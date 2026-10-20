import os
import math
from PIL import Image, ImageDraw, ImageFilter

def create_squircle_mask(size, margin, radius):
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    box = [(margin, margin), (size - margin, size - margin)]
    draw.rounded_rectangle(box, radius=radius, fill=255)
    return mask

def generate_balanced_icon(style="faceted_clean"):
    S = 2048
    cx, cy = S // 2, S // 2
    margin = 180
    w = S - 2 * margin
    radius = 380
    squircle_box = [(margin, margin), (margin + w, margin + w)]
    
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    
    # 1. Subtle, realistic macOS dock drop shadow
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_s = ImageDraw.Draw(shadow)
    draw_s.rounded_rectangle([(margin + 12, margin + 26), (margin + w - 12, margin + w + 26)], 
                             radius=radius, fill=(0, 0, 0, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=42))
    img.alpha_composite(shadow)
    
    # 2. Pure, Clean, Deep Obsidian Squircle Background (#101317 -> #0C0E12)
    # Zero blur glow, zero radar, zero noise
    mask = create_squircle_mask(S, margin, radius)
    bg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_bg = ImageDraw.Draw(bg)
    for y in range(margin, margin + w):
        t = (y - margin) / w
        r = int(18 * (1 - t) + 11 * t)
        g = int(22 * (1 - t) + 13 * t)
        b = int(28 * (1 - t) + 17 * t)
        draw_bg.line([(margin, y), (margin + w, y)], fill=(r, g, b, 255))
    bg.putalpha(mask)
    img.alpha_composite(bg)
    
    # 3. Subtle Hairline Rim (Mac hardware finish)
    rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_rim = ImageDraw.Draw(rim)
    draw_rim.rounded_rectangle(squircle_box, radius=radius, outline=(255, 255, 255, 25), width=3)
    rim.putalpha(mask)
    img.alpha_composite(rim)
    
    # 4. Perfectly Proportioned Arrows
    arrow_y = cy + 20
    
    # Outer Downward Arrow
    outer_stem = 260
    outer_wing = 540
    outer_top = arrow_y - 560
    outer_top_notch = outer_top + 50
    outer_shoulder = arrow_y + 80
    outer_wing_tip = arrow_y + 140
    outer_bottom_tip = arrow_y + 600
    
    # Inner Upward Arrow (strictly bounded within the outer stem!)
    # Max wing width is 185 < outer_stem (260) -> Leaves at least 75px green on each side!
    inner_stem = 85
    inner_wing = 185
    inner_tip = arrow_y - 340
    inner_wing_tip = arrow_y + 40
    inner_shoulder = arrow_y - 20
    inner_bottom = arrow_y + 360
    inner_bottom_notch = inner_bottom - 35
    
    arrow_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_a = ImageDraw.Draw(arrow_layer)
    
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
    
    inner_poly = [
        (cx, inner_tip),
        (cx + inner_wing, inner_wing_tip),
        (cx + inner_stem, inner_shoulder),
        (cx + inner_stem, inner_bottom),
        (cx, inner_bottom_notch),
        (cx - inner_stem, inner_bottom),
        (cx - inner_stem, inner_shoulder),
        (cx - inner_wing, inner_wing_tip),
    ]
    
    if style == "faceted_clean":
        # Dual facet Geek Green: Left bright #00F076, Right deep #00C853
        draw_a.polygon(left_outer, fill=(0, 238, 120, 255))
        draw_a.polygon(right_outer, fill=(0, 196, 88, 255))
        # Crisp hairline center divider
        draw_a.line([(cx, outer_top_notch), (cx, outer_bottom_tip)], fill=(255, 255, 255, 60), width=3)
        # Inner cutout to the dark squircle background
        draw_a.polygon(inner_poly, fill=(14, 17, 22, 255))
        # Crisp laser hairline stroke around inner arrow
        draw_a.polygon(inner_poly, outline=(0, 255, 140, 240), width=6)
        
    elif style == "flat_geek":
        # Pure solid Geek Green #00E676
        full_outer = [
            (cx - outer_stem, outer_top),
            (cx + outer_stem, outer_top),
            (cx + outer_stem, outer_shoulder),
            (cx + outer_wing, outer_wing_tip),
            (cx, outer_bottom_tip),
            (cx - outer_wing, outer_wing_tip),
            (cx - outer_stem, outer_shoulder),
        ]
        draw_a.polygon(full_outer, fill=(0, 230, 118, 255))
        # Cutout to dark
        draw_a.polygon(inner_poly, fill=(14, 17, 22, 255))
        draw_a.polygon(inner_poly, outline=(0, 255, 136, 200), width=5)
        
    elif style == "dual_glyph_tech":
        # Outer green arrow, inner floating mint white upward arrow
        draw_a.polygon(left_outer, fill=(0, 238, 120, 255))
        draw_a.polygon(right_outer, fill=(0, 196, 88, 255))
        # Cutout
        draw_a.polygon(inner_poly, fill=(14, 17, 22, 255))
        # Inner solid floating upward arrow in Crisp Electric Mint (#A7F3D0 / #00FF88)
        inner_float_stem = 50
        inner_float_wing = 125
        inner_float_tip = arrow_y - 240
        inner_float_wing_tip = arrow_y + 10
        inner_float_shoulder = arrow_y - 30
        inner_float_bottom = arrow_y + 260
        float_poly = [
            (cx, inner_float_tip),
            (cx + inner_float_wing, inner_float_wing_tip),
            (cx + inner_float_stem, inner_float_shoulder),
            (cx + inner_float_stem, inner_float_bottom),
            (cx - inner_float_stem, inner_float_bottom),
            (cx - inner_float_stem, inner_float_shoulder),
            (cx - inner_float_wing, inner_float_wing_tip),
        ]
        draw_a.polygon(float_poly, fill=(0, 255, 136, 255))
        
    img.alpha_composite(arrow_layer)
    return img.resize((1024, 1024), Image.Resampling.LANCZOS)

if __name__ == '__main__':
    out_dir = '/tmp/kazumi_icon_preview'
    os.makedirs(out_dir, exist_ok=True)
    
    im1 = generate_balanced_icon("faceted_clean")
    im1.save(os.path.join(out_dir, "balanced_faceted_clean.png"))
    
    im2 = generate_balanced_icon("flat_geek")
    im2.save(os.path.join(out_dir, "balanced_flat_geek.png"))
    
    im3 = generate_balanced_icon("dual_glyph_tech")
    im3.save(os.path.join(out_dir, "balanced_dual_glyph_tech.png"))
    print("Saved balanced icons!")
