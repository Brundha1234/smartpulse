import os
from PIL import Image, ImageDraw

def create_app_icon():
    # Create a 1024x1024 image with transparent background
    size = 1024
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw background circle (dark blue)
    circle_bbox = [(40, 40), (size-40, size-40)]
    draw.ellipse(circle_bbox, fill=(30, 58, 138, 255))  # #1E3A8A
    
    # Draw heart shape (blue)
    heart_color = (59, 130, 246, 255)  # #3B82F6
    heart_outline = (96, 165, 250, 255)  # #60A5FA
    
    # Heart path coordinates (simplified)
    heart_points = [
        (512, 768),  # Bottom point
        (256, 640),  # Left bottom
        (128, 480),  # Left middle
        (128, 320),  # Left top
        (192, 224),  # Left curve
        (320, 128),  # Left top curve
        (384, 160),  # Left middle
        (512, 224),  # Center
        (640, 160),  # Right middle
        (704, 128),  # Right top curve
        (832, 224),  # Right curve
        (896, 320),  # Right top
        (896, 480),  # Right middle
        (768, 640),  # Right bottom
        (512, 768),  # Bottom point (close)
    ]
    
    # Draw filled heart
    draw.polygon(heart_points, fill=heart_color)
    
    # Draw heart outline
    draw.polygon(heart_points, outline=heart_outline, width=8)
    
    # Draw ECG pulse line (white)
    pulse_color = (255, 255, 255, 255)
    pulse_width = 12
    
    # ECG wave points
    pulse_points = [
        (200, 512),
        (300, 512),
        (350, 462),
        (400, 562),
        (450, 362),
        (500, 662),
        (550, 462),
        (600, 512),
        (824, 512)
    ]
    
    # Draw pulse line
    for i in range(len(pulse_points) - 1):
        draw.line([pulse_points[i], pulse_points[i+1]], fill=pulse_color, width=pulse_width)
    
    # Draw pulse dots
    dot_size = 16
    draw.ellipse([200-dot_size//2, 512-dot_size//2, 200+dot_size//2, 512+dot_size//2], fill=pulse_color)
    draw.ellipse([824-dot_size//2, 512-dot_size//2, 824+dot_size//2, 512+dot_size//2], fill=pulse_color)
    
    # Add heart highlight
    highlight_color = (96, 165, 250, 77)  # #60A5FA with 30% opacity
    draw.ellipse([320, 200, 440, 360], fill=highlight_color)
    
    return img

# Create and save the icon
icon = create_app_icon()
icon_path = "assets/images/app_icon.png"
icon.save(icon_path, "PNG")
print(f"App icon saved to {icon_path}")

# Also create a smaller version for testing
small_icon = icon.resize((192, 192), Image.Resampling.LANCZOS)
small_icon.save("assets/images/app_icon_small.png", "PNG")
print("Small icon saved to assets/images/app_icon_small.png")
