#!/bin/bash

# Create directories if they don't exist
mkdir -p UnlockTheDoor/Assets.xcassets/AppIcon.appiconset
mkdir -p "UnlockTheDoor Watch App Watch App/Assets.xcassets/AppIcon.appiconset"

# iOS App Icon Sizes
echo "Generating iOS app icons..."

# iPhone icons
sips -s format png -z 40 40 unlock-door-icon.svg --out UnlockTheDoor/Assets.xcassets/AppIcon.appiconset/icon-20@2x.png
sips -s format png -z 60 60 unlock-door-icon.svg --out UnlockTheDoor/Assets.xcassets/AppIcon.appiconset/icon-20@3x.png
sips -s format png -z 58 58 unlock-door-icon.svg --out UnlockTheDoor/Assets.xcassets/AppIcon.appiconset/icon-29@2x.png
sips -s format png -z 87 87 unlock-door-icon.svg --out UnlockTheDoor/Assets.xcassets/AppIcon.appiconset/icon-29@3x.png
sips -s format png -z 80 80 unlock-door-icon.svg --out UnlockTheDoor/Assets.xcassets/AppIcon.appiconset/icon-40@2x.png
sips -s format png -z 120 120 unlock-door-icon.svg --out UnlockTheDoor/Assets.xcassets/AppIcon.appiconset/icon-40@3x.png
sips -s format png -z 120 120 unlock-door-icon.svg --out UnlockTheDoor/Assets.xcassets/AppIcon.appiconset/icon-60@2x.png
sips -s format png -z 180 180 unlock-door-icon.svg --out UnlockTheDoor/Assets.xcassets/AppIcon.appiconset/icon-60@3x.png
sips -s format png -z 1024 1024 unlock-door-icon.svg --out UnlockTheDoor/Assets.xcassets/AppIcon.appiconset/icon-1024.png

# Watch App Icon Sizes
echo "Generating Watch app icons..."

# Watch icons - note the space in the path
WATCH_PATH="UnlockTheDoor Watch App Watch App/Assets.xcassets/AppIcon.appiconset"

sips -s format png -z 48 48 unlock-door-icon.svg --out "$WATCH_PATH/icon-24@2x.png"
sips -s format png -z 55 55 unlock-door-icon.svg --out "$WATCH_PATH/icon-27.5@2x.png"
sips -s format png -z 58 58 unlock-door-icon.svg --out "$WATCH_PATH/icon-29@2x.png"
sips -s format png -z 87 87 unlock-door-icon.svg --out "$WATCH_PATH/icon-29@3x.png"
sips -s format png -z 66 66 unlock-door-icon.svg --out "$WATCH_PATH/icon-33@2x.png"
sips -s format png -z 80 80 unlock-door-icon.svg --out "$WATCH_PATH/icon-40@2x.png"
sips -s format png -z 88 88 unlock-door-icon.svg --out "$WATCH_PATH/icon-44@2x.png"
sips -s format png -z 92 92 unlock-door-icon.svg --out "$WATCH_PATH/icon-46@2x.png"
sips -s format png -z 100 100 unlock-door-icon.svg --out "$WATCH_PATH/icon-50@2x.png"
sips -s format png -z 102 102 unlock-door-icon.svg --out "$WATCH_PATH/icon-51@2x.png"
sips -s format png -z 108 108 unlock-door-icon.svg --out "$WATCH_PATH/icon-54@2x.png"
sips -s format png -z 172 172 unlock-door-icon.svg --out "$WATCH_PATH/icon-86@2x.png"
sips -s format png -z 196 196 unlock-door-icon.svg --out "$WATCH_PATH/icon-98@2x.png"
sips -s format png -z 216 216 unlock-door-icon.svg --out "$WATCH_PATH/icon-108@2x.png"
sips -s format png -z 234 234 unlock-door-icon.svg --out "$WATCH_PATH/icon-117@2x.png"
sips -s format png -z 1024 1024 unlock-door-icon.svg --out "$WATCH_PATH/icon-1024.png"

echo "Icon generation complete!"