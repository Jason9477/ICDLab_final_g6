import cv2
import os

# 【新增】將 width 和 height 加入參數，預設為 200
def extract_grayscale_frames(video_path, output_folder, target_seconds=3, width=200, height=200):
    # 如果儲存圖片的資料夾不存在，就自動建立一個
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    # 開啟影片檔案
    cap = cv2.VideoCapture(video_path)
    
    # 檢查影片是否成功讀取
    if not cap.isOpened():
        print(f"錯誤：無法打開影片 {video_path}，請檢查檔案是否存在！")
        return

    # 取得影片的 FPS (每秒影格數)
    fps = cap.get(cv2.CAP_PROP_FPS)
    
    # 計算指定秒數總共會有幾幀 (FPS * 秒數)
    max_frames = int(fps * target_seconds)

    print(f"影片 FPS 為: {fps}")
    # 【修改】讓輸出的文字也會根據你設定的參數自動改變
    print(f"預計擷取前 {target_seconds} 秒，總共將輸出 {max_frames} 幀 {width}x{height} 的圖片，請稍候...")

    frame_count = 1
    
    while True:
        # 如果目前的幀數已經超過我們計算出的最大幀數，就提早結束迴圈
        if frame_count > max_frames:
            break

        # 讀取每一幀
        ret, frame = cap.read()
        
        # 如果影片提早結束，跳出迴圈
        if not ret:
            break
            
        # 1. 將彩色圖片轉換為灰階
        gray_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        
        # 2. 【修改】使用參數 width 和 height 來進行縮放
        resized_frame = cv2.resize(gray_frame, (width, height))
        
        # 設定圖片檔名：使用 2 位數補零 (例如 frame01.png)
        filename = f"frame{frame_count:02d}.png"
        filepath = os.path.join(output_folder, filename)
        
        # 3. 儲存縮放後的圖片
        cv2.imwrite(filepath, resized_frame)
        
        frame_count += 1

    # 釋放資源
    cap.release()
    print(f"轉換完成！一共輸出了 {frame_count - 1} 幀 {width}x{height} 灰階圖片，存放於 '{output_folder}' 資料夾中。")

# ====================
# === 執行與設定區域 ===
# ====================
video_file = "highway_top_view.mp4" 
output_dir = "highway_top_view"

# 你現在可以直接在這裡修改所有參數！
# 例如：想要 300x300 的圖片，就直接改 width=300, height=300
extract_grayscale_frames(
    video_path=video_file, 
    output_folder=output_dir, 
    target_seconds=3, 
    width=600, 
    height=600
)