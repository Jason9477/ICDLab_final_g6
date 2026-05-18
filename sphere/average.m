clc; clear; close all;

% =========================
% 1. 路徑與參數設定
% =========================
input_dir  = 'test/compressed/Minicooper';
output_dir = 'output_flow_png/Minicooper';
csv_dir    = 'output_csv_data/';
if ~exist(output_dir, 'dir'), mkdir(output_dir); end
if ~exist(csv_dir,    'dir'), mkdir(csv_dir);    end

start_frame = 0;
end_frame   = 75;

window_size = 7;
w           = floor(window_size / 2);  % w = 3
core_size   = 5;
stride      = 5;
mul         = 8  ;
threshold   = 2e6;
k           = 0.061;

% =========================
% ★ 模式開關：'hw' 或 'sw'
% =========================
MODE = 'hw';

% =========================
% 2. 連續處理迴圈
% =========================
for f_idx = start_frame : (end_frame - 1)

    file1 = fullfile(input_dir, sprintf('frame%02d.png', f_idx));
    file2 = fullfile(input_dir, sprintf('frame%02d.png', f_idx + 1));
    if ~exist(file1, 'file') || ~exist(file2, 'file'), continue; end

    im1 = double(imread(file1));
    im2 = double(imread(file2));
    [H, W] = size(im1);

    % --- 梯度（向量化）---
    Ix = zeros(H, W); Iy = zeros(H, W); It = zeros(H, W);
    Ix(2:H-1, 2:W-1) = im1(2:H-1, 3:W)   - im1(2:H-1, 1:W-2);
    Iy(2:H-1, 2:W-1) = im1(3:H,   2:W-1) - im1(1:H-2, 2:W-1);
    It(2:H-1, 2:W-1) = (im2(2:H-1, 2:W-1) - im1(2:H-1, 2:W-1)) ;

    % grid：stride=5，從 (1+w) 開始確保 patch 不超邊界
    ys_range = (1+w):stride:(H-w);
    xs_range = (1+w):stride:(W-w);
    n_gy = length(ys_range);
    n_gx = length(xs_range);

    % =========================
    % sw 模式
    % =========================
    if strcmp(MODE, 'sw')

        Vx = zeros(H, W); Vy = zeros(H, W);
        num_windows = n_gy * n_gx;
        data_matrix = zeros(num_windows, 23);
        row_cnt = 0;

        for i = ys_range
            for j = xs_range
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
                R         = raw_detH - 0.01 * (raw_trace^2);

                vx_actual = 0; vy_actual = 0;
                vx_final  = 0; vy_final  = 0;

                if R > threshold && raw_detA > 0
                    vx_actual = raw_Ux / raw_detA;
                    vy_actual = raw_Uy / raw_detA;

                    if abs(vx_actual) < 3 || abs(vy_actual) < 3
                        Vx(i,j) = vx_actual * mul;
                        Vy(i,j) = vy_actual * mul;
                    else
                        Vx(i,j) = 0; Vy(i,j) = 0;
                        vx_actual = 0; vy_actual = 0;
                    end
                    vx_final = vx_actual;
                    vy_final = vy_actual;
                end

                row_cnt = row_cnt + 1;
                data_matrix(row_cnt, :) = [i, j, raw_Ix2, raw_Iy2, raw_IxIy, raw_IxIt, raw_IyIt, ...
                                           0, 0, 0, 0, 0, 0, R, raw_detA, raw_Ux, raw_Uy, ...
                                           0, 0, vx_final, vy_final, vx_actual, vy_actual];
            end
        end

        % 儲存 CSV
        col_names = {'Row_Idx','Col_Idx','raw_Ix2','raw_Iy2','raw_IxIy','raw_IxIt','raw_IyIt', ...
                     'shift_amt','Ix2_s','Iy2_s','IxIy_s','IxIt_s','IyIt_s', ...
                     'Harris_R','detA_s','Ux_s','Uy_s','vx_fixed','vy_fixed', ...
                     'Vx_phys','Vy_phys','vx_actual','vy_actual'};
        T = array2table(data_matrix, 'VariableNames', col_names);
        csv_path = fullfile(csv_dir, sprintf('%s_data_frame_%02d.csv', MODE, f_idx));
        writetable(T, csv_path);
        fprintf('[%s] CSV Saved: %s\n', MODE, csv_path);

        % 繪圖
        [X_grid, Y_grid] = meshgrid(xs_range, ys_range);
        fig = figure('Visible', 'off');
        imshow(im1, []); hold on;
        quiver(X_grid, Y_grid, Vx(ys_range, xs_range), Vy(ys_range, xs_range), 0, 'r', 'LineWidth', 0.8);
        title(sprintf('Optical Flow Frame %02d [%s]', f_idx, MODE));
        save_path = fullfile(output_dir, sprintf('%s_flow_%02d.png', MODE, f_idx));
        print(fig, save_path, '-dpng', '-r150');
        close(fig);

    % =========================
    % hw 模式：外圍 w pixel 不算，其餘全部累加，average 後再做 Harris + flow threshold
    % =========================
    else

        Vx_sum   = zeros(n_gy, n_gx);
        Vy_sum   = zeros(n_gy, n_gx);
        Vx_count = zeros(n_gy, n_gx);

        % ── 第一步：(1+w)~(H-w) 每個 pixel 算 flow，detA > 0 才累加 ──
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

                % hw auto-scaling
                max_abs_val = max(abs([raw_Ix2, raw_Iy2, raw_IxIy, raw_IxIt, raw_IyIt]));
                bit_len = 0;
                if max_abs_val > 0, bit_len = ceil(log2(max_abs_val)); end
                shift_amt = max(0, bit_len - 15);

                Ix2_s  = floor(raw_Ix2  / (2^shift_amt));
                Iy2_s  = floor(raw_Iy2  / (2^shift_amt));
                IxIy_s = floor(raw_IxIy / (2^shift_amt));
                IxIt_s = floor(raw_IxIt / (2^shift_amt));
                IyIt_s = floor(raw_IyIt / (2^shift_amt));

                detA_s = Ix2_s * Iy2_s - IxIy_s^2;

                % detA <= 0 → 除法無意義，跳過
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

                % 無條件累加
                Vx_sum(gi, gj)   = Vx_sum(gi, gj)   + vx_final;
                Vy_sum(gi, gj)   = Vy_sum(gi, gj)   + vy_final;
                Vx_count(gi, gj) = Vx_count(gi, gj) + 1;
            end
        end

        % ── 第二步：除以 25 取平均 ──
        valid  = Vx_count > 0;
        Vx_avg = zeros(n_gy, n_gx);
        Vy_avg = zeros(n_gy, n_gx);
        Vx_avg(valid) = Vx_sum(valid) ./ 25;
        Vy_avg(valid) = Vy_sum(valid) ./ 25;

        % ── 第三步：對每個 block center 做 Harris + flow threshold ──
        Vx_out = zeros(n_gy, n_gx);
        Vy_out = zeros(n_gy, n_gx);

        for gi = 1:n_gy
            i = ys_range(gi);
            for gj = 1:n_gx
                j = xs_range(gj);

                if ~valid(gi, gj), continue; end

                % 用 block center 的梯度做 Harris
                patch_Ix = Ix(i-w:i+w, j-w:j+w);
                patch_Iy = Iy(i-w:i+w, j-w:j+w);

                wx = reshape(patch_Ix(2:6, 2:6), [], 1);
                wy = reshape(patch_Iy(2:6, 2:6), [], 1);

                raw_Ix2  = sum(wx.*wx);
                raw_Iy2  = sum(wy.*wy);
                raw_IxIy = sum(wx.*wy);

                max_abs_val = max(abs([raw_Ix2, raw_Iy2, raw_IxIy]));
                bit_len = 0;
                if max_abs_val > 0, bit_len = ceil(log2(max_abs_val)); end
                shift_amt = max(0, bit_len - 15);

                Ix2_s  = floor(raw_Ix2  / (2^shift_amt));
                Iy2_s  = floor(raw_Iy2  / (2^shift_amt));
                IxIy_s = floor(raw_IxIy / (2^shift_amt));

                detH   = Ix2_s * Iy2_s - IxIy_s^2;
                traceH = Ix2_s + Iy2_s;
                R      = double(detH) - double((int64(traceH)*int64(traceH)) * k);

                % 關卡 1：Harris
                if R <= threshold, continue; end

                % 關卡 2：flow magnitude
                if abs(Vx_avg(gi, gj)) >= 3 || abs(Vy_avg(gi, gj)) >= 3
                    continue;
                end

                Vx_out(gi, gj) = Vx_avg(gi, gj) * mul;
                Vy_out(gi, gj) = Vy_avg(gi, gj) * mul;
            end
        end

        % 繪圖
        [X_grid, Y_grid] = meshgrid(xs_range, ys_range);
        fig = figure('Visible', 'off');
        imshow(im1, []); hold on;
        quiver(X_grid, Y_grid, Vx_out, Vy_out, 0, 'r', 'LineWidth', 0.8);
        title(sprintf('Optical Flow Frame %02d [%s - avg then threshold]', f_idx, MODE));
        save_path = fullfile(output_dir, sprintf('%s_flow_%02d.png', MODE, f_idx));
        print(fig, save_path, '-dpng', '-r150');
        close(fig);
    end

    fprintf('[%s] Frame %02d done\n', MODE, f_idx);
end
fprintf('--- 全部處理完成 [MODE = %s] ---\n', MODE);