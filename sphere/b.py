import numpy as np
import cv2

# 讀灰階影像
img = cv2.imread('s0.png', cv2.IMREAD_GRAYSCALE)

# 往右下移 2 pixel（循環）
shift_y = 2  # 往下
shift_x = 2  # 往右

out = np.roll(img, shift=(shift_y, shift_x), axis=(0, 1))

# 存圖
cv2.imwrite('s0_s.png', out)
