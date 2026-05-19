clc; clear; close all;

% =========================
% 1. 路徑與參數設定
% =========================
base_name  = 'soccer';  % <--- 對應到你的圖片資料夾名稱
input_dir  = base_name;
output_dir = sprintf('output_flow_png/%s_flow_png/', base_name);
csv_dir    = sprintf('output_csv_data/%s_csv_data/', base_name);
if ~exist(output_dir, 'dir'), mkdir(output_dir); end
if ~exist(csv_dir,    'dir'), mkdir(csv_dir);    end

start_frame = 1;
end_frame   = 30;

% ★ 新增功能參數
num_levels   = 3;       % 金字塔層數 (1=無金字塔, 3=降階兩次)
block_size_n = 64;      % 最後繪圖聚合的 n*n 區塊大小

% ★ LK Window 參數
window_size = 7;
w           = floor(window_size / 2);  % w = 3
core_size   = 5;
stride      = 5;
mul         = 100.0/(block_size_n*block_size_n);       % 畫圖用的向量放大倍率 (依照要求，不作任何變動)
threshold   = 1e6;      % Harris Corner 閥值
k           = 0.06;     % Harris 參數

% =========================
% ★ 模式開關：'hw' 或 'sw'
% =========================
MODE = 'sw';

% =========================
% 2. 連續處理迴圈
% =========================
for f_idx = start_frame : (end_frame - 1)

    file1 = fullfile(input_dir, sprintf('frame%02d.png', f_idx));
    file2 = fullfile(input_dir, sprintf('frame%02d.png', f_idx + 1));
    if ~exist(file1, 'file') || ~exist(file2, 'file'), continue; end

    im1_raw = double(imread(file1));
    im2_raw = double(imread(file2));
    [H_orig, W_orig] = size(im1_raw);
    
    % --- 建立影像金字塔 ---
    pyr1 = cell(num_levels, 1);
    pyr2 = cell(num_levels, 1);
    pyr1{1} = im1_raw;
    pyr2{1} = im2_raw;
    for lvl = 2:num_levels
        pyr1{lvl} = imresize(pyr1{lvl-1}, 0.5, 'bilinear');
        pyr2{lvl} = imresize(pyr2{lvl-1}, 0.5, 'bilinear');
    end
    
    % 於頂層 (最小尺寸) 初始化 Dense Vector Field
    [H_top, W_top] = size(pyr1{num_levels});
    Vx_dense = zeros(H_top, W_top);
    Vy_dense = zeros(H_top, W_top);

    % =========================
    % 3. 由粗到細 (Coarse-to-Fine) 疊代
    % =========================
    for lvl = num_levels:-1:1
        im1 = pyr1{lvl};
        im2 = pyr2{lvl};
        [H, W] = size(im1);
        
        % 若非最頂層，將上一層的光流場放大兩倍並對齊當前解析度
        if lvl < num_levels
            Vx_dense = imresize(Vx_dense, [H, W], 'bilinear') * 2;
            Vy_dense = imresize(Vy_dense, [H, W], 'bilinear') * 2;
        end
        
        % --- Image Warping (影像扭曲) ---
        [X_img, Y_img] = meshgrid(1:W, 1:H);
        im2_warp = interp2(X_img, Y_img, im2, X_img + Vx_dense, Y_img + Vy_dense, 'bilinear', NaN);
        
        % 處理邊界產生的 NaN (直接補回 im1 的值)
        nan_mask = isnan(im2_warp);
        im2_warp(nan_mask) = im1(nan_mask);

        % --- 計算空間與時間梯度 ---
        Ix = zeros(H, W); Iy = zeros(H, W); It = zeros(H, W);
        Ix(2:H-1, 2:W-1) = im1(2:H-1, 3:W)   - im1(2:H-1, 1:W-2);
        Iy(2:H-1, 2:W-1) = im1(3:H,   2:W-1) - im1(1:H-2, 2:W-1);
        It(2:H-1, 2:W-1) = (im2_warp(2:H-1, 2:W-1) - im1(2:H-1, 2:W-1)) / 2;

        ys_range = (1+w):stride:(H-w);
        xs_range = (1+w):stride:(W-w);
        n_gy = length(ys_range);
        n_gx = length(xs_range);
        
        % 儲存當前層級的殘差光流 (Residual Flow)
        dVx_grid = zeros(n_gy, n_gx);
        dVy_grid = zeros(n_gy, n_gx);

        % =========================
        % SW 模式
        % =========================
        if strcmp(MODE, 'sw')
            if lvl == 1
                num_windows = n_gy * n_gx;
                data_matrix = zeros(num_windows, 23);
                row_cnt = 0;
            end

            for idx_y = 1:n_gy
                for idx_x = 1:n_gx
                    i = ys_range(idx_y); 
                    j = xs_range(idx_x);
                    
                    patch_Ix = Ix(i-w:i+w, j-w:j+w);
                    patch_Iy = Iy(i-w:i+w, j-w:j+w);
                    patch_It = It(i-w:i+w, j-w:j+w);

                    wx = reshape(patch_Ix(2:6, 2:6), [], 1);
                    wy = reshape(patch_Iy(2:6, 2:6), [], 1);
                    wt = reshape(patch_It(2:6, 2:6), [], 1);

                    raw_Ix2  = sum(wx.*wx);
                    raw_Iy2  = sum(wy.*wy);
                    raw_IxIy = sum(wx.*wy);
                    raw_IxIt = sum(wx.*wt);
                    raw_IyIt = sum(wy.*wt);

                    raw_detA = (raw_Ix2 * raw_Iy2) - (raw_IxIy^2);
                    raw_Ux   = -(raw_Iy2 * raw_IxIt) + (raw_IxIy * raw_IyIt);
                    raw_Uy   = -(raw_Ix2 * raw_IyIt) + (raw_IxIy * raw_IxIt);

                    raw_detH  = raw_Ix2 * raw_Iy2 - raw_IxIy^2;
                    raw_trace = raw_Ix2 + raw_Iy2;
                    R         = raw_detH - k * (raw_trace^2);

                    vx_actual = 0; vy_actual = 0;
                    vx_final  = 0; vy_final  = 0;

                    if R > threshold && raw_detA > 0
                        vx_actual = raw_Ux / raw_detA;
                        vy_actual = raw_Uy / raw_detA;

                        if abs(vx_actual) < 3 && abs(vy_actual) < 3
                            dVx_grid(idx_y, idx_x) = vx_actual;
                            dVy_grid(idx_y, idx_x) = vy_actual;
                        else
                            vx_actual = 0; vy_actual = 0;
                        end
                        vx_final = vx_actual;
                        vy_final = vy_actual;
                    end

                    if lvl == 1
                        row_cnt = row_cnt + 1;
                        data_matrix(row_cnt, :) = [i, j, raw_Ix2, raw_Iy2, raw_IxIy, raw_IxIt, raw_IyIt, ...
                                                   0, 0, 0, 0, 0, 0, R, raw_detA, raw_Ux, raw_Uy, ...
                                                   0, 0, vx_final, vy_final, vx_actual, vy_actual];
                    end
                end
            end
            
            if lvl == 1
                col_names = {'Row_Idx','Col_Idx','raw_Ix2','raw_Iy2','raw_IxIy','raw_IxIt','raw_IyIt', ...
                             'shift_amt','Ix2_s','Iy2_s','IxIy_s','IxIt_s','IyIt_s', ...
                             'Harris_R','detA_s','Ux_s','Uy_s','vx_fixed','vy_fixed', ...
                             'Vx_phys','Vy_phys','vx_actual','vy_actual'};
                T = array2table(data_matrix, 'VariableNames', col_names);
                csv_path = fullfile(csv_dir, sprintf('%s_data_frame_%02d.csv', MODE, f_idx));
                writetable(T, csv_path);
            end

        % =========================
        % HW 模式
        % =========================
        else
            dVx_sum   = zeros(n_gy, n_gx);
            dVy_sum   = zeros(n_gy, n_gx);
            dVx_count = zeros(n_gy, n_gx);

            for i = (1+w):(H-w)
                [~, gi] = min(abs(ys_range - i));
                for j = (1+w):(W-w)
                    [~, gj] = min(abs(xs_range - j));

                    patch_Ix = Ix(i-w:i+w, j-w:j+w);
                    patch_Iy = Iy(i-w:i+w, j-w:j+w);
                    patch_It = It(i-w:i+w, j-w:j+w);

                    wx = reshape(patch_Ix(2:6, 2:6), [], 1);
                    wy = reshape(patch_Iy(2:6, 2:6), [], 1);
                    wt = reshape(patch_It(2:6, 2:6), [], 1);

                    raw_Ix2  = sum(wx.*wx);
                    raw_Iy2  = sum(wy.*wy);
                    raw_IxIy = sum(wx.*wy);
                    raw_IxIt = sum(wx.*wt);
                    raw_IyIt = sum(wy.*wt);

                    raw_detA = (raw_Ix2 * raw_Iy2) - (raw_IxIy^2);

                    max_abs_val = max(abs([raw_Ix2, raw_Iy2, raw_IxIy, raw_IxIt, raw_IyIt]));
                    bit_len = 0;
                    if max_abs_val > 0, bit_len = ceil(log2(max_abs_val)); end
                    shift_amt = max(0, bit_len - 15);

                    Ix2_s  = floor(raw_Ix2  / (2^shift_amt));
                    Iy2_s  = floor(raw_Iy2  / (2^shift_amt));
                    IxIy_s = floor(raw_IxIy / (2^shift_amt));
                    IxIt_s = floor(raw_IxIt / (2^shift_amt));
                    IyIt_s = floor(raw_IyIt / (2^shift_amt));

                    detH   = Ix2_s * Iy2_s - IxIy_s^2;
                    traceH = Ix2_s + Iy2_s;
                    R      = double(detH) - double((int64(traceH)*int64(traceH)) * k);
                    detA_s = detH;

                    if R <= threshold
                        continue; 
                    end

                    if detA_s <= 0 || raw_detA <= 0
                        continue;
                    end

                    Ux_s = -(Iy2_s * IxIt_s) + (IxIy_s * IyIt_s);
                    Uy_s = -(Ix2_s * IyIt_s) + (IxIy_s * IxIt_s);

                    k_div       = floor(log2(double(detA_s)));
                    final_shift = k_div - 8;
                    if final_shift >= 0
                        vx_f = floor(Ux_s / (2^final_shift));
                        vy_f = floor(Uy_s / (2^final_shift));
                    else
                        vx_f = floor(Ux_s * (2^abs(final_shift)));
                        vy_f = floor(Uy_s * (2^abs(final_shift)));
                    end
                    vx_f = max(min(vx_f, 2047), -2048);
                    vy_f = max(min(vy_f, 2047), -2048);

                    vx_final = vx_f / 256;
                    vy_final = vy_f / 256;

                    if abs(vx_final) >= 3 || abs(vy_final) >= 3
                        continue;
                    end

                    dVx_sum(gi, gj)   = dVx_sum(gi, gj)   + vx_final;
                    dVy_sum(gi, gj)   = dVy_sum(gi, gj)   + vy_final;
                    dVx_count(gi, gj) = dVx_count(gi, gj) + 1;
                end
            end

            valid  = dVx_count > 0;
            dVx_grid(valid) = dVx_sum(valid) ./ dVx_count(valid);
            dVy_grid(valid) = dVy_sum(valid) ./ dVx_count(valid);
        end
        
        % --- 聚合與補展回 Dense Flow ---
        dVx_dense = imresize(dVx_grid, [H, W], 'bilinear');
        dVy_dense = imresize(dVy_grid, [H, W], 'bilinear');
        
        Vx_dense = Vx_dense + dVx_dense;
        Vy_dense = Vy_dense + dVy_dense;
        
    end % 金字塔迴圈結束

    % =========================
    % 4. 區塊聚合 (Block Aggregation - Summation) 與繪圖
    % =========================
    num_blocks_y = floor(H_orig / block_size_n);
    num_blocks_x = floor(W_orig / block_size_n);

    Vx_block = zeros(num_blocks_y, num_blocks_x);
    Vy_block = zeros(num_blocks_y, num_blocks_x);
    X_block  = zeros(num_blocks_y, num_blocks_x);
    Y_block  = zeros(num_blocks_y, num_blocks_x);

    for by = 1:num_blocks_y
        for bx = 1:num_blocks_x
            y_start = (by - 1) * block_size_n + 1;
            y_end   = by * block_size_n;
            x_start = (bx - 1) * block_size_n + 1;
            x_end   = bx * block_size_n;

            patch_Vx = Vx_dense(y_start:y_end, x_start:x_end);
            patch_Vy = Vy_dense(y_start:y_end, x_start:x_end);

            % ★ 改為純粹加總 (Sum)
            Vx_block(by, bx) = sum(patch_Vx(:));
            Vy_block(by, bx) = sum(patch_Vy(:));

            % 記錄中心點用於繪製箭頭
            X_block(by, bx) = x_start + block_size_n / 2;
            Y_block(by, bx) = y_start + block_size_n / 2;
        end
    end

    % 依照要求，mul 參數不變動，直接相乘
    Vx_out = Vx_block * mul;
    Vy_out = Vy_block * mul;
    
    % 繪圖
    fig = figure('Visible', 'off');
    imshow(im1_raw, []); hold on;
    quiver(X_block, Y_block, Vx_out, Vy_out, 0, 'r', 'LineWidth', 1.2);
    
    title(sprintf('Optical Flow [%s] (Pyr: %d, Block: %dx%d, Sum)', MODE, num_levels, block_size_n, block_size_n));
    save_path = fullfile(output_dir, sprintf('%s_flow_pyr_%02d.png', MODE, f_idx));
    print(fig, save_path, '-dpng', '-r150');
    close(fig);

    fprintf('[%s] Frame %02d done (Block Aggregation Sum: %dx%d)\n', MODE, f_idx, block_size_n, block_size_n);
end
fprintf('--- 全部處理完成 [MODE = %s, Pyramid Levels = %d] ---\n', MODE, num_levels);