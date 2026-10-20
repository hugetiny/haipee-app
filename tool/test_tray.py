import os
from PIL import Image, ImageDraw

def generate_clean_tray_icon(target_size=72):
    # Render at 512x512 supersampled
    S = 512
    cx, cy = S // 2, S // 2
    
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    arrow_y = cy + 10
    
    # Outer Downward Arrow (Solid White)
    outer_stem = 65
    outer_wing = 145
    outer_top = arrow_y - 150
    outer_top_notch = outer_top + 12
    outer_shoulder = arrow_y + 20
    outer_wing_tip = arrow_y + 35
    outer_bottom_tip = arrow_y + 160
    
    outer_poly = [
        (cx, outer_top_notch),
        (cx - outer_stem, outer_top),
        (cx - outer_stem, outer_shoulder),
        (cx - outer_wing, outer_wing_tip),
        (cx, outer_bottom_tip),
        (cx + outer_wing, outer_wing_tip),
        (cx + outer_stem, outer_shoulder),
        (cx + outer_stem, outer_top),
    ]
    draw.polygon(outer_poly, fill=(255, 255, 255, 255))
    
    # Inner Upward Arrow (Clean Cutout - Transparent)
    in_stem = 24
    in_wing = 55
    in_top = arrow_y - 80
    in_shoulder = arrow_y - 10
    in_wing_tip = arrow_y + 6
    in_bottom = arrow_y + 90
    in_bottom_notch = in_bottom - 10
    
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
    draw.polygon(in_poly, fill=(0, 0, 0, 0))
    
    final_tray = img.resize((target_size, target_size), Image.Resampling.LANCZOS)
    return final_tray

if __name__ == '__main__':
    out_dir = '/tmp/kazumi_icon_preview'
    tray = generate_clean_tray_icon(72)
    tray.save(os.path.join(out_dir, "clean_tray_preview.png"))
    print("Saved clean tray preview!")
