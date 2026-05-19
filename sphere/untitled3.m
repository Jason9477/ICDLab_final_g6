clc; clear; close all;

% =========================
% 1. 路徑與參數設定
% =========================
input_dir  = 'test/compressed/MiniCooper';
output_dir = 'output_flow_png/Minicooper';
% input_dit ='';
% output_dir = 'output_flow_png/';
csv_dir    = 'output_csv_data/';
if ~exist(output_dir, 'dir'), mkdir(output_dir); end
if ~exist(csv_dir,    'dir'), mkdir(csv_dir);    end

start_frame = 7;
end_frame   = 14;

window_size = 7;
w           = floor(window_size / 2);  % w = 3
core_size   = 5;
stride      = 5;
mul         = 5  ;
threshold = 1e6 ;
% =========================
% ★ 模式開關：'hw' 或 'sw'
% =========================
MODE = 'hw';   % 'hw' = 硬體模擬（auto-scale + fixed-point）
               % 'sw' = 軟體參考（full precision，直接除法）

% =========================
% 2. 連續處理迴圈
% =========================
for f_idx = start_frame : (end_frame - 1)

    file1 = fullfile(input_dir, sprintf('frame%02d.png', f_idx));
    file2 = fullfile(input_dir, sprintf('frame%02d.png', f_idx + 1));
    % file1 = fullfile('s2_wide.png');
    % file2 = fullfile('s3_wide.png');
    % file1 = fullfile('pp1.png');
    % file2 = fullfile('pp2.png');
    if ~exist(file1, 'file') || ~exist(file2, 'file'), continue; end

    im1 = double(imread(file1));
    im2 = double(imread(file2));
    [H, W] = size(im1);

    % --- 梯度（向量化）---
    Ix = zeros(H, W); Iy = zeros(H, W); It = zeros(H, W);
    Ix(2:H-1, 2:W-1) = im1(2:H-1, 3:W)   - im1(2:H-1, 1:W-2);
    Iy(2:H-1, 2:W-1) = im1(3:H,   2:W-1) - im1(1:H-2, 2:W-1);
    It(2:H-1, 2:W-1) = (im2(2:H-1, 2:W-1) - im1(2:H-1, 2:W-1)) ;

    Vx = zeros(H, W); Vy = zeros(H, W);
    ys_range = (1+w):stride:(H-w);
    xs_range = (1+w):stride:(W-w);

    num_windows = length(ys_range) * length(xs_range);
    data_matrix = zeros(num_windows, 23);
    row_cnt = 0;

    for i = ys_range
        for j = xs_range

            % 7×7 patch，只取中間 5×5 累加
            patch_Ix = Ix(i-w:i+w, j-w:j+w);
            patch_Iy = Iy(i-w:i+w, j-w:j+w);
            patch_It = It(i-w:i+w, j-w:j+w);

            wx = reshape(patch_Ix(2:6, 2:6), [], 1);
            wy = reshape(patch_Iy(2:6, 2:6), [], 1);
            wt = reshape(patch_It(2:6, 2:6), [], 1);

            % --- 原始累加值 ---
            raw_Ix2  = sum(wx.*wx);
            raw_Iy2  = sum(wy.*wy);
            raw_IxIy = sum(wx.*wy);
            raw_IxIt = sum(wx.*wt);
            raw_IyIt = sum(wy.*wt);

            % 共用的 raw det / 分子
            raw_detA = (raw_Ix2 * raw_Iy2) - (raw_IxIy^2);
            raw_Ux   = -(raw_Iy2 * raw_IxIt) + (raw_IxIy * raw_IyIt);
            raw_Uy   = -(raw_Ix2 * raw_IyIt) + (raw_IxIy * raw_IxIt);

            % 初始化輸出
            vx_f = 0; vy_f = 0; vx_final = 0; vy_final = 0;
            vx_actual = 0; vy_actual = 0;
            shift_amt = 0;
            Ix2_s = 0; Iy2_s = 0; IxIy_s = 0; IxIt_s = 0; IyIt_s = 0;
            R = 0; detA_s = 0; Ux_s = 0; Uy_s = 0;

            % =========================================================
            if strcmp(MODE, 'sw')
            % =========================================================
            % ★ 軟體模式：full precision，直接浮點除法，不省略任何步驟

                % Harris（用 raw 值）
                raw_detH  = raw_Ix2 * raw_Iy2 - raw_IxIy^2;
                raw_trace = raw_Ix2 + raw_Iy2;
                R         = raw_detH - 0.06 * (raw_trace^2);

                if R > threshold  && raw_detA > 0

                    % 直接浮點除法，不做任何 bit 操作
                    vx_actual = raw_Ux / raw_detA;
                    vy_actual = raw_Uy / raw_detA;

                    if abs(vx_actual) < 5 && abs(vy_actual) < 5
                        Vx(i,j) = vx_actual * mul;
                        Vy(i,j) = vy_actual * mul;
                    else
                        Vx(i,j) = 0; Vy(i,j) = 0;
                        vx_actual = 0; vy_actual = 0;
                    end

                    % 讓 CSV 欄位有值（hw 專用欄填 NaN）
                    vx_final = vx_actual;
                    vy_final = vy_actual;
                end

            % =========================================================
            else  % MODE == 'hw'
            % =========================================================
            % ★ 硬體模式：auto-scale + fixed-point 除法

                % Step A: Auto-scaling
                max_abs_val = max(abs([raw_Ix2, raw_Iy2, raw_IxIy, raw_IxIt, raw_IyIt]));
                bit_len = 0;
                if max_abs_val > 0, bit_len = ceil(log2(max_abs_val)); end
                shift_amt = max(0, bit_len - 15);

                Ix2_s  = floor(raw_Ix2  / (2^shift_amt));
                Iy2_s  = floor(raw_Iy2  / (2^shift_amt));
                IxIy_s = floor(raw_IxIy / (2^shift_amt));
                IxIt_s = floor(raw_IxIt / (2^shift_amt));
                IyIt_s = floor(raw_IyIt / (2^shift_amt));

                % Step B: Harris
                detH   = Ix2_s * Iy2_s - IxIy_s^2;
                traceH = Ix2_s + Iy2_s;
                R      = double(detH) - double((int64(traceH)*int64(traceH)) * 0.0625 );
                detA_s = detH;

                % Step C: LK 分子
                Ux_s = -(Iy2_s * IxIt_s) + (IxIy_s * IyIt_s);
                Uy_s = -(Ix2_s * IyIt_s) + (IxIy_s * IxIt_s);
                if detA_s== 0 
                    fprintf("aaaa")
                end
                if R > threshold     && detA_s > 0 && raw_detA > 0

                    % 理論實際值（對照用）
                    vx_actual = raw_Ux / raw_detA;
                    vy_actual = raw_Uy / raw_detA;

                    % Fixed-point 除法（bit-shift 近似）
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

                    if abs(vx_final) < 5 || abs(vy_final) < 5
                        Vx(i,j) = vx_final * mul;
                        Vy(i,j) = vy_final * mul;
                    else
                        Vx(i,j) = 0; Vy(i,j) = 0;
                        vx_actual = 0; vy_actual = 0;
                        vx_final  = 0; vy_final  = 0;
                        vx_f = 0; vy_f = 0;
                    end
                else
                        Vx(i,j) = 0; Vy(i,j) = 0;
                        vx_actual = 0; vy_actual = 0;
                        vx_final  = 0; vy_final  = 0;
                        vx_f = 0; vy_f = 0;
                end
            end  % MODE

            row_cnt = row_cnt + 1;
            data_matrix(row_cnt, :) = [i, j, raw_Ix2, raw_Iy2, raw_IxIy, raw_IxIt, raw_IyIt, ...
                                       shift_amt, Ix2_s, Iy2_s, IxIy_s, IxIt_s, IyIt_s, ...
                                       R, detA_s, Ux_s, Uy_s, vx_f, vy_f, vx_final, vy_final, ...
                                       vx_actual, vy_actual];
        end
    end

    % =========================
    % 3. 儲存 CSV
    % =========================
    col_names = {'Row_Idx', 'Col_Idx', 'raw_Ix2', 'raw_Iy2', 'raw_IxIy', 'raw_IxIt', 'raw_IyIt', ...
                 'shift_amt', 'Ix2_s', 'Iy2_s', 'IxIy_s', 'IxIt_s', 'IyIt_s', ...
                 'Harris_R', 'detA_s', 'Ux_s', 'Uy_s', 'vx_fixed', 'vy_fixed', ...
                 'Vx_phys', 'Vy_phys', 'vx_actual', 'vy_actual'};
    
    T = array2table(data_matrix, 'VariableNames', col_names);
    csv_path = fullfile(csv_dir, sprintf('%s_data_frame_%02d.csv', MODE, f_idx));
    writetable(T, csv_path);
    fprintf('[%s] CSV Saved: %s\n', MODE, csv_path);
    
    % =========================
    % 3b. 儲存 Vx/Vy 12-bit hex TXT
    %     格式：1 sign + 3 integer + 8 fraction = 12 bit
    %     每行一個值，vx 換行 vy 換行 vx ...
    % =========================
    txt_path = fullfile(csv_dir, sprintf('%s_flow_hex_frame_%02d.txt', MODE, f_idx));
    fid = fopen(txt_path, 'w');
    
    for r = 1:row_cnt
        vx_phys = data_matrix(r, 20);  % Vx_phys 欄
        vy_phys = data_matrix(r, 21);  % Vy_phys 欄
    
        fprintf(fid, '%s\n', float_to_12bit_hex(vx_phys));
        fprintf(fid, '%s\n', float_to_12bit_hex(vy_phys));
    end
    
    fclose(fid);
    fprintf('[%s] HEX TXT Saved: %s\n', MODE, txt_path);

    % =========================
    % 4. 繪圖與儲存 PNG
    % =========================
    fig = figure('Visible', 'off');
    imshow(im1, []); hold on;
    [X_grid, Y_grid] = meshgrid(xs_range, ys_range);
    quiver(X_grid, Y_grid, Vx(ys_range, xs_range), Vy(ys_range, xs_range), 0, 'r', 'LineWidth', 0.8);
    title(sprintf('Optical Flow Frame %02d [%s]', f_idx, MODE));
    save_path = fullfile(output_dir, sprintf('%s_flow_%02d.png',MODE , f_idx));
    print(fig, save_path, '-dpng', '-r150');
    close(fig);
end
fprintf('--- 全部處理完成 [MODE = %s] ---\n', MODE);
% =========================
% Helper：浮點數 → 12-bit signed fixed-point hex
%         格式：1 sign + 3 integer + 8 fraction
%         範圍：-8.0 ~ +7.99609375，精度 1/256
% =========================
function hex_str = float_to_12bit_hex(val)
    % 量化：乘以 2^8 = 256，四捨五入
    quantized = round(val * 256);

    % 夾住範圍：12-bit signed = -2048 ~ 2047
    quantized = max(min(quantized, 2047), -2048);

    % 負數轉 two's complement
    if quantized < 0
        quantized = quantized + 4096;  % 2^12 = 4096
    end

    % 轉成 3 位 hex（12 bit = 3 hex digits）
    hex_str = sprintf('%03X', quantized);
end