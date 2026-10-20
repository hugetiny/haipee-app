import os
import math
from PIL import Image, ImageDraw, ImageFilter

def create_squircle_mask(size, margin, radius):
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    box = [(margin, margin), (size - margin, size - margin)]
    draw.rounded_rectangle(box, radius=radius, fill=255)
    return mask

def generate_variant_a(size=2048):
    """
    Variant A: Mathematically uniform offset nesting.
    Clean, sleek, perfectly balanced proportions.
    Matte dark obsidian squircle, zero glare, zero background noise.
    """
    S = size
    cx, cy = S // 2, S // 2
    margin = 180
    w = S - 2 * margin
    radius = 380
    squircle_box = [(margin, margin), (margin + w, margin + w)]
    
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    
    # Shadow
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_s = ImageDraw.Draw(shadow)
    draw_s.rounded_rectangle([(margin + 10, margin + 24), (margin + w - 10, margin + w + 24)], 
                             radius=radius, fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=40))
    img.alpha_composite(shadow)
    
    # Clean Dark Matte Squircle (#12151A)
    mask = create_squircle_mask(S, margin, radius)
    bg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_bg = ImageDraw.Draw(bg)
    for y in range(margin, margin + w):
        t = (y - margin) / w
        r = int(22 * (1 - t) + 12 * t)
        g = int(26 * (1 - t) + 15 * t)
        b = int(32 * (1 - t) + 18 * t)
        draw_bg.line([(margin, y), (margin + w, y)], fill=(r, g, b, 255))
    bg.putalpha(mask)
    img.alpha_composite(bg)
    
    # Subtle crisp hairline border
    rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_rim = ImageDraw.Draw(rim)
    draw_rim.rounded_rectangle(squircle_box, radius=radius, outline=(255, 255, 255, 22), width=3)
    rim.putalpha(mask)
    img.alpha_composite(rim)
    
    # Geometric Downward Arrow (Download)
    # Proportions:
    # Top stem width: 440 (half: 220)
    # Wing span: 960 (half: 480)
    # Arrowhead angle: 90 degrees
    arrow_y = cy + 25
    stem_half = 210
    wing_half = 480
    
    # Y coordinates:
    top_y = arrow_y - 560
    notch_y = top_y + 60       # slight sleek angled top
    shoulder_y = arrow_y + 40
    wing_tip_y = arrow_y + 110
    bottom_tip_y = arrow_y + 590
    
    outer_poly = [
        (cx, notch_y),
        (cx - stem_half, top_y),
        (cx - stem_half, shoulder_y),
        (cx - wing_half, wing_tip_y),
        (cx, bottom_tip_y),
        (cx + wing_half, wing_tip_y),
        (cx + stem_half, shoulder_y),
        (cx + stem_half, top_y),
    ]
    
    # Inner Upward Arrow (Upload)
    # Nested symmetrically inside
    i_stem_half = 100
    i_wing_half = 260
    i_top_tip_y = arrow_y - 360
    i_wing_tip_y = arrow_y + 20
    i_shoulder_y = arrow_y - 30
    i_bottom_y = arrow_y + 380
    i_bottom_notch_y = i_bottom_y - 45
    
    inner_poly = [
        (cx, i_top_tip_y),
        (cx + i_wing_half, i_wing_tip_y),
        (cx + i_stem_half, i_shoulder_y),
        (cx + i_stem_half, i_bottom_y),
        (cx, i_bottom_notch_y),
        (cx - i_stem_half, i_bottom_y),
        (cx - i_stem_half, i_shoulder_y),
        (cx - i_wing_half, i_wing_tip_y),
    ]
    
    arrow_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_a = ImageDraw.Draw(arrow_layer)
    
    # Clean vibrant Tech Emerald Green: Left #00E676, Right #00C853
    left_outer = [
        (cx, notch_y),
        (cx - stem_half, top_y),
        (cx - stem_half, shoulder_y),
        (cx - wing_half, wing_tip_y),
        (cx, bottom_tip_y),
    ]
    right_outer = [
        (cx, notch_y),
        (cx + stem_half, top_y),
        (cx + stem_half, shoulder_y),
        (cx + wing_half, wing_tip_y),
        (cx, bottom_tip_y),
    ]
    draw_a.polygon(left_outer, fill=(0, 230, 118, 255))
    draw_a.polygon(right_outer, fill=(0, 190, 85, 255))
    
    # Pure clean cutout to dark void
    draw_a.polygon(inner_poly, fill=(15, 18, 22, 255))
    
    # Crisp laser outline around inner upward arrow (#00FF88)
    draw_a.polygon(inner_poly, outline=(0, 255, 136, 230), width=6)
    
    img.alpha_composite(arrow_layer)
    return img.resize((1024, 1024), Image.Resampling.LANCZOS)

def generate_variant_b(size=2048):
    """
    Variant B: Sleek Modern Geometric Dual-Arrow (Flat Clean Tech).
    The outer arrow is pure solid tech green (#00E676),
    The inner upward arrow is negative-space dark obsidian, but with a sharp vertical center accent.
    No bevels, ultra-clean, minimal vector.
    """
    S = size
    cx, cy = S // 2, S // 2
    margin = 180
    w = S - 2 * margin
    radius = 380
    squircle_box = [(margin, margin), (margin + w, margin + w)]
    
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    
    # Shadow
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_s = ImageDraw.Draw(shadow)
    draw_s.rounded_rectangle([(margin + 10, margin + 24), (margin + w - 10, margin + w + 24)], 
                             radius=radius, fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=40))
    img.alpha_composite(shadow)
    
    # Pure Matte Charcoal / Cyber Obsidian (#111418)
    mask = create_squircle_mask(S, margin, radius)
    bg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_bg = ImageDraw.Draw(bg)
    draw_bg.rectangle([(0, 0), (S, S)], fill=(17, 20, 24, 255))
    bg.putalpha(mask)
    img.alpha_composite(bg)
    
    # Hairline outline
    rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_rim = ImageDraw.Draw(rim)
    draw_rim.rounded_rectangle(squircle_box, radius=radius, outline=(255, 255, 255, 18), width=3)
    rim.putalpha(mask)
    img.alpha_composite(rim)
    
    # Solid Clean Downward Arrow
    arrow_y = cy + 20
    stem_half = 200
    wing_half = 460
    
    top_y = arrow_y - 540
    shoulder_y = arrow_y + 30
    wing_tip_y = arrow_y + 90
    bottom_tip_y = arrow_y + 550
    
    outer_poly = [
        (cx - stem_half, top_y),
        (cx + stem_half, top_y),
        (cx + stem_half, shoulder_y),
        (cx + wing_half, wing_tip_y),
        (cx, bottom_tip_y),
        (cx - wing_half, wing_tip_y),
        (cx - stem_half, shoulder_y),
    ]
    
    # Inner Upward Arrow
    i_stem_half = 90
    i_wing_half = 230
    i_top_tip_y = arrow_y - 340
    i_wing_tip_y = arrow_y + 20
    i_shoulder_y = arrow_y - 30
    i_bottom_y = arrow_y + 360
    
    inner_poly = [
        (cx, i_top_tip_y),
        (cx + i_wing_half, i_wing_tip_y),
        (cx + i_stem_half, i_shoulder_y),
        (cx + i_stem_half, i_bottom_y),
        (cx - i_stem_half, i_bottom_y),
        (cx - i_stem_half, i_shoulder_y),
        (cx - i_wing_half, i_wing_tip_y),
    ]
    
    arrow_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_a = ImageDraw.Draw(arrow_layer)
    
    # Pure vibrant Electric Green #00E676
    draw_a.polygon(outer_poly, fill=(0, 230, 118, 255))
    # Direct negative space cutout to reveal the background
    draw_a.polygon(inner_poly, fill=(17, 20, 24, 255))
    
    img.alpha_composite(arrow_layer)
    return img.resize((1024, 1024), Image.Resampling.LANCZOS)

def generate_variant_c(size=2048):
    """
    Variant C: High-End Tech Dual Chevron Interlock.
    Outer downward green chevron, inner upward contrasting mint/cyan chevron.
    Looks like an aerospace / high-tech data transfer emblem.
    """
    S = size
    cx, cy = S // 2, S // 2
    margin = 180
    w = S - 2 * margin
    radius = 380
    squircle_box = [(margin, margin), (margin + w, margin + w)]
    
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    
    # Shadow
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_s = ImageDraw.Draw(shadow)
    draw_s.rounded_rectangle([(margin + 10, margin + 24), (margin + w - 10, margin + w + 24)], 
                             radius=radius, fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=40))
    img.alpha_composite(shadow)
    
    # Deep Dark Background
    mask = create_squircle_mask(S, margin, radius)
    bg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_bg = ImageDraw.Draw(bg)
    draw_bg.rectangle([(0, 0), (S, S)], fill=(15, 17, 21, 255))
    bg.putalpha(mask)
    img.alpha_composite(bg)
    
    rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_rim = ImageDraw.Draw(rim)
    draw_rim.rounded_rectangle(squircle_box, radius=radius, outline=(255, 255, 255, 20), width=3)
    rim.putalpha(mask)
    img.alpha_composite(rim)
    
    # Elegant Downward Arrow with rounded corner style
    arrow_y = cy + 20
    
    # Outer Downward Arrow
    stem_w = 210
    wing_w = 480
    top_y = arrow_y - 520
    shoulder_y = arrow_y + 40
    wing_tip_y = arrow_y + 100
    bottom_y = arrow_y + 570
    
    outer_poly = [
        (cx - stem_w, top_y),
        (cx + stem_w, top_y),
        (cx + stem_w, shoulder_y),
        (cx + wing_w, wing_tip_y),
        (cx, bottom_y),
        (cx - wing_w, wing_tip_y),
        (cx - stem_w, shoulder_y),
    ]
    
    # Inner Upward Arrow
    i_stem_w = 95
    i_wing_w = 230
    i_top_y = arrow_y - 320
    i_wing_tip_y = arrow_y + 20
    i_shoulder_y = arrow_y - 30
    i_bottom_y = arrow_y + 350
    
    inner_poly = [
        (cx, i_top_y),
        (cx + i_wing_w, i_wing_tip_y),
        (cx + i_stem_w, i_shoulder_y),
        (cx + i_stem_w, i_bottom_y),
        (cx - i_stem_w, i_bottom_y),
        (cx - i_stem_w, i_shoulder_y),
        (cx - i_wing_w, i_wing_tip_y),
    ]
    
    arrow_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_a = ImageDraw.Draw(arrow_layer)
    
    # Vibrant Cyber Green Gradient (top slightly brighter #10F284 to #00C853)
    draw_a.polygon(outer_poly, fill=(0, 230, 118, 255))
    
    # Cutout with a clean tech mint arrow inside
    draw_a.polygon(inner_poly, fill=(15, 17, 21, 255))
    
    # Inside the cutout, a clean floating upward arrow in Crisp White-Mint (#E0FFF0)
    # Scaled down slightly to float inside
    f_stem = 55
    f_wing = 145
    f_top = arrow_y - 230
    f_wing_tip = arrow_y - 20
    f_shoulder = arrow_y - 50
    f_bottom = arrow_y + 230
    float_poly = [
        (cx, f_top),
        (cx + f_wing, f_wing_tip),
        (cx + f_stem, f_shoulder),
        (cx + f_stem, f_bottom),
        (cx - f_stem, f_bottom),
        (cx - f_stem, f_shoulder),
        (cx - f_wing, f_wing_tip),
    ]
    draw_a.polygon(float_poly, fill=(0, 255, 136, 255))
    
    img.alpha_composite(arrow_layer)
    return img.resize((1024, 1024), Image.Resampling.LANCZOS)

if __name__ == '__main__':
    out_dir = '/tmp/kazumi_icon_preview'
    os.makedirs(out_dir, exist_ok=True)
    
    va = generate_variant_a(2048)
    va.save(os.path.join(out_dir, 'variant_a.png'), format='PNG')
    
    vb = generate_variant_b(2048)
    vb.save(os.path.join(out_dir, 'variant_b.png'), format='PNG')
    
    vc = generate_variant_c(2048)
    vc.save(os.path.join(out_dir, 'variant_c.png'), format='PNG')
    print("Generated variants A, B, C")
