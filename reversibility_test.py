import numpy as np
from PIL import Image
import os

def apply_custom_effect(img_np):
    # img_np: (H, W, 3) or (H, W, 4)
    h, w = img_np.shape[:2]
    dst = np.zeros_like(img_np)
    
    # R: 255 - src(x, h-1-y).r
    # G: 255 - src(x, y).g
    # B: 255 - src(w-1-x, y).b
    
    # R channel
    r_src = img_np[:, :, 0]
    dst[:, :, 0] = 255 - np.flipud(r_src)
    
    # G channel
    g_src = img_np[:, :, 1]
    dst[:, :, 1] = 255 - g_src
    
    # B channel
    b_src = img_np[:, :, 2]
    dst[:, :, 2] = 255 - np.fliplr(b_src)
    
    if img_np.shape[2] == 4:
        dst[:, :, 3] = img_np[:, :, 3] # Alpha remains
        
    return dst

def test_reversibility(image_path, format='PNG'):
    print(f"Testing reversibility for {image_path} with format {format}...")
    original = Image.open(image_path).convert('RGB')
    orig_np = np.array(original)
    
    # 1st processing
    processed1_np = apply_custom_effect(orig_np)
    processed1 = Image.fromarray(processed1_np)
    temp1 = f"temp1.{format.lower()}"
    processed1.save(temp1, format=format, quality=100 if format=='JPEG' else None)
    
    # Reload and 2nd processing
    reloaded1 = Image.open(temp1).convert('RGB')
    reloaded1_np = np.array(reloaded1)
    processed2_np = apply_custom_effect(reloaded1_np)
    processed2 = Image.fromarray(processed2_np)
    temp2 = f"temp2.{format.lower()}"
    processed2.save(temp2, format=format, quality=100 if format=='JPEG' else None)
    
    # Final check
    final = Image.open(temp2).convert('RGB')
    final_np = np.array(final)
    
    diff = np.abs(orig_np.astype(int) - final_np.astype(int))
    max_diff = np.max(diff)
    mean_diff = np.mean(diff)
    
    print(f"  Max pixel difference: {max_diff}")
    print(f"  Mean pixel difference: {mean_diff:.4f}")
    
    if max_diff == 0:
        print("  SUCCESS: Perfectly reversible!")
        return True
    else:
        print("  FAILURE: Not perfectly reversible.")
        return False

# Create a sample image
sample_path = "sample.png"
sample_img = np.random.randint(0, 256, (100, 100, 3), dtype=np.uint8)
Image.fromarray(sample_img).save(sample_path)

# Test PNG
png_result = test_reversibility(sample_path, 'PNG')

# Test JPEG for comparison
jpg_result = test_reversibility(sample_path, 'JPEG')

if png_result and not jpg_result:
    print("\nConclusion: PNG is perfectly reversible, while JPEG is not (even at quality 100).")
    print("This confirms that forcing PNG is the correct fix for the reversibility issue.")
elif png_result:
    print("\nConclusion: PNG is perfectly reversible.")
