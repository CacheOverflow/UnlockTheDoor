#!/usr/bin/env python3
"""
Remove alpha channel from all app icons to meet Apple's requirements
"""

from PIL import Image
import os
import glob

def remove_alpha_channel(image_path):
    """Remove alpha channel from an image and save it with the same name"""
    try:
        # Open the image
        img = Image.open(image_path)
        
        # Convert RGBA to RGB (removes alpha channel)
        if img.mode in ('RGBA', 'LA', 'P'):
            # Create a white background
            background = Image.new('RGB', img.size, (255, 255, 255))
            
            # Paste the image on the white background
            if img.mode == 'P':
                img = img.convert('RGBA')
            
            if img.mode == 'RGBA':
                background.paste(img, mask=img.split()[3])  # Use alpha channel as mask
            else:
                background.paste(img)
            
            # Save the image without alpha channel
            background.save(image_path, 'PNG', quality=100)
            print(f"✅ Fixed: {os.path.basename(image_path)}")
            return True
        elif img.mode == 'RGB':
            print(f"⏭️  Skipped (no alpha): {os.path.basename(image_path)}")
            return False
        else:
            print(f"⚠️  Unknown mode {img.mode}: {os.path.basename(image_path)}")
            return False
            
    except Exception as e:
        print(f"❌ Error processing {image_path}: {e}")
        return False

def main():
    """Process all app icons in the project"""
    
    # Define icon locations
    icon_paths = [
        # iOS App icons
        "UnlockTheDoor/Assets.xcassets/AppIcon.appiconset/*.png",
        
        # Watch App icons  
        "UnlockTheDoor Watch App Watch App/Assets.xcassets/AppIcon.appiconset/*.png",
    ]
    
    total_processed = 0
    total_fixed = 0
    
    print("🔧 Removing alpha channel from app icons...\n")
    
    for pattern in icon_paths:
        print(f"\n📁 Processing: {pattern}")
        icons = glob.glob(pattern)
        
        if not icons:
            print(f"   No icons found")
            continue
            
        for icon_path in icons:
            total_processed += 1
            if remove_alpha_channel(icon_path):
                total_fixed += 1
    
    print(f"\n✨ Complete! Processed {total_processed} icons, fixed {total_fixed} with alpha channel")
    print("\n📝 Next steps:")
    print("1. Clean Build Folder: Product → Clean Build Folder (Shift+Cmd+K)")
    print("2. Archive again: Product → Archive")
    print("3. Validate the archive")

if __name__ == "__main__":
    main()