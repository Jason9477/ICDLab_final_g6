`timescale 1ns/10ps
`define CYCLE 10
`define HCYCLE (`CYCLE/2.0)


module LK #(parameter width = 8)(
    input clk,
    input rst_n,
    input in_en,
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

wire Ix_shift = (col_reg !=0) && (row_reg !=0); //什麼時候要 shift Ix
wire Ix_en = Ix_shift && (col_reg !=1) && (row_reg !=6); //什麼時候要計算 Ix^2 IxIt
wire Iy_en = (col_reg !=6) && (col_reg !=0) && (row_reg !=0 && row_reg !=1); //什麼時候要計算 Iy^2 IxIy IyIt 
wire It_shift = (col_reg !=6) && (col_reg !=0) && (row_reg !=0); //什麼時候要 shift It

always @(*) begin
    Ix_now =  a - img1[12];
    Iy_now =  a - img1[0];
    It_now =  b - a;
end
// wire signed [15:0] IxIt_now = Ix_now*It[(row_reg-1)*5 + col_reg-2];
wire signed [2*width+1:0] IxIt_now = Ix_now*It[4];
wire signed [2*width+1:0] IyIt_now = Iy_now*It[0];
wire signed [2*width+1:0] IxIy_now = Iy_now*Ix[0];

// matrix multiplication
reg [2 : 0] mul_counter;
reg signed [2*width+6:0] mul_src;
wire [2*width+6:0] mul_abs [0:4];

assign mul_abs[0] = Ix2   [2*width+6] ? -Ix2   : Ix2;
assign mul_abs[1] = Iy2   [2*width+6] ? -Iy2   : Iy2;
assign mul_abs[2] = IxIy  [2*width+6] ? -IxIy  : IxIy;
assign mul_abs[3] = IxIt  [2*width+6] ? -IxIt  : IxIt;
assign mul_abs[4] = IyIt  [2*width+6] ? -IyIt  : IyIt;
wire [$clog2(2*width+7) - 1 : 0] mul_pos[0:4];
wire [$clog2(2*width+7) - 1 : 0] pos1 = mul_pos[0];
wire [$clog2(2*width+7) - 1 : 0] pos2 = mul_pos[1];
wire [$clog2(2*width+7) - 1 : 0] pos3 = mul_pos[2];
wire [$clog2(2*width+7) - 1 : 0] pos4 = mul_pos[3];
wire [$clog2(2*width+7) - 1 : 0] pos5 = mul_pos[4];
wire [$clog2(2*width+7) - 1 : 0] mul_pos_new;
reg [$clog2(2*width+7) - 1 : 0] mul_pos_buffer;
wire mul_valid;
LOD #(.W(2*width+7)) L_mul0 (.in(mul_abs[0]), .pos(mul_pos[0]), .valid(mul_valid));
LOD #(.W(2*width+7)) L_mul1 (.in(mul_abs[1]), .pos(mul_pos[1]), .valid(mul_valid));
LOD #(.W(2*width+7)) L_mul2 (.in(mul_abs[2]), .pos(mul_pos[2]), .valid(mul_valid));
LOD #(.W(2*width+7)) L_mul3 (.in(mul_abs[3]), .pos(mul_pos[3]), .valid(mul_valid));
LOD #(.W(2*width+7)) L_mul4 (.in(mul_abs[4]), .pos(mul_pos[4]), .valid(mul_valid));
reg [$clog2(2*width+7)-1:0] max_val;
integer i;
always @(*) begin
    max_val = mul_pos[0];
    
    for(i=1;i<5;i=i+1) begin
        if(mul_pos[i] > max_val)
            max_val = mul_pos[i];
    end
end
always @(posedge clk or negedge rst_n) begin 
    if (~rst_n) begin
        mul_pos_buffer <= 0;
    end
    else begin 
        if (col_reg == 6 && row_reg == 6) begin
            mul_pos_buffer <= max_val;
        end

    end
end

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
        img1[13] <= a;

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
    end 
    else begin
        // Vx<= vx_reg;
        // Vy<= vy_reg;
        if(col_reg == 1 && row_reg == 0) begin
            Vout <= vx_reg;
            if(start_valid) valid <= 1;
            else start_valid <= 1;
        end
        else if(col_reg == 2 && row_reg == 0) begin
            Vout <= vy_reg;
        end

        if(col_reg == 3 && row_reg == 0) begin
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
        row_reg <= 0;
        col_reg <= 0;
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

    reg signed [31:0] THRESHOLD = 32'd1000000;

    assign corner = (R > THRESHOLD);

endmodule
`timescale 1ns/10ps
`define CYCLE 10
`define HCYCLE 5

module tb;

reg clk;
reg rst_n;
reg [7:0] a,b;
reg in_en;

wire valid;
wire [11:0] Vout;

reg [7:0] a_mem [0:18000];
reg [7:0] b_mem [0:18000];
reg signed [11:0] answer_mem [0:18000];

integer i;
integer ans_idx;
integer error_cnt;

LK uut(
    .clk(clk),
    .rst_n(rst_n),
    .a(a),
    .b(b),
    .in_en(in_en),
    .valid(valid),
    .Vout(Vout)
);

//////////////////////////////////////////////////
// dump
//////////////////////////////////////////////////

initial begin
    $dumpfile("LK.vcd");
    $dumpvars();
end


//////////////////////////////////////////////////
// clock
//////////////////////////////////////////////////

initial begin
    clk = 0;
    a   = 0;
    b   = 0;
    in_en = 0;
end

always #`HCYCLE clk = ~clk;


//////////////////////////////////////////////////
// compare variables
//////////////////////////////////////////////////

reg signed [11:0] prev_Vout;
reg prev_valid;

real vout1_decimal;
real vout2_decimal;
real ans1_decimal;
real ans2_decimal;


//////////////////////////////////////////////////
// compare output with answer
//////////////////////////////////////////////////
always @(posedge clk) begin

    if(valid) begin
        
        if(prev_valid) begin
            $display("\n===== Compare #%0d ~ #%0d =====",ans_idx,ans_idx+1);
            // Q3.8 -> decimal
            vout1_decimal = $signed(prev_Vout)/256.0;
            vout2_decimal = $signed(Vout)/256.0;

            ans1_decimal =
                answer_mem[ans_idx]/256.0;

            ans2_decimal =
                answer_mem[ans_idx+1]/256.0;


            /////////////////////////////////////
            // compare prev_Vout
            /////////////////////////////////////

            if($signed(prev_Vout)
                != answer_mem[ans_idx]) begin
                
                error_cnt = error_cnt + 1;

                $display("\nERROR idx=%0d",
                         ans_idx);

                $display(
                "Expected=%b (%f)",
                answer_mem[ans_idx],
                ans1_decimal);

                $display(
                "Got     =%b (%f)",
                prev_Vout,
                vout1_decimal);

            end


            /////////////////////////////////////
            // compare current Vout
            /////////////////////////////////////

            if($signed(Vout) != answer_mem[ans_idx+1]) begin
                
                error_cnt = error_cnt + 1;

                $display("\nERROR idx=%0d",
                         ans_idx+1);

                $display(
                "Expected=%b (%f)",
                answer_mem[ans_idx+1],
                ans2_decimal);

                $display(
                "Got     =%b (%f)",
                Vout,
                vout2_decimal);

            end


            ans_idx = ans_idx + 2;

        end

        prev_Vout  <= Vout;
        prev_valid <= 1;

    end

    else begin
        prev_valid <= 0;
    end

end


//////////////////////////////////////////////////
// stimulus
//////////////////////////////////////////////////

initial begin

    $readmemh("a.txt",a_mem);
    $readmemh("b.txt",b_mem);

    // answer.txt 一行一個12bit hex
    $readmemh("answer.txt",answer_mem);

    rst_n = 0;
    ans_idx = 0;
    error_cnt = 0;

    #`CYCLE;
    rst_n = 1;
    in_en = 1;


    for(i=0;i<18001;i=i+1) begin

        a = a_mem[i];
        b = b_mem[i];

        #`CYCLE;

    end


    in_en = 0;

    #(6*`CYCLE);

    //////////////////////////////////////////
    // summary
    //////////////////////////////////////////

    $display("");
    $display("===============");
    $display("Total Error=%0d",
             error_cnt);

    if(error_cnt==0)
        $display("ALL PASS");
    else
        $display("FAIL");

    $display("===============");

    $finish;

end

endmodule