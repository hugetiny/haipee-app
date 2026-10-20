import os
import subprocess
from PIL import Image, ImageDraw, ImageFilter
from verify_nested_render import render_nested_dock_icon, render_nested_tray_icon

def deploy():
    print("🎨 [1/5] Rendering 1024x1024 Master P2P Nested Arrow Dock Icon (下箭头套上箭头)...")
    dock_icon = render_nested_dock_icon(2048).resize((1024, 1024), Image.Resampling.LANCZOS)
    dock_icon.save("assets/images/logo/logo_rounded.png")
    dock_icon.save("assets/images/logo/logo_linux.png")
    dock_icon.save("assets/images/logo/logo_android.png")
    dock_icon.save("assets/images/logo/logo_ios.png")
    
    print("🎨 [2/5] Rendering macOS Menu Bar Tray Icon (Tightly Cropped, High-Contrast Template)...")
    tray_icon = render_nested_tray_icon(72)
    tray_icon.save("assets/images/logo/tray_icon_macos.png")
    
    print("🎨 [3/5] Generating Windows ICOs...")
    dock_icon.save("assets/images/logo/logo_windows.ico", format='ICO', sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    dock_icon.save("assets/images/logo/logo_lanczos.ico", format='ICO', sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    
    print("🎨 [4/5] Deploying macOS AppIcon.appiconset...")
    appiconset_dir = "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    for s in sizes:
        resized = dock_icon.resize((s, s), Image.Resampling.LANCZOS)
        resized.save(os.path.join(appiconset_dir, f"app_icon_{s}.png"))
        
    print("🎨 [5/5] Compiling macOS .icns with iconutil...")
    iconset_dir = "/tmp/AppIcon.iconset"
    os.makedirs(iconset_dir, exist_ok=True)
    icon_map = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    for filename, s in icon_map.items():
        dock_icon.resize((s, s), Image.Resampling.LANCZOS).save(os.path.join(iconset_dir, filename))
        
    icns_path = "build/macos/Build/Products/Debug/Kazumi.app/Contents/Resources/AppIcon.icns"
    if os.path.exists(os.path.dirname(icns_path)):
        subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", icns_path], check=True)
        print("  -> Updated build .icns at", icns_path)
        
    print("✅ All pure nested-arrow icons deployed successfully!")

if __name__ == '__main__':
    deploy()
