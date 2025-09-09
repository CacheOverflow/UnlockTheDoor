#!/usr/bin/env python3
import os
import subprocess

# Define the base directories
project_root = "/Users/tirzumandaniel/dev/git/github/repositories/UnlockTheDoor"
svg_file = os.path.join(project_root, "watch_app_icon.svg")
watch_icon_dir = os.path.join(project_root, "UnlockTheDoor Watch App Watch App/Assets.xcassets/AppIcon.appiconset")
iphone_icon_dir = os.path.join(project_root, "UnlockTheDoor/Assets.xcassets/AppIcon.appiconset")

# Watch app icon sizes (name: size in pixels)
watch_sizes = {
    "icon-24@2x.png": 48,
    "icon-27.5@2x.png": 55,
    "icon-29@2x.png": 58,
    "icon-29@3x.png": 87,
    "icon-33@2x.png": 66,
    "icon-40@2x.png": 80,
    "icon-44@2x.png": 88,
    "icon-46@2x.png": 92,
    "icon-50@2x.png": 100,
    "icon-51@2x.png": 102,
    "icon-54@2x.png": 108,
    "icon-86@2x.png": 172,
    "icon-98@2x.png": 196,
    "icon-108@2x.png": 216,
    "icon-117@2x.png": 234,
    "icon-129@2x.png": 258,
    "icon-1024.png": 1024
}

# iPhone app icon sizes
iphone_sizes = {
    "icon-20@2x.png": 40,
    "icon-20@3x.png": 60,
    "icon-29@2x.png": 58,
    "icon-29@3x.png": 87,
    "icon-40@2x.png": 80,
    "icon-40@3x.png": 120,
    "icon-60@2x.png": 120,
    "icon-60@3x.png": 180,
    "icon-1024.png": 1024
}

def generate_icon(output_path, size):
    """Generate a PNG icon from the SVG at the specified size."""
    cmd = [
        "rsvg-convert",
        "-w", str(size),
        "-h", str(size),
        svg_file,
        "-o", output_path
    ]
    try:
        subprocess.run(cmd, check=True, capture_output=True)
        print(f"✅ Generated {os.path.basename(output_path)} ({size}x{size})")
    except subprocess.CalledProcessError as e:
        # Fallback to sips if rsvg-convert is not available
        temp_png = "/tmp/temp_icon.png"
        # First convert SVG to PNG at 1024x1024
        subprocess.run(["qlmanage", "-t", "-s", "1024", "-o", "/tmp", svg_file], 
                      capture_output=True, stderr=subprocess.DEVNULL)
        svg_preview = svg_file.replace('.svg', '.svg.png')
        if os.path.exists(svg_preview):
            os.rename(svg_preview, temp_png)
        elif os.path.exists("/tmp/watch_app_icon.svg.png"):
            os.rename("/tmp/watch_app_icon.svg.png", temp_png)
        
        # Then resize to target size
        subprocess.run(["sips", "-z", str(size), str(size), temp_png, "--out", output_path],
                      check=True, capture_output=True)
        print(f"✅ Generated {os.path.basename(output_path)} ({size}x{size}) using sips")

print("🎨 Generating Watch App Icons...")
for filename, size in watch_sizes.items():
    output_path = os.path.join(watch_icon_dir, filename)
    generate_icon(output_path, size)

print("\n🎨 Generating iPhone App Icons...")
os.makedirs(iphone_icon_dir, exist_ok=True)
for filename, size in iphone_sizes.items():
    output_path = os.path.join(iphone_icon_dir, filename)
    generate_icon(output_path, size)

print("\n✅ All icons generated successfully!")