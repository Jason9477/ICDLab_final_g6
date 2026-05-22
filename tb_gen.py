"""
Sliding Window Hex Extractor
============================
Input : 252 x 82 grayscale PNG
Window: 7x7  (1-pixel border around a 5x5 non-overlap core)
Stride: 5    (the 5x5 inner region is non-overlapping)
Output: hex string for every 7x7 patch → output.txt

Patch grid: 50 cols × 16 rows = 800 patches
"""

from pathlib import Path
import numpy as np
from PIL import Image

# ── 直接定義 input / output 路徑 ──────────────────────────────────────────────
INPUT_IMAGE  = Path("frame08.png")          # ← 改成你的圖片路徑
OUTPUT_FILE  = Path("b.txt")         # ← 改成你想要的輸出路徑
# ──────────────────────────────────────────────────────────────────────────────

WINDOW = 7    # 全窗口大小
CORE   = 5    # non-overlap 內核大小
STRIDE = 5    # 步長 = core（確保 5×5 不重疊）


def extract_patches(arr: np.ndarray) -> list[dict]:
    """以 stride=5 滑動 7×7 窗口，回傳所有 patch。"""
    h, w = arr.shape
    patches = []
    for row_idx, y in enumerate(range(0, h - WINDOW + 1, STRIDE)):
        for col_idx, x in enumerate(range(0, w - WINDOW + 1, STRIDE)):
            patches.append({
                "row"  : row_idx,
                "col"  : col_idx,
                "y_px" : y,
                "x_px" : x,
                "patch": arr[y : y + WINDOW, x : x + WINDOW].copy(),
            })
    return patches


def patch_to_hex(patch: np.ndarray) -> str:
    """7×7 uint8 array → 49-byte hex 字串（98 個字元）。"""
    return patch.flatten().tobytes().hex()


# ── 主流程 ────────────────────────────────────────────────────────────────────
img = Image.open(INPUT_IMAGE).convert("L")   # 強制轉灰階
arr = np.array(img, dtype=np.uint8)
h, w = arr.shape

print(f"Input       : {INPUT_IMAGE}  ({w}×{h})")

patches = extract_patches(arr)
n_cols  = (w - WINDOW) // STRIDE + 1
n_rows  = (h - WINDOW) // STRIDE + 1
print(f"Patch grid  : {n_cols} cols × {n_rows} rows = {len(patches)} patches")

lines = []
for p in patches:
    hex_str = patch_to_hex(p["patch"])
    # 每8位（2個hex字符）換一行
    for i in range(0, len(hex_str), 2):
        lines.append(hex_str[i:i+2])

OUTPUT_FILE.write_text("\n".join(lines), encoding="utf-8")
print(f"Output      : {OUTPUT_FILE}  ({len(lines)} lines)")
