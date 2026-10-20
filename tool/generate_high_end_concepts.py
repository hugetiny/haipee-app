import os
import math
from PIL import Image, ImageDraw, ImageFilter

def create_squircle_mask(size, margin, radius):
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    box = [(margin, margin), (size - margin, size - margin)]
    draw.rounded_rectangle(box, radius=radius, fill=255)
    return mask

def generate_concept_engraved_gem(size=2048):
    """
    Concept A: Precision Machined Dual-Arrow Emblem.
    - Deep Matte Obsidian Squircle (#111317 -> #0C0D10)
    - Outer: Sculpted Downward Arrow (Download ⬇) in vibrant Cyber Emerald (#00EE78 / #00B84D)
      with micro-beveled lighting facets.
    - Recessed Slot: Subtle dark metallic channel with soft inner shadow.
    - Inner: Crisp, luminous Upward Arrow (Upload ⬆) in Electric Mint (#34D399 / #6EE7B7 / #E6FFFA)
      with chamfered vertices and center spine highlight.
    - ZERO background glare, ZERO raw black cutout.
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
    
    # 5. Machined Recessed Slot (The housing for the upward arrow)
    slot_stem = 150
    slot_wing = 270
    slot_top = arrow_y - 390
    slot_shoulder = arrow_y + 40
    slot_wing_tip = arrow_y + 90
    slot_bottom = arrow_y + 420
    slot_bottom_notch = slot_bottom - 40
    
    slot_poly = [
        (cx, slot_top),
        (cx + slot_wing, slot_wing_tip),
        (cx + slot_stem, slot_shoulder),
        (cx + slot_stem, slot_bottom),
        (cx, slot_bottom_notch),
        (cx - slot_stem, slot_bottom),
        (cx - slot_stem, slot_shoulder),
        (cx - slot_wing, slot_wing_tip),
    ]
    
    # 6. Inner Luminous Upward Arrow (Upload ⬆)
    in_stem = 80
    in_wing = 180
    in_top = arrow_y - 280
    in_shoulder = arrow_y - 30
    in_wing_tip = arrow_y + 20
    in_bottom = arrow_y + 340
    in_bottom_notch = in_bottom - 30
    
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
    
    # Draw Outer Downward Arrow with faceted lighting
    # Left side: Luminous Cyber Emerald (#00F076)
    draw_a.polygon(left_outer, fill=(0, 240, 118, 255))
    # Right side: Rich Technical Emerald (#00BA4E)
    draw_a.polygon(right_outer, fill=(0, 186, 78, 255))
    # Crisp hairline center divider
    draw_a.line([(cx, outer_top_notch), (cx, outer_bottom_tip)], fill=(255, 255, 255, 50), width=3)
    # Beveled highlight along top and wing leading edges
    draw_a.line([(cx - outer_stem, outer_top), (cx, outer_top_notch)], fill=(255, 255, 255, 120), width=5)
    draw_a.line([(cx - outer_wing, outer_wing_tip), (cx, outer_bottom_tip)], fill=(255, 255, 255, 100), width=5)
    
    # Draw Machined Recessed Slot:
    # Deep matte charcoal slot with subtle dark border
    draw_a.polygon(slot_poly, fill=(13, 16, 20, 255))
    # Precision inner rim
    draw_a.polygon(slot_poly, outline=(0, 255, 140, 70), width=4)
    
    # Draw Inner Luminous Upward Arrow (NOT black! Vibrant Electric Mint & Ice Jade)
    # Left facet: Crisp Electric Mint (#4EFEB3)
    draw_a.polygon(in_left, fill=(78, 254, 179, 255))
    # Right facet: Deep Aqua Emerald (#10D680)
    draw_a.polygon(in_right, fill=(16, 214, 128, 255))
    # Inner center spine highlight
    draw_a.line([(cx, in_top), (cx, in_bottom_notch)], fill=(255, 255, 255, 140), width=4)
    # Top tip highlight
    draw_a.line([(cx - in_wing, in_wing_tip), (cx, in_top)], fill=(255, 255, 255, 160), width=4)
    
    img.alpha_composite(arrow_layer)
    return img.resize((1024, 1024), Image.Resampling.LANCZOS)

def generate_concept_interlocking_flow(size=2048):
    """
    Concept B: Interlocking Kinetic Cyber Chevrons (双向互锁流光图腾).
    - Top chevron points DOWN in Emerald Green (#00F076)
    - Bottom chevron points UP in Electric Mint (#34D399)
    - Interlocking like a Swiss watch gear or modern tech logo (Linear / Vercel grade)
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
    draw_s.rounded_rectangle(
        [(margin + 12, margin + 26), (margin + w - 12, margin + w + 26)], 
        radius=radius, 
        fill=(0, 0, 0, 120)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=42))
    img.alpha_composite(shadow)
    
    # Background
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
    
    # Rim
    rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_rim = ImageDraw.Draw(rim)
    draw_rim.rounded_rectangle(squircle_box, radius=radius, outline=(255, 255, 255, 22), width=3)
    rim.putalpha(mask)
    img.alpha_composite(rim)
    
    # Two Interlocking High-Tech Arrows:
    # Arrow 1: Downward (Download ⬇) - Emerald Green (#00F076)
    # Arrow 2: Upward (Upload ⬆) - Electric Mint (#2DD4BF / #6EE7B7)
    
    arrow_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_a = ImageDraw.Draw(arrow_layer)
    
    # Downward Arrow (Left & Upper Dominance)
    d_top = cy - 540
    d_tip = cy + 280
    d_wing_w = 480
    d_stem_w = 200
    d_shoulder = cy - 20
    d_wing_tip = cy + 40
    
    d_left = [
        (cx, d_top + 40),
        (cx - d_stem_w, d_top),
        (cx - d_stem_w, d_shoulder),
        (cx - d_wing_w, d_wing_tip),
        (cx, d_tip),
    ]
    d_right = [
        (cx, d_top + 40),
        (cx + d_stem_w, d_top),
        (cx + d_stem_w, d_shoulder),
        (cx + d_wing_w, d_wing_tip),
        (cx, d_tip),
    ]
    
    draw_a.polygon(d_left, fill=(0, 240, 118, 255))
    draw_a.polygon(d_right, fill=(0, 186, 78, 255))
    
    # Cutout channel for the upward arrow
    gap = 40
    cutout = [
        (cx, cy - 240 - gap),
        (cx + 220 + gap, cy + 60 + gap),
        (cx + 100 + gap, cy + 30 + gap),
        (cx + 100 + gap, cy + 460 + gap),
        (cx - 100 - gap, cy + 460 + gap),
        (cx - 100 - gap, cy + 30 + gap),
        (cx - 220 - gap, cy + 60 + gap),
    ]
    draw_a.polygon(cutout, fill=(13, 16, 20, 255))
    
    # Upward Arrow (Nested firmly inside)
    u_top = cy - 240
    u_wing_w = 220
    u_stem_w = 100
    u_shoulder = cy + 30
    u_wing_tip = cy + 60
    u_bottom = cy + 460
    
    u_left = [
        (cx, u_top),
        (cx - u_wing_w, u_wing_tip),
        (cx - u_stem_w, u_shoulder),
        (cx - u_stem_w, u_bottom),
        (cx, u_bottom - 30),
    ]
    u_right = [
        (cx, u_top),
        (cx + u_wing_w, u_wing_tip),
        (cx + u_stem_w, u_shoulder),
        (cx + u_stem_w, u_bottom),
        (cx, u_bottom - 30),
    ]
    
    draw_a.polygon(u_left, fill=(80, 255, 185, 255))
    draw_a.polygon(u_right, fill=(20, 220, 140, 255))
    draw_a.line([(cx, u_top), (cx, u_bottom - 30)], fill=(255, 255, 255, 140), width=4)
    
    img.alpha_composite(arrow_layer)
    return img.resize((1024, 1024), Image.Resampling.LANCZOS)

if __name__ == '__main__':
    out_dir = '/tmp/kazumi_icon_preview'
    os.makedirs(out_dir, exist_ok=True)
    
    c1 = generate_concept_engraved_gem(2048)
    c1.save(os.path.join(out_dir, 'concept_engraved_gem.png'))
    
    c2 = generate_concept_interlocking_flow(2048)
    c2.save(os.path.join(out_dir, 'concept_interlocking_flow.png'))
    print("Generated high-end concept icons!")
