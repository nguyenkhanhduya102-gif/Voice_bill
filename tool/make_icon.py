"""Dựng app icon từ ảnh logo nguồn:
- Tách phần đồ họa trắng (mic + hóa đơn) khỏi nền.
- Xuất icon vuông 1024 nền xanh thương hiệu (tràn mép) cho iOS/legacy/web.
- Xuất foreground trong suốt (đồ họa trắng, thu nhỏ) cho Android adaptive.
"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SRC = sys.argv[1]
OUT_DIR = "assets/icon"
BRAND = (46, 125, 50)  # #2E7D32
SIZE = 1024

img = Image.open(SRC).convert("RGB")
w, h = img.size

# 1) Xoá nền sáng quanh khối xanh: flood-fill từ 4 góc -> magenta (loại khỏi mask).
flood = img.copy()
for xy in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
    ImageDraw.floodfill(flood, xy, (255, 0, 255), thresh=60)

arr = np.asarray(flood)
r, g, b = arr[..., 0].astype(int), arr[..., 1].astype(int), arr[..., 2].astype(int)
# Mask đồ họa = pixel trắng (mọi kênh sáng & gần nhau). Nền đã thành magenta nên bị loại.
white = (r > 205) & (g > 205) & (b > 205) & (abs(r - g) < 25) & (abs(g - b) < 25)
mask = (white.astype(np.uint8)) * 255
mask_img = Image.fromarray(mask, "L")

# Bounding box của đồ họa để căn giữa.
bbox = mask_img.getbbox()
graphic = mask_img.crop(bbox)
gw, gh = graphic.size

# 2) Icon đầy đủ: nền xanh 1024, dán đồ họa trắng căn giữa (~78% khung).
def compose(canvas_bg, target_ratio, bg_color):
    scale = (SIZE * target_ratio) / max(gw, gh)
    nw, nh = int(gw * scale), int(gh * scale)
    gm = graphic.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), canvas_bg)
    white_layer = Image.new("RGBA", (nw, nh), (255, 255, 255, 255))
    ox, oy = (SIZE - nw) // 2, (SIZE - nh) // 2
    canvas.paste(white_layer, (ox, oy), gm)
    return canvas

# iOS/web: nền xanh đặc.
full = compose((BRAND[0], BRAND[1], BRAND[2], 255), 0.78, BRAND)
full.convert("RGB").save(f"{OUT_DIR}/app_icon.png")

# Android adaptive foreground: trong suốt, đồ họa nhỏ hơn (vùng an toàn ~66%).
fg = compose((0, 0, 0, 0), 0.62, None)
fg.save(f"{OUT_DIR}/app_icon_foreground.png")

print("OK: app_icon.png + app_icon_foreground.png, graphic bbox", bbox)
