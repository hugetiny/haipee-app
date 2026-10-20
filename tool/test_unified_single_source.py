import math
from PIL import Image, ImageDraw, ImageFilter

def compute_master_glyph_polygons(S=2048):
    """
    SINGLE SOURCE OF TRUTH:
    Returns (left_eye, right_eye, smile_ribbon, left_arrow, right_arrow, smile_outer_edge)
    All coordinates defined ONCE with mathematical precision.
    """
    cx, cy = S // 2, S // 2 - 20
    
    # 1. EYES
    eye_spacing = 280
    eye_y = cy - 140
    eye_rx = 160
    eye_ry = 95
    eye_thick = 85
    
    eyes = []
    for side in (-1, 1):
        ecx = cx + side * eye_spacing
        pts_outer = []
        pts_inner = []
        for deg in range(195, 346, 3):
            rad = math.radians(deg)
            ox = ecx + eye_rx * math.cos(rad)
            oy = eye_y + eye_ry * math.sin(rad)
            nx = math.cos(rad)
            ny = math.sin(rad)
            t = math.sin(math.radians(deg - 180))
            cur_th = eye_thick * (0.70 + 0.38 * t)
            pts_outer.append((ox - nx * (cur_th / 2), oy - ny * (cur_th / 2)))
            pts_inner.insert(0, (ox + nx * (cur_th / 2), oy + ny * (cur_th / 2)))
        eyes.append(pts_outer + pts_inner)
        
    # 2. SMILE RIBBON
    mouth_cy = cy + 90
    mouth_rx = 560
    mouth_ry = 380
    
    deg_start = 30
    deg_end = 150
    pts_outer = []
    pts_inner = []
    
    for deg in range(deg_start, deg_end + 1, 2):
        rad = math.radians(deg)
        x = cx - mouth_rx * math.cos(rad)
        y = mouth_cy + mouth_ry * math.sin(rad)
        nx = -math.cos(rad)
        ny = math.sin(rad)
        nl = math.sqrt(nx*nx + ny*ny)
        nx /= nl
        ny /= nl
        t = math.sin(rad)
        thick = 95 + 42 * t
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_ribbon = pts_outer + pts_inner
    
    # 3. LEFT ARROW (Download ⬇)
    lx_mid = (pts_outer[0][0] + pts_inner[-1][0]) / 2
    ly_mid = (pts_outer[0][1] + pts_inner[-1][1]) / 2
    l_tip = (lx_mid - 75, ly_mid + 170)
    l_barb_out = (lx_mid - 160, ly_mid - 15)
    l_notch = (lx_mid - 15, ly_mid + 20)
    l_barb_in = (lx_mid + 80, ly_mid - 25)
    left_arrow = [l_tip, l_barb_out, l_notch, l_barb_in]
    
    # 4. RIGHT ARROW (Upload ⬆)
    rx_mid = (pts_outer[-1][0] + pts_inner[0][0]) / 2
    ry_mid = (pts_outer[-1][1] + pts_inner[0][1]) / 2
    r_tip = (rx_mid + 75, ry_mid - 170)
    r_barb_out = (rx_mid + 160, ry_mid + 15)
    r_notch = (rx_mid + 15, ry_mid - 20)
    r_barb_in = (rx_mid - 80, ry_mid + 25)
    right_arrow = [r_tip, r_barb_in, r_notch, r_barb_out]
    
    return {
        'left_eye': eyes[0],
        'right_eye': eyes[1],
        'smile_ribbon': smile_ribbon,
        'smile_outer': pts_outer,
        'left_arrow': left_arrow,
        'right_arrow': right_arrow,
        'l_tip': l_tip,
        'l_barb_out': l_barb_out,
        'l_notch': l_notch,
        'l_barb_in': l_barb_in,
        'r_tip': r_tip,
        'r_barb_out': r_barb_out,
        'r_notch': r_notch,
        'r_barb_in': r_barb_in,
    }

print("Master geometry defined!")
