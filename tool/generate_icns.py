import os
import subprocess
from PIL import Image

def generate_icns(master_png_path, output_icns_path):
    master = Image.open(master_png_path)
    iconset_dir = "/tmp/kazumi_app.iconset"
    os.makedirs(iconset_dir, exist_ok=True)
    
    sizes = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]
    
    for filename, sz in sizes:
        dst = os.path.join(iconset_dir, filename)
        resized = master.resize((sz, sz), Image.Resampling.LANCZOS)
        resized.save(dst, format="PNG")
        
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", output_icns_path], check=True)
    print(f"Generated {output_icns_path}")

if __name__ == "__main__":
    master_png = "/Users/a12/projects/kazumi/assets/images/logo/logo_rounded.png"
    target_icns = "/Users/a12/projects/kazumi/build/macos/Build/Products/Debug/kazumi.app/Contents/Resources/AppIcon.icns"
    generate_icns(master_png, target_icns)
