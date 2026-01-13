#!/bin/bash

SOURCE="android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
DEST="ios/Runner/Assets.xcassets/AppIcon.appiconset"

# Ensure destination exists
mkdir -p "$DEST"

# Function to resize
resize_icon() {
    SIZE=$1
    NAME=$2
    sips -z $SIZE $SIZE "$SOURCE" --out "$DEST/$NAME" > /dev/null
}

echo "Generating iOS icons from $SOURCE..."

# 1024x1024 (Marketing) - Upscaling 192px to 1024px is bad practice but requested
resize_icon 1024 "Icon-App-1024x1024@1x.png"

# 20pt
resize_icon 20 "Icon-App-20x20@1x.png"
resize_icon 40 "Icon-App-20x20@2x.png"
resize_icon 60 "Icon-App-20x20@3x.png"

# 29pt
resize_icon 29 "Icon-App-29x29@1x.png"
resize_icon 58 "Icon-App-29x29@2x.png"
resize_icon 87 "Icon-App-29x29@3x.png"

# 40pt
resize_icon 40 "Icon-App-40x40@1x.png"
resize_icon 80 "Icon-App-40x40@2x.png"
resize_icon 120 "Icon-App-40x40@3x.png"

# 60pt
resize_icon 120 "Icon-App-60x60@2x.png"
resize_icon 180 "Icon-App-60x60@3x.png"

# 76pt
resize_icon 76 "Icon-App-76x76@1x.png"
resize_icon 152 "Icon-App-76x76@2x.png"

# 83.5pt
resize_icon 167 "Icon-App-83.5x83.5@2x.png"

echo "Done generating icons!"
