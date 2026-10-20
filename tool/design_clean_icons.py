import os
import math
from PIL import Image, ImageDraw, ImageFilter

def create_squircle_mask(size, margin, radius):
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    box = [(margin, margin), (size - margin, size - margin)]
    draw.rounded_rectangle(box, radius=radius, fill=255)
    return mask

def generate_clean_icon(variant="negative_cutout", size=2048):
    S = size
    cx, cy = S // 2, S // 2
    
    # macOS standard icon proportions
    # Margin ~ 180 on 2048 canvas
    margin = 180
    w = S - 2 * margin
    radius = 380
    squircle_box = [(margin, margin), (margin + w, margin + w)]
    
    # 1. Base image with transparent background
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    
    # 2. Realistic subtle macOS dock drop shadow
    shadow_offset = 24
    shadow_blur = 40
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_shadow = ImageDraw.Draw(shadow)
    shadow_box = [(margin + 10, margin + shadow_offset), (margin + w - 10, margin + w + shadow_offset)]
    draw_shadow.rounded_rectangle(shadow_box, radius=radius, fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=shadow_blur))
    img.alpha_composite(shadow)
    
    # 3. Squircle Background - Clean Matte Obsidian / Cyber Dark (NO GLOW, NO RADAR, NO GRID)
    squircle_mask = create_squircle_mask(S, margin, radius)
    bg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_bg = ImageDraw.Draw(bg)
    
    # Subtle, premium vertical gradient: #191C22 at top to #0F1115 at bottom
    for y in range(margin, margin + w):
        t = (y - margin) / w
        r = int(24 * (1 - t) + 14 * t)
        g = int(27 * (1 - t) + 16 * t)
        b = int(32 * (1 - t) + 20 * t)
        draw_bg.line([(margin, y), (margin + w, y)], fill=(r, g, b, 255))
        
    bg.putalpha(squircle_mask)
    img.alpha_composite(bg)
    
    # 4. Subtle Bezel Edge (1px hairline highlight at top, dark rim)
    rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_rim = ImageDraw.Draw(rim)
    # Subtle inner border
    draw_rim.rounded_rectangle(squircle_box, radius=radius, outline=(255, 255, 255, 24), width=4)
    # Very subtle green tech tint on the rim
    draw_rim.rounded_rectangle([(margin + 2, margin + 2), (margin + w - 2, margin + w - 2)], 
                               radius=radius - 2, outline=(0, 230, 118, 30), width=2)
    rim.putalpha(squircle_mask)
    img.alpha_composite(rim)
    
    # 5. FOREGROUND: The Nested Arrows (Download ⬇ & Upload ⬆)
    # Outer Downward Arrow geometry
    # Perfectly centered and balanced
    # Optical center slightly adjusted
    arrow_center_y = cy + 20
    
    # Dimensions for Outer Downward Arrow
    outer_stem_w = 260       # half-width of stem
    outer_wing_w = 560       # half-width of wings
    outer_top_y = arrow_center_y - 620
    outer_wing_top_y = arrow_center_y + 100
    outer_wing_tip_y = arrow_center_y + 140
    outer_tip_y = arrow_center_y + 640
    
    # Outer arrow polygon
    outer_poly = [
        (cx - outer_stem_w, outer_top_y),
        (cx + outer_stem_w, outer_top_y),
        (cx + outer_stem_w, outer_wing_top_y),
        (cx + outer_wing_w, outer_wing_tip_y),
        (cx, outer_tip_y),
        (cx - outer_wing_w, outer_wing_tip_y),
        (cx - outer_stem_w, outer_wing_top_y),
    ]
    
    # Inner Upward Arrow geometry
    # Nested cleanly inside the body
    inner_stem_w = 110
    inner_wing_w = 260
    inner_tip_y = arrow_center_y - 400
    inner_wing_base_y = arrow_center_y + 40
    inner_wing_tip_y = arrow_center_y + 80
    inner_bottom_y = arrow_center_y + 420
    
    inner_poly = [
        (cx, inner_tip_y),
        (cx + inner_wing_w, inner_wing_tip_y),
        (cx + inner_stem_w, inner_wing_base_y),
        (cx + inner_stem_w, inner_bottom_y),
        (cx - inner_stem_w, inner_bottom_y),
        (cx - inner_stem_w, inner_wing_base_y),
        (cx - inner_wing_w, inner_wing_tip_y),
    ]
    
    # Render arrow layer
    arrow_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_arrow = ImageDraw.Draw(arrow_layer)
    
    # Geometric clean dual-tone or crisp tech green
    # Left facet slightly brighter: #00F076 (0, 240, 118)
    # Right facet slightly deeper: #00C853 (0, 200, 83)
    # This gives a clean, crisp, modern faceted vector look without any blur or glare!
    outer_left_poly = [
        (cx, outer_top_y),
        (cx - outer_stem_w, outer_top_y),
        (cx - outer_stem_w, outer_wing_top_y),
        (cx - outer_wing_w, outer_wing_tip_y),
        (cx, outer_tip_y),
    ]
    outer_right_poly = [
        (cx, outer_top_y),
        (cx + outer_stem_w, outer_top_y),
        (cx + outer_stem_w, outer_wing_top_y),
        (cx + outer_wing_w, outer_wing_tip_y),
        (cx, outer_tip_y),
    ]
    
    # Crisp, punchy Geek Green
    draw_arrow.polygon(outer_left_poly, fill=(0, 235, 115, 255))
    draw_arrow.polygon(outer_right_poly, fill=(0, 195, 85, 255))
    
    # Crisp hairline center divider line
    draw_arrow.line([(cx, outer_top_y), (cx, outer_tip_y)], fill=(255, 255, 255, 70), width=3)
    
    # Cutout the inner upward arrow cleanly
    draw_arrow.polygon(inner_poly, fill=(0, 0, 0, 0))
    
    # Now inside the cutout:
    # Fill with deep obsidian void matching the background, with a crisp clean contour
    inner_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_inner = ImageDraw.Draw(inner_layer)
    draw_inner.polygon(inner_poly, fill=(16, 19, 23, 255))
    # Crisp clean inner outline (pure minimalist tech line, no blur)
    draw_inner.polygon(inner_poly, outline=(0, 255, 136, 180), width=6)
    
    arrow_layer.alpha_composite(inner_layer)
    
    img.alpha_composite(arrow_layer)
    
    final_icon = img.resize((1024, 1024), Image.Resampling.LANCZOS)
    return final_icon

if __name__ == '__main__':
    out_dir = '/tmp/kazumi_icon_preview'
    os.makedirs(out_dir, exist_ok=True)
    icon = generate_clean_icon('clean_geek', 2048)
    out_path = os.path.join(out_dir, 'clean_geek_icon.png')
    icon.save(out_path, format='PNG')
    print(f"Generated clean icon at {out_path}")
