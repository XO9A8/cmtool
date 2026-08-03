import os
import sys
from PIL import Image, ImageDraw, ImageOps

def create_gradient_image(width, height, color1, color2):
    base = Image.new('RGB', (width, height), color1)
    top = Image.new('RGB', (width, height), color2)
    mask = Image.new('L', (width, height))
    mask_data = []
    for y in range(height):
        for x in range(width):
            ratio = (x / width + y / height) / 2
            mask_data.append(int(255 * ratio))
    mask.putdata(mask_data)
    return Image.composite(top, base, mask)

def main():
    width, height = 512, 512
    color1 = (176, 0, 255) # #B000FF
    color2 = (0, 229, 255) # #00E5FF
    
    img = create_gradient_image(width, height, color1, color2)
    
    try:
        icon = Image.open('soccer_black.png').convert("RGBA")
        r, g, b, a = icon.split()
        white = Image.new("RGBA", icon.size, (255, 255, 255, 255))
        icon = Image.composite(white, Image.new("RGBA", icon.size, (0,0,0,0)), a)
        icon = icon.resize((300, 300), Image.Resampling.LANCZOS if hasattr(Image, 'Resampling') else Image.LANCZOS)
        
        offset = ((width - 300) // 2, (height - 300) // 2)
        img.paste(icon, offset, icon)
    except Exception as e:
        print("Could not process soccer icon:", e)
    
    if not os.path.exists('assets'):
        os.makedirs('assets')
        
    img.save('assets/icon.png')
    print("Saved assets/icon.png")

if __name__ == '__main__':
    main()
