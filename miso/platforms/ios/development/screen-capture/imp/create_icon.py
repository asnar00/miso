#!/usr/bin/env python3
from PIL import Image
import os

# Load the original image
img = Image.open('iphone_icon.png')
orig_width, orig_height = img.size

# Icon sizes needed for macOS
sizes = [16, 32, 64, 128, 256, 512, 1024]

# Create iconset directory
os.makedirs('AppIcon.iconset', exist_ok=True)

for size in sizes:
    # Calculate the height that fits in the square while maintaining aspect ratio
    # Since the image is taller than it is wide, height will be the limiting dimension
    new_height = size
    new_width = int(size * orig_width / orig_height)

    # Resize the image maintaining aspect ratio
    resized = img.resize((new_width, new_height), Image.Resampling.LANCZOS)

    # Create a square transparent canvas
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))

    # Calculate position to center the image horizontally
    x_offset = (size - new_width) // 2
    y_offset = 0  # Top aligned, or could center vertically too

    # Paste the resized image onto the canvas
    canvas.paste(resized, (x_offset, y_offset))

    # Save the icon
    canvas.save(f'AppIcon.iconset/icon_{size}x{size}.png')

    # Create @2x versions for sizes up to 512
    if size <= 512:
        double = size * 2
        new_height_2x = double
        new_width_2x = int(double * orig_width / orig_height)

        resized_2x = img.resize((new_width_2x, new_height_2x), Image.Resampling.LANCZOS)
        canvas_2x = Image.new('RGBA', (double, double), (0, 0, 0, 0))
        x_offset_2x = (double - new_width_2x) // 2
        canvas_2x.paste(resized_2x, (x_offset_2x, 0))
        canvas_2x.save(f'AppIcon.iconset/icon_{size}x{size}@2x.png')

print('Created icon files with preserved aspect ratio')
