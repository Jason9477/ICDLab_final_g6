
module LK #(parameter width = 8)(
    input clk,
    input rst_n,
    input [7:0] a,
    input [7:0] b,
    output reg valid,
    output reg [11:0] Vout
);
    // reg [7:0] img1[0:48] ;
    reg [width-1:0] img1[0:13] ;
    reg [3:0] row_reg;
    reg [3:0] col_reg;
    // reg signed [8:0] Ix[0:24];
    reg signed [width:0] Ix[0:4];
    // reg signed [8:0] It[0:24];
    reg signed [width:0] It[0:4];
    // reg signed [8:0] Iy[0:24];
    // reg [5:0]counter ;
    reg signed[2*width+6:0] Ix2;
    reg signed[2*width+6:0] Iy2;
    reg signed [2*width+6:0] IxIy;
    reg signed [2*width+6:0] IxIt;
    reg signed [2*width+6:0] IyIt;
    reg signed [width:0] Ix_now ;
    reg signed [width:0] Iy_now ;
    reg signed [width:0] It_now;
    wire [width*2+1:0] Ix_now2 = Ix_now * Ix_now;//18 = 9+9
    wire [width*2+1:0] Iy_now2 = Iy_now * Iy_now;
    reg [width-1:0] a_reg, b_reg;
    wire [7:0] ig0 = img1[0];
    wire [7:0] ig1 = img1[1];
    wire [7:0] ig2 = img1[2];
    wire [7:0] ig3 = img1[3];
    wire [7:0] ig4 = img1[4];
    wire [7:0] ig5 = img1[5];
    wire [7:0] ig6 = img1[6];
    wire [7:0] ig7 = img1[7];
    wire [7:0] ig8 = img1[8];
    wire [7:0] ig9 = img1[9];
    wire [7:0] ig10 = img1[10];
    wire [7:0] ig11 = img1[11];
    wire [7:0] ig12 = img1[12];
    wire [7:0] ig13 = img1[13];

wire Ix_shift = (col_reg !=0) && (row_reg !=0); //什麼時候要 shift Ix
wire Ix_en = Ix_shift && (col_reg !=1) && (row_reg !=6); //什麼時候要計算 Ix^2 IxIt
wire Iy_en = (col_reg !=6) && (col_reg !=0) && (row_reg !=0 && row_reg !=1); //什麼時候要計算 Iy^2 IxIy IyIt 
wire It_shift = (col_reg !=6) && (col_reg !=0) && (row_reg !=0); //什麼時候要 shift It

always @(*) begin
    Ix_now =  a_reg - img1[12];
    Iy_now =  a_reg - img1[0];
    It_now =  b_reg - a_reg;
end
// wire signed [15:0] IxIt_now = Ix_now*It[(row_reg-1)*5 + col_reg-2];
wire signed [2*width+1:0] IxIt_now = Ix_now*It[4];
wire signed [2*width+1:0] IyIt_now = Iy_now*It[0];
wire signed [2*width+1:0] IxIy_now = Iy_now*Ix[0];

// // matrix multiplication
// reg [2 : 0] mul_counter;
// reg signed [2*width+6:0] mul_src;
// wire [2*width+6:0] mul_abs [0:4];

// assign mul_abs[0] = Ix2   [2*width+6] ? -Ix2   : Ix2;
// assign mul_abs[1] = Iy2   [2*width+6] ? -Iy2   : Iy2;
// assign mul_abs[2] = IxIy  [2*width+6] ? -IxIy  : IxIy;
// assign mul_abs[3] = IxIt  [2*width+6] ? -IxIt  : IxIt;
// assign mul_abs[4] = IyIt  [2*width+6] ? -IyIt  : IyIt;
// wire [$clog2(2*width+7) - 1 : 0] mul_pos[0:4];
// wire [$clog2(2*width+7) - 1 : 0] pos1 = mul_pos[0];
// wire [$clog2(2*width+7) - 1 : 0] pos2 = mul_pos[1];
// wire [$clog2(2*width+7) - 1 : 0] pos3 = mul_pos[2];
// wire [$clog2(2*width+7) - 1 : 0] pos4 = mul_pos[3];
// wire [$clog2(2*width+7) - 1 : 0] pos5 = mul_pos[4];
// wire [$clog2(2*width+7) - 1 : 0] mul_pos_new;
// reg [$clog2(2*width+7) - 1 : 0] mul_pos_buffer;
// wire mul_valid;
// LOD #(.W(2*width+7)) L_mul0 (.in(mul_abs[0]), .pos(mul_pos[0]), .valid(mul_valid));
// LOD #(.W(2*width+7)) L_mul1 (.in(mul_abs[1]), .pos(mul_pos[1]), .valid(mul_valid));
// LOD #(.W(2*width+7)) L_mul2 (.in(mul_abs[2]), .pos(mul_pos[2]), .valid(mul_valid));
// LOD #(.W(2*width+7)) L_mul3 (.in(mul_abs[3]), .pos(mul_pos[3]), .valid(mul_valid));
// LOD #(.W(2*width+7)) L_mul4 (.in(mul_abs[4]), .pos(mul_pos[4]), .valid(mul_valid));
// reg [$clog2(2*width+7)-1:0] max_val;
// integer i;
// always @(*) begin
//     max_val = mul_pos[0];
    
//     for(i=1;i<5;i=i+1) begin
//         if(mul_pos[i] > max_val)
//             max_val = mul_pos[i];
//     end
// end

reg [2 : 0] mul_counter;
reg signed [2*width+6:0] mul_src;
wire [2*width+6:0] mul_src_abs = mul_src[2*width+6]? -mul_src : mul_src;
wire [$clog2(2*width+7) - 1 : 0] mul_pos;
wire [$clog2(2*width+7) - 1 : 0] mul_pos_new;
reg [$clog2(2*width+7) - 1 : 0] mul_pos_buffer;
wire mul_valid;
LOD #(.W(2*width+7)) L_mul (.in(mul_src_abs), .pos(mul_pos), .valid(mul_valid));
assign mul_pos_new = (mul_pos > mul_pos_buffer && mul_valid)? mul_pos : mul_pos_buffer;
reg mul_pos_valid;
always @* begin
    mul_src = 0;
    mul_pos_valid = 0;
    if(row_reg == 6) begin
        case (col_reg)
        4: begin  mul_src = Ix2; mul_pos_valid = 1; end
        5: begin  mul_src = IxIt; mul_pos_valid = 1; end
        6: begin  mul_src = Iy2; mul_pos_valid = 1; end
        endcase
    end else if(row_reg ==0) begin
        case (col_reg) 
            0:begin mul_src = IxIy; mul_pos_valid = 1; end
            1:begin mul_src = IyIt; mul_pos_valid = 1; end
        endcase
    end

end
always @(posedge clk or negedge rst_n) begin 
    if (~rst_n) begin
        mul_pos_buffer <= 0;
    end
    else begin 
        if (mul_pos_valid ) begin
            mul_pos_buffer <= mul_pos_new;
        end else if(row_reg == 1)begin
            mul_pos_buffer<= 0;
        end
    end
end





// always @(posedge clk or negedge rst_n) begin 
//     if (~rst_n) begin
//         mul_pos_buffer <= 0;
//     end
//     else begin 
//         if (col_reg == 6 && row_reg == 6) begin
//             mul_pos_buffer <= max_val;
//         end

//     end
// end

wire sum_shift = (mul_pos_buffer > 14);
wire [3:0] shift_amount = (sum_shift)? (mul_pos_buffer - 14) : 0;
wire signed[2*width-1:0] Ix2_shift = (Ix2 >>> shift_amount);
wire signed[2*width-1:0] Iy2_shift =  (Iy2 >>> shift_amount) ;
wire signed[2*width-1:0] IxIy_shift = (IxIy >>> shift_amount) ;
wire signed[2*width-1:0] IxIt_shift = (IxIt >>> shift_amount) ;
wire signed[2*width-1:0] IyIt_shift = (IyIt >>> shift_amount) ;
// wire signed [4*width:0] Ux = -(Iy2_shift * IxIt_shift) + (IxIy_shift * IyIt_shift); //-(197316*36516)+(-156086*-15534) =-4780551168
// wire signed [4*width:0] Uy = -(Ix2_shift * IyIt_shift)+ (IxIy_shift * IxIt_shift);//-(341126*-15534) + (-156086*36516)
// wire signed [4*width:0] det = (Ix2_shift * Iy2_shift) - (IxIy_shift * IxIy_shift);
reg signed [4*width-1:0] Iy2_IxIt_reg, Ix2_IyIt_reg, Ix2_Iy2_reg,IxIy_IyIt_reg, IxIy_IxIt_reg,IxIy2_reg;
wire signed [4*width-1:0] Iy2_IxIt = Iy2_shift * IxIt_shift;
wire signed [4*width-1:0] Ix2_IyIt = Ix2_shift * IyIt_shift;
wire signed [4*width-1:0] Ix2_Iy2 = Ix2_shift * Iy2_shift;
wire signed [4*width-1:0] IxIy_IyIt = IxIy_shift * IyIt_shift;
wire signed [4*width-1:0] IxIy_IxIt = IxIy_shift * IxIt_shift;
wire signed [4*width-1:0] IxIy2 = IxIy_shift * IxIy_shift;
wire signed [4*width:0] Ux = -Iy2_IxIt_reg + IxIy_IyIt_reg; //-(197316*36516)+(-156086*-15534) =-4780551168
wire signed [4*width:0] Uy = -Ix2_IyIt_reg + IxIy_IxIt_reg;//-(341126*-15534) + (-156086*36516)
wire signed [4*width:0] det = Ix2_Iy2_reg - IxIy2_reg;//(Ix2_shift * Iy2_shift) - (IxIy_shift * IxIy_shift);

// division
wire [4*width:0] det_abs = det[4*width]? (-det) : det;
wire [$clog2(4*width+1)-1 : 0] div_pos;
wire div_valid;
LOD #(.W(4*width+1)) L1(.in(det_abs), .pos(div_pos), .valid(div_valid));
wire signed [4*width+11:0] Ux_pad = {{3{Ux[4*width]}}, Ux, 8'b0};
wire signed [4*width+11:0] Uy_pad = {{3{Uy[4*width]}}, Uy, 8'b0};
wire signed [4*width+11:0] shifted_x = Ux_pad >>> div_pos;
wire signed [4*width+11:0] shifted_y = Uy_pad >>> div_pos;
wire signed [11 : 0] result_x = (det[4*width])? -$signed(shifted_x[11 : 0]) : $signed(shifted_x[11 : 0]);
wire signed [11 : 0] result_y = (det[4*width])? -$signed(shifted_y[11 : 0]) : $signed(shifted_y[11 : 0]);
reg signed  [11:0] vx_reg, vy_reg;
wire corner;
Harris #(.width(width)) H1(.Ix2(Ix2_shift),.Iy2(Iy2_shift),.det(det),.corner(corner));
wire too_long = ($signed(result_x) > $signed(12'b010100000000) || 
                 $signed(result_x) < $signed(12'b101100000000) || 
                 $signed(result_y) > $signed(12'b010100000000) || 
                 $signed(result_y) < $signed(12'b101100000000));

always @(*) begin 
    if(~div_valid ||too_long || ~corner) begin 
        vx_reg = 8'b0;
    end
    else vx_reg = result_x;

    if(~div_valid || too_long || ~corner) begin 
        vy_reg = 8'b0;
    end
    else vy_reg = result_y;
end


// shift registers
integer j;
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin 
        for(j = 0; j < 14; j = j + 1) begin 
            img1[j] <= 0;
        end
        for(j = 0; j < 5; j = j + 1) begin 
            Ix[j] <= 0;
            It[j] <= 0;
        end
    end
    
    else begin
        for(j = 0; j <= 12; j = j + 1) begin 
            img1[j] <= img1[j + 1];
        end 
        img1[13] <= a_reg;

        if(Ix_shift) begin
            for(j = 0; j <= 3; j = j + 1) begin 
                Ix[j] <= Ix[j + 1];     
            end
            Ix[4] <= Ix_now;    
        end

        if(It_shift) begin
            for(j = 0; j <= 3; j = j + 1) begin 
                It[j] <= It[j + 1];     
            end
            It[4] <= It_now;    
        end
    end
end

// summaiton
reg start_valid;
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        Iy2  <= 0;
        Ix2  <= 0;
        IxIt <= 0;
        IyIt <= 0;
        IxIy <= 0;
        // Vx <= 0;
        // Vy <= 0;
        Vout <= 0;
        Ix2_IyIt_reg <= 0;
        Iy2_IxIt_reg <= 0;
        Ix2_Iy2_reg <= 0;
        IxIy_IyIt_reg <= 0;
        IxIy_IxIt_reg <= 0;
        IxIy2_reg <= 0;
        valid <= 0;
        start_valid <= 0;
        a_reg <= 0;
        b_reg <= 0;
    end 
    else begin
        // Vx<= vx_reg;
        // Vy<= vy_reg;
        a_reg <= a;
        b_reg <= b;
        if(col_reg == 3 && row_reg == 0) begin
            Vout <= vx_reg;
            if(start_valid) valid <= 1;
            else start_valid <= 1;
        end
        else if(col_reg == 4 && row_reg == 0) begin
            Vout <= vy_reg;
        end

        if(col_reg == 5 && row_reg == 0) begin
           valid <= 0;
        end

        Ix2_IyIt_reg <= Ix2_IyIt;
        Iy2_IxIt_reg <= Iy2_IxIt;
        Ix2_Iy2_reg <= Ix2_Iy2;
        IxIy_IyIt_reg <= IxIy_IyIt;
        IxIy_IxIt_reg <= IxIy_IxIt;
        IxIy2_reg <= IxIy2;
        if (col_reg == 6 && row_reg == 0) begin
            Iy2  <= 0;
            Ix2  <= 0;
            IxIt <= 0;
            IyIt <= 0;
            IxIy <= 0;
        end 
        else begin

            // 正常的累加邏輯
            if (Iy_en) begin
                Iy2  <= Iy2  + Iy_now2;
                IxIy <= IxIy + IxIy_now;
                IyIt <= IyIt + IyIt_now;
            end
            if (Ix_en) begin
                Ix2  <= Ix2  + Ix_now2;
                IxIt <= IxIt + IxIt_now;
            end
        end
    end
end


// input matrix index
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        row_reg <= 6;
        col_reg <= 6;
    end else begin

        if (col_reg == 6) begin // 0 到 6 代表 7 個數
            if(row_reg == 6) begin
                col_reg <= 0;
                row_reg <= 0;
            end
            else begin
                col_reg <= 0;
                row_reg <= row_reg + 1;
            end
        end
        else  begin
            col_reg <= col_reg + 1;
        end
    end    
end


endmodule

// Leading One Detector
module LOD #(
    parameter W = 45
)(
    input [W - 1 : 0] in,
    output [$clog2(W) - 1 : 0] pos,
    output valid
);
    localparam W_pow2 = 1 << $clog2(W);
    wire [W_pow2-1 : 0] in_pad;
    generate
        if(W_pow2 == W) begin: no_padding_zeros
            assign in_pad = in;
        end
        else begin: padding_zeros
            assign in_pad = {{(W_pow2 - W){1'b0}}, in};
        end

        if(W_pow2 == 2) begin: base_case
            assign valid = in_pad[1] | in_pad[0];
            assign pos = in_pad[1];
        end
        else begin: recursive_case
            wire left_valid, right_valid;
            wire [$clog2(W_pow2/2) - 1 : 0] left_pos, right_pos;

            LOD #(.W(W_pow2/2)) LOD_left(.in(in_pad[W_pow2 - 1 : W_pow2/2]), .pos(left_pos), .valid(left_valid));
            LOD #(.W(W_pow2/2)) LOD_right(.in(in_pad[W_pow2/2 - 1 : 0]), .pos(right_pos), .valid(right_valid));

            assign valid = left_valid | right_valid;
            assign pos = (left_valid)? {1'b1, left_pos} : {1'b0, right_pos};
        end
    endgenerate
endmodule
module Harris#(parameter  width = 8)(
    input [2*width-1:0] Ix2,
    input [2*width-1:0] Iy2,
    input [4*width:0] det,
    output corner
);
    wire signed [2*width:0] trace;

    assign trace = Ix2 + Iy2;

    wire signed [4*width+1:0] trace_sq;

    assign trace_sq = trace * trace;

    wire signed [4*width+1:0] R;
    assign R = det - (trace_sq >>> 4);

    reg signed [31:0] THRESHOLD = 32'd10000000;

    assign corner = (R > THRESHOLD);

endmodule