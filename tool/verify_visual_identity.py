from PIL import Image, ImageDraw, ImageFilter
from test_unified_single_source import compute_master_glyph_polygons

def render_unified_dock(S=2048):
    geom = compute_master_glyph_polygons(S)
    
    # Obsidian squircle canvas
    margin = 180
    w = S - 2 * margin
    radius = 380
    squircle_box = [(margin, margin), (margin + w, margin + w)]
    
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    
    # Shadow
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_s = ImageDraw.Draw(shadow)
    draw_s.rounded_rectangle([(margin + 12, margin + 26), (margin + w - 12, margin + w + 26)], radius=radius, fill=(0, 0, 0, 160))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=46))
    img.alpha_composite(shadow)
    
    # BG
    mask = Image.new('L', (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle(squircle_box, radius=radius, fill=255)
    bg = Image.new('RGBA', (S, S), (20, 25, 32, 255))
    draw_bg = ImageDraw.Draw(bg)
    for y in range(margin, margin + w):
        t = (y - margin) / w
        r = int(22 * (1 - t) + 11 * t)
        g = int(27 * (1 - t) + 13 * t)
        b = int(34 * (1 - t) + 16 * t)
        draw_bg.line([(margin, y), (margin + w, y)], fill=(r, g, b, 255))
    glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([(S//2 - 500, S//2 - 350), (S//2 + 500, S//2 + 450)], fill=(0, 230, 120, 26))
    bg.alpha_composite(glow.filter(ImageFilter.GaussianBlur(radius=120)))
    bg.putalpha(mask)
    img.alpha_composite(bg)
    
    # Rim
    rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle(squircle_box, radius=radius, outline=(255, 255, 255, 26), width=3)
    rim.putalpha(mask)
    img.alpha_composite(rim)
    
    # Glyph layer
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # Eye shadows & fill
    for eye in (geom['left_eye'], geom['right_eye']):
        esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(esh).polygon([(p[0], p[1] + 24) for p in eye], fill=(0, 20, 10, 160))
        layer.alpha_composite(esh.filter(ImageFilter.GaussianBlur(radius=20)))
        draw.polygon(eye, fill=(80, 255, 185, 255))
        
    # Mouth shadow & fill
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_m = ImageDraw.Draw(msh)
    draw_m.polygon([(p[0], p[1] + 28) for p in geom['smile_ribbon']], fill=(0, 25, 12, 180))
    draw_m.polygon([(p[0], p[1] + 28) for p in geom['left_arrow']], fill=(0, 25, 12, 180))
    draw_m.polygon([(p[0], p[1] + 28) for p in geom['right_arrow']], fill=(0, 25, 12, 180))
    layer.alpha_composite(msh.filter(ImageFilter.GaussianBlur(radius=30)))
    
    draw.polygon(geom['smile_ribbon'], fill=(0, 226, 110, 255))
    
    # Left arrow (Download ⬇)
    draw.polygon([geom['l_tip'], geom['l_barb_out'], geom['l_notch']], fill=(0, 196, 92, 255))
    draw.polygon([geom['l_tip'], geom['l_notch'], geom['l_barb_in']], fill=(55, 248, 142, 255))
    draw.line([geom['l_barb_out'], geom['l_tip'], geom['l_barb_in']], fill=(255, 255, 255, 230), width=8)
    draw.line([geom['l_tip'], geom['l_notch']], fill=(255, 255, 255, 160), width=5)
    
    # Right arrow (Upload ⬆)
    draw.polygon([geom['r_tip'], geom['r_notch'], geom['r_barb_out']], fill=(20, 218, 134, 255))
    draw.polygon([geom['r_tip'], geom['r_barb_in'], geom['r_notch']], fill=(85, 255, 190, 255))
    draw.line([geom['r_barb_in'], geom['r_tip'], geom['r_barb_out']], fill=(255, 255, 255, 240), width=8)
    draw.line([geom['r_tip'], geom['r_notch']], fill=(255, 255, 255, 180), width=5)
    
    draw.line(geom['smile_outer'], fill=(255, 255, 255, 185), width=8)
    img.alpha_composite(layer)
    return img

def render_unified_tray(S=2048, target_size=72):
    geom = compute_master_glyph_polygons(S)
    
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # Draw exact same elements in solid pure white
    draw.polygon(geom['left_eye'], fill=(255, 255, 255, 255))
    draw.polygon(geom['right_eye'], fill=(255, 255, 255, 255))
    draw.polygon(geom['smile_ribbon'], fill=(255, 255, 255, 255))
    draw.polygon(geom['left_arrow'], fill=(255, 255, 255, 255))
    draw.polygon(geom['right_arrow'], fill=(255, 255, 255, 255))
    
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

dock = render_unified_dock().resize((1024, 1024), Image.Resampling.LANCZOS)
tray = render_unified_tray(target_size=72)

dock.save('/tmp/unified_dock_1024.png')
tray.save('/tmp/unified_tray_72.png')

print("Rendered unified dock and tray successfully!")
