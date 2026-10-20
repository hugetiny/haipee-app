import os
from PIL import Image

target_size = (1024, 1024)
for root, dirs, files in os.walk("/Users/a12/projects/kazumi"):
    if ".git" in root:
        continue
    for f in files:
        if f.endswith(".png") or f.endswith(".icns"):
            p = os.path.join(root, f)
            try:
                im = Image.open(p)
                # check if corner pixel is white/light or transparent
                # or check color at (512, 100) - in anime girl it is green hair (around 150, 220, 130)
                # in our new icon it is black/dark void (around 10, 18, 22)
                im_rgb = im.convert("RGBA")
                pixel = im_rgb.getpixel((im.width // 2, 100 * im.height // 1024))
                if pixel[1] > 180 and pixel[0] < 180 and pixel[2] < 180 and pixel[3] > 200:
                    print(f"ANIME GIRL FOUND AT: {p} (pixel: {pixel}, size: {im.size})")
            except Exception:
                pass
print("Scan finished.")
