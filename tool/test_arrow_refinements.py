import os
import math
from PIL import Image, ImageDraw, ImageFilter
from render_masterpiece import create_luxury_obsidian_canvas

def test_option_1_perfect_tangent(target_size=1024):
    """Option 1: Left arrow points down-outward, perfectly tangent to ribbon."""
    S = 2048
    canvas = create_luxury_obsidian_canvas(S)
    cx, cy = S // 2, S // 2 - 20
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # EYES
    eye_y = cy - 165
    eye_spacing = 280
    eye_span = 195
    eye_h = 148
    notch_h = 54
    for side in (-1, 1):
        ecx = cx + side * eye_spacing
        top_tip = (ecx, eye_y - 36)
        r_outer = (ecx + eye_span, eye_y + eye_h)
        r_inner = (ecx + eye_span - 60, eye_y + eye_h + 40)
        bottom_notch = (ecx, eye_y + notch_h)
        l_inner = (ecx - eye_span + 60, eye_y + eye_h + 40)
        l_outer = (ecx - eye_span, eye_y + eye_h)
        poly_full = [top_tip, r_outer, r_inner, bottom_notch, l_inner, l_outer]
        
        esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        draw_esh = ImageDraw.Draw(esh)
        draw_esh.polygon([(p[0], p[1] + 24) for p in poly_full], fill=(0, 20, 10, 160))
        esh = esh.filter(ImageFilter.GaussianBlur(radius=22))
        layer.alpha_composite(esh)
        
        draw.polygon([top_tip, bottom_notch, l_inner, l_outer], fill=(88, 255, 192, 255))
        draw.polygon([top_tip, r_outer, r_inner, bottom_notch], fill=(20, 216, 132, 255))
        draw.line([l_outer, top_tip, r_outer], fill=(255, 255, 255, 240), width=9)
        draw.line([top_tip, bottom_notch], fill=(255, 255, 255, 190), width=5)

    # MOUTH
    mouth_cy = cy + 105
    mouth_rx = 570
    mouth_ry = 380
    deg_start = 32
    deg_end = 148
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
        thick = 90 + 42 * t
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_ribbon = pts_outer + pts_inner
    
    # Left Arrow (Download ⬇): Smooth tangent along curve end
    lx = pts_outer[0][0]
    ly = pts_outer[0][1]
    lx_in = pts_inner[-1][0]
    ly_in = pts_inner[-1][1]
    lx_mid = (lx + lx_in) / 2
    ly_mid = (ly + ly_in) / 2
    
    # Direction is along curve normal and tangent
    l_tip = (lx_mid - 65, ly_mid + 110)
    l_barb_out = (lx_mid - 110, ly_mid - 15)
    l_notch = (lx_mid, ly_mid)
    l_barb_in = (lx_mid + 55, ly_mid - 15)
    l_arrow = [l_tip, l_barb_out, l_notch, l_barb_in]
    
    # Right Arrow (Upload ⬆)
    rx = pts_outer[-1][0]
    ry = pts_outer[-1][1]
    rx_in = pts_inner[0][0]
    ry_in = pts_inner[0][1]
    rx_mid = (rx + rx_in) / 2
    ry_mid = (ry + ry_in) / 2
    
    r_tip = (rx_mid + 65, ry_mid - 110)
    r_barb_out = (rx_mid + 110, ry_mid + 15)
    r_notch = (rx_mid, ry_mid)
    r_barb_in = (rx_mid - 55, ry_mid + 15)
    r_arrow = [r_tip, r_barb_in, r_notch, r_barb_out]
    
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_msh = ImageDraw.Draw(msh)
    draw_msh.polygon([(p[0], p[1] + 30) for p in smile_ribbon], fill=(0, 25, 12, 180))
    draw_msh.polygon([(p[0], p[1] + 30) for p in l_arrow], fill=(0, 25, 12, 180))
    draw_msh.polygon([(p[0], p[1] + 30) for p in r_arrow], fill=(0, 25, 12, 180))
    msh = msh.filter(ImageFilter.GaussianBlur(radius=32))
    layer.alpha_composite(msh)
    
    draw.polygon(smile_ribbon, fill=(0, 226, 110, 255))
    draw.polygon([l_tip, l_barb_out, l_notch], fill=(0, 240, 122, 255))
    draw.polygon([l_tip, l_notch, l_barb_in], fill=(0, 192, 86, 255))
    draw.line([(l_barb_out[0], l_barb_out[1]), (l_tip[0], l_tip[1])], fill=(255, 255, 255, 220), width=7)
    
    draw.polygon([r_tip, r_barb_in, r_notch], fill=(85, 255, 188, 255))
    draw.polygon([r_tip, r_notch, r_barb_out], fill=(22, 218, 134, 255))
    draw.line([(r_barb_in[0], r_barb_in[1]), (r_tip[0], r_tip[1])], fill=(255, 255, 255, 240), width=8)
    
    draw.line(pts_outer, fill=(255, 255, 255, 185), width=9)
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

def test_option_2_dual_cheek_lift(target_size=1024):
    """Option 2: Dual lifting cheek arrowheads (Symmetrical joyful smile cheeks)"""
    S = 2048
    canvas = create_luxury_obsidian_canvas(S)
    cx, cy = S // 2, S // 2 - 20
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    
    # EYES
    eye_y = cy - 165
    eye_spacing = 280
    eye_span = 195
    eye_h = 148
    notch_h = 54
    for side in (-1, 1):
        ecx = cx + side * eye_spacing
        top_tip = (ecx, eye_y - 36)
        r_outer = (ecx + eye_span, eye_y + eye_h)
        r_inner = (ecx + eye_span - 60, eye_y + eye_h + 40)
        bottom_notch = (ecx, eye_y + notch_h)
        l_inner = (ecx - eye_span + 60, eye_y + eye_h + 40)
        l_outer = (ecx - eye_span, eye_y + eye_h)
        poly_full = [top_tip, r_outer, r_inner, bottom_notch, l_inner, l_outer]
        
        esh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        draw_esh = ImageDraw.Draw(esh)
        draw_esh.polygon([(p[0], p[1] + 24) for p in poly_full], fill=(0, 20, 10, 160))
        esh = esh.filter(ImageFilter.GaussianBlur(radius=22))
        layer.alpha_composite(esh)
        
        draw.polygon([top_tip, bottom_notch, l_inner, l_outer], fill=(88, 255, 192, 255))
        draw.polygon([top_tip, r_outer, r_inner, bottom_notch], fill=(20, 216, 132, 255))
        draw.line([l_outer, top_tip, r_outer], fill=(255, 255, 255, 240), width=9)
        draw.line([top_tip, bottom_notch], fill=(255, 255, 255, 190), width=5)

    # MOUTH
    mouth_cy = cy + 105
    mouth_rx = 570
    mouth_ry = 380
    deg_start = 28
    deg_end = 152
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
        thick = 90 + 42 * t
        pts_outer.append((x - nx * (thick / 2), y - ny * (thick / 2)))
        pts_inner.insert(0, (x + nx * (thick / 2), y + ny * (thick / 2)))
        
    smile_ribbon = pts_outer + pts_inner
    
    # Both cheeks lift up with sleek arrowheads (Upload dimples)
    rx_mid = (pts_outer[-1][0] + pts_inner[0][0]) / 2
    ry_mid = (pts_outer[-1][1] + pts_inner[0][1]) / 2
    r_tip = (rx_mid + 45, ry_mid - 125)
    r_barb_out = (rx_mid + 125, ry_mid + 36)
    r_notch = (rx_mid + 15, ry_mid + 10)
    r_barb_in = (rx_mid - 82, ry_mid + 32)
    r_arrow = [r_tip, r_barb_out, r_notch, r_barb_in]
    
    lx_mid = (pts_outer[0][0] + pts_inner[-1][0]) / 2
    ly_mid = (pts_outer[0][1] + pts_inner[-1][1]) / 2
    l_tip = (lx_mid - 45, ly_mid - 125)
    l_barb_out = (lx_mid - 125, ly_mid + 36)
    l_notch = (lx_mid - 15, ly_mid + 10)
    l_barb_in = (lx_mid + 82, ly_mid + 32)
    l_arrow = [l_tip, l_barb_out, l_notch, l_barb_in]
    
    msh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_msh = ImageDraw.Draw(msh)
    draw_msh.polygon([(p[0], p[1] + 30) for p in smile_ribbon], fill=(0, 25, 12, 180))
    draw_msh.polygon([(p[0], p[1] + 30) for p in l_arrow], fill=(0, 25, 12, 180))
    draw_msh.polygon([(p[0], p[1] + 30) for p in r_arrow], fill=(0, 25, 12, 180))
    msh = msh.filter(ImageFilter.GaussianBlur(radius=32))
    layer.alpha_composite(msh)
    
    draw.polygon(smile_ribbon, fill=(0, 226, 110, 255))
    draw.polygon([l_tip, l_notch, l_barb_in], fill=(85, 255, 188, 255))
    draw.polygon([l_tip, l_barb_out, l_notch], fill=(22, 218, 134, 255))
    draw.line([(l_barb_in[0], l_barb_in[1]), (l_tip[0], l_tip[1])], fill=(255, 255, 255, 240), width=8)
    
    draw.polygon([r_tip, r_barb_in, r_notch], fill=(85, 255, 188, 255))
    draw.polygon([r_tip, r_notch, r_barb_out], fill=(22, 218, 134, 255))
    draw.line([(r_barb_in[0], r_barb_in[1]), (r_tip[0], r_tip[1])], fill=(255, 255, 255, 240), width=8)
    
    draw.line(pts_outer, fill=(255, 255, 255, 185), width=9)
    canvas.alpha_composite(layer)
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

if __name__ == '__main__':
    out_dir = '/tmp/kazumi_refinements'
    os.makedirs(out_dir, exist_ok=True)
    test_option_1_perfect_tangent(1024).save(os.path.join(out_dir, 'option_1_tangent.png'))
    test_option_2_dual_cheek_lift(1024).save(os.path.join(out_dir, 'option_2_dual_cheek.png'))
    print("Refinements generated in", out_dir)
