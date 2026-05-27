// =============================================================================
// Module : LK  (Lucas-Kanade Optical Flow Estimator)
// Description:
//   Computes per-pixel optical flow (Vx, Vy) using the Lucas-Kanade method.
//   Accepts two 8-bit pixel streams (frame A and frame B), accumulates
//   gradient products over a 5x5 window, solves the 2x2 linear system via
//   determinant-based division, and outputs the result as a 12-bit fixed-point
//   velocity vector.
//
// Parameters:
//   width  – pixel bit-width (default 8)
//
// Ports:
//   clk    – system clock
//   rst_n  – active-low synchronous reset
//   a      – pixel from frame A (current frame)
//   b      – pixel from frame B (next frame)
//   valid  – output valid pulse
//   Vout   – 12-bit output (Vx on first cycle, Vy on second cycle)
// =============================================================================

module LK #(parameter width = 8)(
    input              clk,
    input              rst_n,
    input  [7:0]       a,
    input  [7:0]       b,
    output reg         valid,
    output reg [11:0]  Vout
);

    // -------------------------------------------------------------------------
    // Pixel shift-register window
    //   img1[0..13] : 14-tap delay line
    //     img1[0]   = pixel delayed by 14 cycles  → used for Iy (row gradient)
    //     img1[12]  = pixel delayed by  2 cycles  → used for Ix (col gradient)
    //     img1[13]  = latest registered pixel     → written each cycle
    // -------------------------------------------------------------------------
    reg [width-1:0] img1[0:13];

    // Scan counter (row_reg, col_reg) : 7-column × 7-row raster, resets at (6,6)
    reg [3:0] row_reg;
    reg [3:0] col_reg;

    // -------------------------------------------------------------------------
    // Gradient shift registers
    //   Ix[0..4] : 5-tap pipeline for x-gradient (column direction)
    //   It[0..4] : 5-tap pipeline for temporal difference
    //   Index [0] = oldest sample, [4] = newest sample
    // -------------------------------------------------------------------------
    reg signed [width:0]   Ix[0:4];
    reg signed [width:0]   It[0:4];

    // -------------------------------------------------------------------------
    // Accumulated gradient-product sums (Σ over 5×5 window)
    //   Ix2  = Σ Ix²        Iy2  = Σ Iy²
    //   IxIy = Σ Ix·Iy      IxIt = Σ Ix·It      IyIt = Σ Iy·It
    // -------------------------------------------------------------------------
    reg signed [2*width+6:0]  Ix2;
    reg signed [2*width+6:0]  Iy2;
    reg signed [2*width+6:0]  IxIy;
    reg signed [2*width+6:0]  IxIt;
    reg signed [2*width+6:0]  IyIt;

    // Current-cycle gradient values (combinational)
    reg signed [width:0]  Ix_now;
    reg signed [width:0]  Iy_now;
    reg signed [width:0]  It_now;

    // Squared gradient products (combinational, full-width)
    wire [width*2+1:0] Ix_now2 = Ix_now * Ix_now;
    wire [width*2+1:0] Iy_now2 = Iy_now * Iy_now;

    // Registered copies of input pixels (1-cycle delay for pipeline alignment)
    reg [width-1:0] a_reg, b_reg;


    // =========================================================================
    // Section 1 : Enable / shift control signals
    // =========================================================================

    // Shift Ix pipeline when we are past the first column and first row
    wire Ix_shift = (col_reg != 0) && (row_reg != 0);

    // Accumulate Ix², IxIt only when Ix data is valid
    //   (exclude col 0, col 1, row 0, and row 6 flush cycle)
    wire Ix_en    = Ix_shift && (col_reg != 1) && (row_reg != 6);

    // Accumulate Iy², IxIy, IyIt only when Iy data spans two valid rows
    //   (exclude col 0, col 6, rows 0 and 1)
    wire Iy_en    = (col_reg != 6) && (col_reg != 0) &&
                    (row_reg != 0) && (row_reg != 1);

    // Shift It pipeline under the same column/row guard as Ix_shift
    wire It_shift = (col_reg != 6) && (col_reg != 0) && (row_reg != 0);


    // =========================================================================
    // Section 2 : Combinational gradient computation
    //   Central-difference approximation using the delay line:
    //     Ix  ≈ a_reg − img1[12]   (2-pixel horizontal difference)
    //     Iy  ≈ a_reg − img1[0]    (14-pixel = ~2-row vertical difference)
    //     It  ≈ b_reg − a_reg      (frame-to-frame temporal difference)
    // =========================================================================
    always @(*) begin
        Ix_now = a_reg - img1[12];
        Iy_now = a_reg - img1[0];
        It_now = b_reg - a_reg;
    end

    // Pairwise gradient products for current position
    wire signed [2*width+1:0] IxIt_now = Ix_now * It[4];
    wire signed [2*width+1:0] IyIt_now = Iy_now * It[0];
    wire signed [2*width+1:0] IxIy_now = Iy_now * Ix[0];


    // =========================================================================
    // Section 3 : Leading-One Detector for dynamic shift scaling
    //   Finds the most-significant '1' position among all accumulated sums,
    //   so the 16-bit multiplier inputs can be normalised without overflow.
    // =========================================================================

    reg  [2:0]                       mul_counter;        // (reserved for future use)
    reg  signed [2*width+6:0]        mul_src;            // selected accumulator for LOD
    wire [2*width+6:0]               mul_src_abs  = mul_src[2*width+6] ? -mul_src : mul_src;
    wire [$clog2(2*width+7)-1:0]     mul_pos;            // LOD result (current cycle)
    wire [$clog2(2*width+7)-1:0]     mul_pos_new;        // running maximum
    reg  [$clog2(2*width+7)-1:0]     mul_pos_buffer;     // registered maximum
    wire                             mul_valid;           // LOD valid flag

    LOD #(.W(2*width+7)) L_mul (
        .in   (mul_src_abs),
        .pos  (mul_pos),
        .valid(mul_valid)
    );

    // Keep track of the largest bit-position seen across all five accumulators
    assign mul_pos_new = (mul_pos > mul_pos_buffer && mul_valid)
                         ? mul_pos : mul_pos_buffer;

    // Mux: feed each accumulator into the LOD in the appropriate scan slot
    reg mul_pos_valid;
    always @(*) begin
        mul_src       = 0;
        mul_pos_valid = 0;
        if (row_reg == 6) begin
            case (col_reg)
                4: begin mul_src = Ix2;  mul_pos_valid = 1; end   // scan Ix²
                5: begin mul_src = IxIt; mul_pos_valid = 1; end   // scan IxIt
                6: begin mul_src = Iy2;  mul_pos_valid = 1; end   // scan Iy²
            endcase
        end else if (row_reg == 0) begin
            case (col_reg)
                0: begin mul_src = IxIy; mul_pos_valid = 1; end   // scan IxIy
                1: begin mul_src = IyIt; mul_pos_valid = 1; end   // scan IyIt
            endcase
        end
    end

    // Register the running maximum; clear it at the start of each new frame
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mul_pos_buffer <= 0;
        end else begin
            if (mul_pos_valid)
                mul_pos_buffer <= mul_pos_new;
            else if (row_reg == 1)
                mul_pos_buffer <= 0;    // reset for next frame
        end
    end


    // =========================================================================
    // Section 4 : Adaptive right-shift for multiplier input normalisation
    //   If the leading-one position exceeds bit 14, shift right by the excess
    //   so the 16-bit signed multiplier inputs stay within range.
    // =========================================================================

    wire        sum_shift       = (mul_pos_new > 14);
    wire [3:0]  shift_amount    = sum_shift ? (mul_pos_new - 14) : 0;
    reg  [3:0]  shift_amount_reg;   // registered one cycle later (pipeline sync)

    wire signed [2*width-1:0]  Ix2_shift  = (Ix2   >>> shift_amount_reg);
    wire signed [2*width-1:0]  Iy2_shift  = (Iy2   >>> shift_amount_reg);
    wire signed [2*width-1:0]  IxIy_shift = (IxIy  >>> shift_amount_reg);
    wire signed [2*width-1:0]  IxIt_shift = (IxIt  >>> shift_amount_reg);
    wire signed [2*width-1:0]  IyIt_shift = (IyIt  >>> shift_amount_reg);


    // =========================================================================
    // Section 5 : Pipelined multipliers  (2-cycle latency each)
    //   Compute all products needed for the 2×2 matrix solution:
    //     Ux =  −Iy²·IxIt  +  IxIy·IyIt
    //     Uy =  −Ix²·IyIt  +  IxIy·IxIt
    //     det = Ix²·Iy²    −  IxIy²
    // =========================================================================

    wire signed [4*width-1:0] Iy2_IxIt, Ix2_IyIt, Ix2_Iy2;
    wire signed [4*width-1:0] IxIy_IyIt, IxIy_IxIt, IxIy2;

    mult_pipe M1 (.clk(clk), .rst_n(rst_n), .A(Iy2_shift),  .B(IxIt_shift), .result(Iy2_IxIt));
    mult_pipe M2 (.clk(clk), .rst_n(rst_n), .A(Ix2_shift),  .B(IyIt_shift), .result(Ix2_IyIt));
    mult_pipe M3 (.clk(clk), .rst_n(rst_n), .A(Ix2_shift),  .B(Iy2_shift),  .result(Ix2_Iy2));
    mult_pipe M4 (.clk(clk), .rst_n(rst_n), .A(IxIy_shift), .B(IyIt_shift), .result(IxIy_IyIt));
    mult_pipe M5 (.clk(clk), .rst_n(rst_n), .A(IxIy_shift), .B(IxIt_shift), .result(IxIy_IxIt));
    mult_pipe M6 (.clk(clk), .rst_n(rst_n), .A(IxIy_shift), .B(IxIy_shift), .result(IxIy2));

    wire signed [4*width:0]  Ux  = -Iy2_IxIt  + IxIy_IyIt;
    wire signed [4*width:0]  Uy  = -Ix2_IyIt  + IxIy_IxIt;
    wire signed [4*width:0]  det =  Ix2_Iy2   - IxIy2;

    reg signed [4*width:0]   Ux_reg, Uy_reg;   // registered Ux / Uy (pipeline sync)
    reg                      det_signed;         // sign bit of det (registered)


    // =========================================================================
    // Section 6 : Division via LOD-based arithmetic right-shift
    //   Approximates  Ux/det  and  Uy/det  by:
    //     1. Finding the leading-one position of |det|  → div_pos
    //     2. Left-padding Ux/Uy by 8 bits (for sub-pixel precision)
    //     3. Right-shifting by div_pos  (≈ dividing by 2^div_pos ≈ det)
    //     4. Correcting sign when det was negative
    // =========================================================================

    wire [4*width:0]                  det_abs     = det[4*width] ? (-det) : det;
    wire [$clog2(4*width+1)-1:0]      div_pos;        // LOD output
    reg  [$clog2(4*width+1)-1:0]      div_pos_reg;    // registered one cycle later
    wire                              div_valid;       // det is non-zero

    LOD #(.W(4*width+1)) L1 (
        .in   (det_abs),
        .pos  (div_pos),
        .valid(div_valid)
    );

    // Sign-extend and left-pad for 8-bit sub-pixel precision
    wire signed [4*width+11:0]  Ux_pad    = {{3{Ux_reg[4*width]}}, Ux_reg, 8'b0};
    wire signed [4*width+11:0]  Uy_pad    = {{3{Uy_reg[4*width]}}, Uy_reg, 8'b0};

    // Approximate division by right-shifting
    wire signed [4*width+11:0]  shifted_x = Ux_pad >>> div_pos_reg;
    wire signed [4*width+11:0]  shifted_y = Uy_pad >>> div_pos_reg;

    // Apply sign correction if det was negative (flip quotient sign)
    wire signed [11:0]  result_x = det_signed ? -$signed(shifted_x[11:0])
                                               :  $signed(shifted_x[11:0]);
    wire signed [11:0]  result_y = det_signed ? -$signed(shifted_y[11:0])
                                               :  $signed(shifted_y[11:0]);


    // =========================================================================
    // Section 7 : Harris corner filter & velocity clamp
    //   Output is forced to zero when:
    //     • det is zero         (div_valid == 0)
    //     • velocity magnitude exceeds ±5.0 pixels  (too_long)
    //     • Harris corner response is below threshold (~corner)
    // =========================================================================

    reg signed [11:0]  vx_reg, vy_reg;

    Harris #(.width(width)) H1 (
        .Ix2   (Ix2_shift),
        .Iy2   (Iy2_shift),
        .det   (det),
        .corner(corner),
        .clk   (clk),
        .rst_n (rst_n)
    );
    wire corner;

    // Velocity magnitude check : ±5.0 in Q4.8 fixed-point = ±0x140
    wire too_long = ($signed(result_x) >  $signed(12'b010100000000) ||
                     $signed(result_x) <  $signed(12'b101100000000) ||
                     $signed(result_y) >  $signed(12'b010100000000) ||
                     $signed(result_y) <  $signed(12'b101100000000));

    always @(*) begin
        // Vx output
        if (~div_valid || too_long || ~corner)
            vx_reg = 8'b0;
        else
            vx_reg = result_x;

        // Vy output
        if (~div_valid || too_long || ~corner)
            vy_reg = 8'b0;
        else
            vy_reg = result_y;
    end


    // =========================================================================
    // Section 8 : Shift-register update
    //   img1 : continuous 14-cycle delay line (always shifting)
    //   Ix   : shift only when Ix_shift is asserted
    //   It   : shift only when It_shift is asserted
    // =========================================================================

    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (j = 0; j < 14; j = j + 1) img1[j] <= 0;
            for (j = 0; j <  5; j = j + 1) begin
                Ix[j] <= 0;
                It[j] <= 0;
            end
        end else begin
            // Advance delay line; insert newest registered pixel at [13]
            for (j = 0; j <= 12; j = j + 1)
                img1[j] <= img1[j + 1];
            img1[13] <= a_reg;

            // Shift x-gradient pipeline
            if (Ix_shift) begin
                for (j = 0; j <= 3; j = j + 1)
                    Ix[j] <= Ix[j + 1];
                Ix[4] <= Ix_now;
            end

            // Shift temporal-difference pipeline
            if (It_shift) begin
                for (j = 0; j <= 3; j = j + 1)
                    It[j] <= It[j + 1];
                It[4] <= It_now;
            end
        end
    end


    // =========================================================================
    // Section 9 : Accumulation & output control
    // =========================================================================

    reg start_valid;    // suppress the very first output until one full frame

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            Iy2           <= 0;
            Ix2           <= 0;
            IxIt          <= 0;
            IyIt          <= 0;
            IxIy          <= 0;
            Vout          <= 0;
            valid         <= 0;
            start_valid   <= 0;
            a_reg         <= 0;
            b_reg         <= 0;
            shift_amount_reg <= 0;
            div_pos_reg   <= 0;
            Ux_reg        <= 0;
            Uy_reg        <= 0;
            det_signed    <= 0;
        end else begin
            // --- Pipeline registers (1-cycle delay) ---
            a_reg            <= a;
            b_reg            <= b;
            shift_amount_reg <= shift_amount;
            Ux_reg           <= Ux;
            Uy_reg           <= Uy;
            det_signed       <= det[4*width];
            div_pos_reg      <= div_pos;

            // --- Output Vx then Vy on consecutive cycles ---
            if (col_reg == 6 && row_reg == 0) begin
                Vout <= vx_reg;                     // cycle 0 : output Vx
                if (start_valid) valid <= 1;
                else             start_valid <= 1;  // skip first incomplete frame
            end else if (col_reg == 0 && row_reg == 1) begin
                Vout <= vy_reg;                     // cycle 1 : output Vy
            end

            // De-assert valid one cycle after the Vy output
            if (col_reg == 1 && row_reg == 1)
                valid <= 0;

            // --- Clear accumulators at the end of each window (flush slot) ---
            if (col_reg == 6 && row_reg == 0) begin
                Iy2  <= 0;
                Ix2  <= 0;
                IxIt <= 0;
                IyIt <= 0;
                IxIy <= 0;
            end else begin
                // Accumulate Iy-related products
                if (Iy_en) begin
                    Iy2  <= Iy2  + Iy_now2;
                    IxIy <= IxIy + IxIy_now;
                    IyIt <= IyIt + IyIt_now;
                end
                // Accumulate Ix-related products
                if (Ix_en) begin
                    Ix2  <= Ix2  + Ix_now2;
                    IxIt <= IxIt + IxIt_now;
                end
            end
        end
    end


    // =========================================================================
    // Section 10 : Scan counter  (col_reg × row_reg)
    //   Counts 0→6 across, 0→6 down, wraps at (6,6) back to (0,0)
    // =========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_reg <= 6;
            col_reg <= 6;
        end else begin
            if (col_reg == 6) begin
                col_reg <= 0;
                row_reg <= (row_reg == 6) ? 0 : row_reg + 1;
            end else begin
                col_reg <= col_reg + 1;
            end
        end
    end

endmodule


// =============================================================================
// Module : LOD  (Leading-One Detector)
// Description:
//   Recursive binary tree that returns the bit-position of the most-significant
//   '1' in the input vector.
//
// Parameters:
//   W    – input width (any positive integer; padded to next power-of-2 internally)
//
// Ports:
//   in    – W-bit input
//   pos   – ⌈log₂W⌉-bit position of the leading '1' (0 = LSB)
//   valid – asserted when at least one bit of 'in' is '1'
// =============================================================================

module LOD #(
    parameter W = 45
)(
    input  [W-1:0]           in,
    output [$clog2(W)-1:0]   pos,
    output                   valid
);

    localparam W_pow2 = 1 << $clog2(W);

    // Zero-pad the input to the next power-of-2 width
    wire [W_pow2-1:0] in_pad;

    generate
        if (W_pow2 == W) begin : no_padding_zeros
            assign in_pad = in;
        end else begin : padding_zeros
            assign in_pad = {{(W_pow2 - W){1'b0}}, in};
        end

        if (W_pow2 == 2) begin : base_case
            // Base case : 2-bit input
            assign valid = in_pad[1] | in_pad[0];
            assign pos   = in_pad[1];
        end else begin : recursive_case
            // Recursive case : split into upper and lower halves
            wire                       left_valid,  right_valid;
            wire [$clog2(W_pow2/2)-1:0] left_pos,   right_pos;

            LOD #(.W(W_pow2/2)) LOD_left  (.in(in_pad[W_pow2-1   : W_pow2/2]), .pos(left_pos),  .valid(left_valid));
            LOD #(.W(W_pow2/2)) LOD_right (.in(in_pad[W_pow2/2-1 : 0        ]), .pos(right_pos), .valid(right_valid));

            assign valid = left_valid | right_valid;
            // Upper half takes priority; prepend '1' to its sub-position
            assign pos   = left_valid ? {1'b1, left_pos} : {1'b0, right_pos};
        end
    endgenerate

endmodule


// =============================================================================
// Module : Harris  (Harris Corner Detector)
// Description:
//   Evaluates the Harris corner response:
//     R = det(M) − k · trace(M)²
//   where M = [[Ix², IxIy],[IxIy, Iy²]].
//   k is approximated as 1/16 (arithmetic right-shift by 4).
//   Output 'corner' is asserted when R exceeds a fixed threshold.
//
// Parameters:
//   width  – pixel bit-width (should match LK)
//
// Ports:
//   Ix2    – accumulated Σ Ix²   (2×width bits)
//   Iy2    – accumulated Σ Iy²   (2×width bits)
//   det    – pre-computed determinant from LK (4×width+1 bits)
//   clk, rst_n
//   corner – asserted when this pixel is a corner
// =============================================================================

module Harris #(parameter width = 8)(
    input  [2*width-1:0]  Ix2,
    input  [2*width-1:0]  Iy2,
    input  [4*width:0]    det,
    input                 clk,
    input                 rst_n,
    output                corner
);

    // trace = Ix² + Iy²
    wire [2*width:0] trace = Ix2 + Iy2;

    // Split trace into high and low halves for efficient squaring
    wire [7:0]  trace_hi = trace[2*width : width+1];   // upper (width-1) bits
    wire [8:0]  trace_lo = trace[width   : 0];          // lower (width+1) bits

    // ----- Pipeline Stage 1 : partial products of trace² -----
    reg [17:0]         s1_P0;    // trace_lo × trace_lo
    reg [16:0]         s1_P1;    // trace_hi × trace_lo  (× 2^(width+1))
    reg [15:0]         s1_P2;    // trace_hi × trace_hi  (× 2^(2·width+2))
    reg [4*width:0]    s1_det;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            s1_P0  <= 0;
            s1_P1  <= 0;
            s1_P2  <= 0;
            s1_det <= 0;
        end else begin
            s1_P0  <= trace_lo * trace_lo;
            s1_P1  <= trace_hi * trace_lo;
            s1_P2  <= trace_hi * trace_hi;
            s1_det <= det;
        end
    end

    // ----- Reconstruct trace² from partial products -----
    wire [4*width+1:0] trace_sq1 =
          {{(2*width-16){1'b0}}, s1_P0}
        + ({{(2*width-15){1'b0}}, s1_P1} << (width+1));

    wire [4*width+1:0] trace_sq2 =
          ({{(2*width-15){1'b0}}, s1_P1} << (width+1))
        + ({{(2*width-14){1'b0}}, s1_P2} << (2*width+2));

    wire [4*width+1:0] trace_sq = trace_sq1 + trace_sq2;

    // ----- Pipeline Stage 2 : register trace² and det -----
    reg [4*width+1:0]  trace_sq_reg;
    reg [4*width:0]    det_reg;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            trace_sq_reg <= 0;
            det_reg      <= 0;
        end else begin
            trace_sq_reg <= trace_sq;
            det_reg      <= s1_det;
        end
    end

    // ----- Harris response  R = det − trace²/16 -----
    wire signed [4*width+1:0] R = $signed(det_reg)
                                - $signed(trace_sq_reg >>> 4);

    localparam signed [31:0] THRESHOLD = 32'd10000000;
    assign corner = (R > THRESHOLD);

endmodule


// =============================================================================
// Module : mult_pipe  (2-Stage Pipelined 16-bit Signed Multiplier)
// Description:
//   Decomposes a 16-bit × 16-bit multiply into four 9-bit × 8-bit sub-products
//   using Karatsuba-like splitting, then recombines across two pipeline stages.
//   Both inputs are interpreted as signed 16-bit integers.
//
//   Stage 1 (4 partial products) → Stage 2 (accumulate) → result
//
// Ports:
//   clk, rst_n
//   A, B    – 16-bit signed operands
//   result  – 32-bit signed product (2-cycle latency)
// =============================================================================

module mult_pipe (
    input         clk,
    input         rst_n,
    input  [15:0] A,
    input  [15:0] B,
    output [31:0] result
);

    // Split each operand into signed high byte and unsigned low byte
    wire signed [8:0]  A_hi = $signed(A[15:8]);
    wire        [7:0]  A_lo = A[7:0];
    wire signed [8:0]  B_hi = $signed(B[15:8]);
    wire        [7:0]  B_lo = B[7:0];

    // ----- Stage 1 : compute four partial products -----
    reg signed [16:0]  s1_P0;      // A_lo × B_lo  (u8×u8 → u16, sign-extended)
    reg signed [16:0]  s1_P1;      // A_hi × B_lo  (s9×u8 → s17)
    reg signed [16:0]  s1_P2;      // A_lo × B_hi  (u8×s9 → s17)
    reg signed [16:0]  s1_P3;      // A_hi × B_hi  (s9×s9 → s16, sign-extended)
    reg                s1_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_P0    <= 0;
            s1_P1    <= 0;
            s1_P2    <= 0;
            s1_P3    <= 0;
            s1_valid <= 1'b0;
        end else begin
            s1_P0    <= $signed({1'b0, A_lo}) * $signed({1'b0, B_lo});
            s1_P1    <= A_hi                  * $signed({1'b0, B_lo});
            s1_P2    <= $signed({1'b0, A_lo}) * B_hi;
            s1_P3    <= A_hi                  * B_hi;
            s1_valid <= 1'b1;
        end
    end

    // ----- Stage 2 : accumulate shifted partial products -----
    // P1 and P2 are weighted by 2^8; P3 is weighted by 2^16
    wire signed [31:0] s2_1 = $signed({{15{s1_P0[16]}}, s1_P0})
                             + ($signed({{15{s1_P1[16]}}, s1_P1}) <<< 8);

    wire signed [31:0] s2_2 = ($signed({{15{s1_P2[16]}}, s1_P2}) <<< 8)
                             + ($signed({{15{s1_P3[16]}}, s1_P3}) <<< 16);

    reg signed [31:0]  s2_result;
    reg                s2_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_result <= 32'd0;
            s2_valid  <= 1'b0;
        end else begin
            s2_result <= s2_1 + s2_2;
            s2_valid  <= s1_valid;
        end
    end

    assign result = s2_result;

endmodule