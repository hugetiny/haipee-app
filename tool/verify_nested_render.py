from PIL import Image, ImageDraw, ImageFilter
from test_nested_arrows import compute_nested_arrow_polygons

def render_nested_dock_icon(S=2048):
    geom = compute_nested_arrow_polygons(S)
    
    # Obsidian squircle canvas
    margin = 180
    w = S - 2 * margin
    radius = 380
    squircle_box = [(margin, margin), (margin + w, margin + w)]
    
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    
    # 1. macOS dock drop shadow
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_s = ImageDraw.Draw(shadow)
    draw_s.rounded_rectangle([(margin + 12, margin + 26), (margin + w - 12, margin + w + 26)], radius=radius, fill=(0, 0, 0, 160))
    draw_s.rounded_rectangle([(margin + 20, margin + 46), (margin + w - 20, margin + w + 46)], radius=radius, fill=(0, 0, 0, 100))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=46))
    img.alpha_composite(shadow)
    
    # 2. Pure Matte Obsidian Background
    mask = Image.new('L', (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle(squircle_box, radius=radius, fill=255)
    bg = Image.new('RGBA', (S, S), (20, 24, 30, 255))
    draw_bg = ImageDraw.Draw(bg)
    for y in range(margin, margin + w):
        t = (y - margin) / w
        r = int(22 * (1 - t) + 11 * t)
        g = int(26 * (1 - t) + 13 * t)
        b = int(32 * (1 - t) + 16 * t)
        draw_bg.line([(margin, y), (margin + w, y)], fill=(r, g, b, 255))
        
    glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([(S//2 - 500, S//2 - 350), (S//2 + 500, S//2 + 450)], fill=(0, 230, 120, 28))
    bg.alpha_composite(glow.filter(ImageFilter.GaussianBlur(radius=120)))
    bg.putalpha(mask)
    img.alpha_composite(bg)
    
    # 3. Micro Bezel Rim (1px hairline)
    rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle(squircle_box, radius=radius, outline=(255, 255, 255, 26), width=3)
    rim.putalpha(mask)
    img.alpha_composite(rim)
    
    # 4. Outer Downward Arrow (Download ⬇)
    outer_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_out = ImageDraw.Draw(outer_layer)
    draw_out.polygon(geom['left_outer'], fill=(0, 238, 120, 255))
    draw_out.polygon(geom['right_outer'], fill=(0, 186, 78, 255))
    draw_out.line([(geom['cx'], geom['outer_top_notch']), (geom['cx'], geom['outer_bottom_tip'])], fill=(255, 255, 255, 50), width=3)
    draw_out.line([(geom['cx'] - geom['outer_stem'], geom['outer_top']), (geom['cx'], geom['outer_top_notch'])], fill=(255, 255, 255, 120), width=5)
    draw_out.line([(geom['cx'] - geom['outer_wing'], geom['outer_wing_tip']), (geom['cx'], geom['outer_bottom_tip'])], fill=(255, 255, 255, 100), width=5)
    img.alpha_composite(outer_layer)
    
    # 5. Inner Arrow Contact Shadow
    inner_shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_is = ImageDraw.Draw(inner_shadow)
    in_poly_shadow = [(p[0], p[1] + 18) for p in geom['in_poly']]
    draw_is.polygon(in_poly_shadow, fill=(0, 20, 10, 160))
    inner_shadow = inner_shadow.filter(ImageFilter.GaussianBlur(radius=22))
    img.alpha_composite(inner_shadow)
    
    # 6. Floating Elevated Upward Arrow (Upload ⬆)
    inner_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_in = ImageDraw.Draw(inner_layer)
    draw_in.polygon(geom['in_left'], fill=(80, 255, 185, 255))
    draw_in.polygon(geom['in_right'], fill=(20, 215, 135, 255))
    draw_in.line([(geom['cx'], geom['in_top']), (geom['cx'], geom['in_bottom_notch'])], fill=(255, 255, 255, 160), width=4)
    draw_in.line([(geom['cx'] - geom['in_wing'], geom['in_wing_tip']), (geom['cx'], geom['in_top'])], fill=(255, 255, 255, 180), width=5)
    draw_in.polygon(geom['in_poly'], outline=(255, 255, 255, 60), width=2)
    img.alpha_composite(inner_layer)
    
    return img

def render_nested_tray_icon(target_size=72):
    S = 2048
    geom = compute_nested_arrow_polygons(S)
    
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # 1. Outer Downward Arrow (Solid pure white)
    draw.polygon(geom['outer_poly'], fill=(255, 255, 255, 255))
    
    # 2. Inner Upward Arrow (Transparent cutout)
    draw.polygon(geom['in_poly'], fill=(0, 0, 0, 0))
    
    # Tightly crop to 92% of the canvas height/width so it appears large & prominent in the menu bar
    bbox = layer.getbbox()
    bw = bbox[2] - bbox[0]
    bh = bbox[3] - bbox[1]
    dim = max(bw, bh)
    bcx = (bbox[0] + bbox[2]) // 2
    bcy = (bbox[1] + bbox[3]) // 2
    
    pad = int(dim * 0.04) # 4% optical margin
    crop_box = (
        bcx - dim // 2 - pad,
        bcy - dim // 2 - pad,
        bcx + dim // 2 + pad,
        bcy + dim // 2 + pad,
    )
    cropped = layer.crop(crop_box)
    return cropped.resize((target_size, target_size), Image.Resampling.LANCZOS)

dock = render_nested_dock_icon().resize((1024, 1024), Image.Resampling.LANCZOS)
tray = render_nested_tray_icon(72)

dock.save('/tmp/nested_dock_1024.png')
tray.save('/tmp/nested_tray_72.png')

print("Rendered nested dock and tray successfully!")
print("Tray bbox:", tray.getbbox())
