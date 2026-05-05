import pandas as pd
import numpy as np

df = pd.read_excel('window_sums_all.xlsx')

Hx = df.iloc[:, 7].values
Hy = df.iloc[:, 8].values
Kx = df.iloc[:, 10].values
Ky = df.iloc[:, 11].values

dot = Hx*Kx + Hy*Ky
normH = np.sqrt(Hx**2 + Hy**2)
normK = np.sqrt(Kx**2 + Ky**2)

# --- angle ---
cos_theta = dot / (normH*normK + 1e-12)
cos_theta = np.clip(cos_theta, -1, 1)
angle = np.degrees(np.arccos(cos_theta))

# ✅ 0 vector mask（關鍵）
zero_mask = (normH < 1e-12) | (normK < 1e-12)
angle[zero_mask] = 0

# --- length diff ---
length_diff = normH - normK
length_diff_abs = np.abs(length_diff)

df['angle_deg'] = angle
df['length_diff'] = length_diff
df['length_diff_abs'] = length_diff_abs

df.to_excel('output.xlsx', index=False)
