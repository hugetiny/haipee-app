import math
from PIL import Image, ImageDraw, ImageFilter

def compute_nested_arrow_polygons(S=2048):
    cx, cy = S // 2, S // 2 + 10
    
    # 1. OUTER DOWNWARD ARROW (Download ⬇)
    outer_stem = 280
    outer_wing = 580
    outer_top = cy - 580
    outer_top_notch = outer_top + 45
    outer_shoulder = cy + 90
    outer_wing_tip = cy + 150
    outer_bottom_tip = cy + 620
    
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
    
    # 2. INNER UPWARD ARROW (Upload ⬆)
    in_stem = 105
    in_wing = 230
    in_top = cy - 340
    in_shoulder = cy - 30
    in_wing_tip = cy + 30
    in_bottom = cy + 400
    in_bottom_notch = in_bottom - 38
    
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
    
    return {
        'cx': cx,
        'cy': cy,
        'outer_poly': outer_poly,
        'left_outer': left_outer,
        'right_outer': right_outer,
        'outer_top_notch': outer_top_notch,
        'outer_bottom_tip': outer_bottom_tip,
        'outer_stem': outer_stem,
        'outer_top': outer_top,
        'outer_wing': outer_wing,
        'outer_wing_tip': outer_wing_tip,
        'in_poly': in_poly,
        'in_left': in_left,
        'in_right': in_right,
        'in_top': in_top,
        'in_bottom_notch': in_bottom_notch,
        'in_wing': in_wing,
        'in_wing_tip': in_wing_tip,
    }

print("Nested arrow polygons defined successfully!")
