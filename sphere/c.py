import cv2
import numpy as np

# 讀灰階 PNG
img = cv2.imread('s0.png', cv2.IMREAD_GRAYSCALE)

shift = 5  # pixel

H, W = img.shape

# 建立輸出（補 0）
out = np.zeros_like(img)

# 往右上移：
# row 往上 → -shift
# col 往右 → +shift
out[0:H-shift, shift:W] = img[shift:H, 0:W-shift]

# 存檔
cv2.imwrite('shift_right_up.png', out)
