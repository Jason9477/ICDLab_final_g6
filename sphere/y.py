import numpy as np
import matplotlib.pyplot as plt
import cv2


# =========================
# 讀影像（IMPORTANT：不要用 int8）
# =========================
im1 = cv2.imread("sphere_gray.0.png", cv2.IMREAD_GRAYSCALE).astype(np.int16)
im2 = cv2.imread("sphere_gray.2.png", cv2.IMREAD_GRAYSCALE).astype(np.int16)

H, W = im1.shape

# =========================
# window = 3
# stride = 3
# =========================
window_size = 5
w = window_size // 2
stride = 5

# =========================
# gradient buffers
# =========================
Ix = np.zeros((H, W), dtype=np.int16)
Iy = np.zeros((H, W), dtype=np.int16)
It = np.zeros((H, W), dtype=np.int16)

# =========================
# compute gradients
# =========================
for i in range(1, H-1):
    for j in range(1, W-1):
        Ix[i, j] = im1[i, j+1] - im1[i, j-1]
        Iy[i, j] = im1[i+1, j] - im1[i-1, j]
        It[i, j] = im2[i, j] - im1[i, j]

# =========================
# optical flow
# =========================
Vx = np.zeros((H, W), dtype=np.float32)
Vy = np.zeros((H, W), dtype=np.float32)

pp = 0

for i in range(w, H-w, stride):
    for j in range(w, W-w, stride):

        wx = Ix[i-w:i+w+1, j-w:j+w+1].flatten()
        wy = Iy[i-w:i+w+1, j-w:j+w+1].flatten()
        wt = It[i-w:i+w+1, j-w:j+w+1].flatten()

        A = np.vstack((wx, wy)).T.astype(np.float32)
        b = (-wt).reshape(-1, 1).astype(np.float32)

        pp += 1

        ATA = A.T @ A

        try:
            V = np.linalg.inv(ATA) @ (A.T @ b)*3

            Vx[i, j] = V[0, 0]
            Vy[i, j] = V[1, 0]

        except np.linalg.LinAlgError:
            Vx[i, j] = 0
            Vy[i, j] = 0

print("patch count:", pp)

# =========================
# visualization
# =========================
fig, axes = plt.subplots(1, 3, figsize=(18, 6))

axes[0].imshow(im1, cmap='gray')
axes[0].set_title("im1")
axes[0].axis('off')

axes[1].imshow(im2, cmap='gray')
axes[1].set_title("im2")
axes[1].axis('off')

axes[2].imshow(im1, cmap='gray', alpha=0.5)

ys = np.arange(w, H-w, stride)
xs = np.arange(w, W-w, stride)
X_grid, Y_grid = np.meshgrid(xs, ys)

Vx_sparse = Vx[w:H-w:stride, w:W-w:stride]
Vy_sparse = Vy[w:H-w:stride, w:W-w:stride]

axes[2].quiver(X_grid, Y_grid, Vx_sparse, Vy_sparse,
               color='red', angles='xy', scale_units='xy', scale=1)


axes[2].axis('off')

plt.tight_layout()
plt.show()
