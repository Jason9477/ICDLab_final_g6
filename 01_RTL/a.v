`timescale 1ns/10ps
`define CYCLE 10
`define HCYCLE (`CYCLE/2.0)


module LK #(parameter width = 8)(
    input clk,
    input rst_n,
    input [width-1:0] a,
    input [width-1:0] b,
    output reg [7:0] Vx,
    output reg [7:0] Vy
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


// wire Ix_en = (col_reg !=1) && (col_reg !=0) && (row_reg !=0 && row_reg !=6); //什麼時候要計算 Ix
// wire Iy_en = (col_reg !=6) && (col_reg !=0) && (row_reg !=0 && row_reg !=1); //什麼時候要計算 Iy
// wire It_en = (col_reg !=6) && (col_reg !=0) && (row_reg !=0 && row_reg !=6); //什麼時候要計算 It
wire Ix_shift = (col_reg !=0) && (row_reg !=0); //什麼時候要 shift Ix
wire Ix_en = Ix_shift && (col_reg !=1) && (row_reg !=6); //什麼時候要計算 Ix^2 IxIt
wire Iy_en = (col_reg !=6) && (col_reg !=0) && (row_reg !=0 && row_reg !=1); //什麼時候要計算 Iy^2 IxIy IyIt 
wire It_shift = (col_reg !=6) && (col_reg !=0) && (row_reg !=0); //什麼時候要 shift It

always @(*) begin
    // Ix_now =  a - img1[(row_reg)*7 + col_reg - 2];
    Ix_now =  a - img1[12];
end
always @(*) begin
    // Iy_now =  a - img1[(row_reg-2)*7 + col_reg ];
    Iy_now =  a - img1[0];
end
always @(*) begin
    It_now =  b - a;
end
// wire signed [15:0] IxIt_now = Ix_now*It[(row_reg-1)*5 + col_reg-2];
wire signed [2*width+1:0] IxIt_now = Ix_now*It[4];
wire signed [2*width+1:0] IyIt_now = Iy_now*It[0];
wire signed [2*width+1:0] IxIy_now = Iy_now*Ix[0];

wire signed[4*width+13:0] Ix2_ext = Ix2;
wire signed[4*width+13:0] Iy2_ext = Iy2;
wire signed [4*width+13:0] Ux = -(Iy2_ext * IxIt) + (IxIy * IyIt); //-(197316*36516)+(-156086*-15534) =-4780551168
wire signed [4*width+13:0] Uy = -(Ix2_ext * IyIt)+ (IxIy * IxIt);//-(341126*-15534) + (-156086*36516)
wire signed [4*width+13:0] det = (Ix2_ext*Iy2) - (IxIy * IxIy);
wire [4*width+12:0] det_abs = det[4*width+13]? (-det) : det;
wire [$clog2(4*width+13)-1 : 0] LOD_pos;
wire LOD_valid;
LOD #(.W(4*width+13)) L1(.in(det_abs), .pos(LOD_pos), .valid(LOD_valid));
wire signed [4*width+20:0] Ux_pad0 = {{4{Ux[4*width+13]}}, Ux, 3'b0};
wire signed [4*width+20:0] Uy_pad0 = {{4{Uy[4*width+13]}}, Uy, 3'b0};
wire signed [7 : 0] result_x = (det[4*width+13])? -signed(Ux_pad0[LOD_pos + 4 -: 8]) : signed(Ux_pad0[LOD_pos + 4 -: 8]);
wire signed [7 : 0] result_y = (det[4*width+13])? -signed(Uy_pad0[LOD_pos + 4 -: 8]) : signed(Uy_pad0[LOD_pos + 4 -: 8]);
always @(*) begin 
    if(~LOD_valid || result_x > $signed(8'b0101_0000) || result_x < $signed(8'b1011_0000)) begin 
        Vx = 8'b0;
    end
    else Vx = result_x;

    if(~LOD_valid || result_x > $signed(8'b0101_0000) || result_x < $signed(8'b1011_0000)) begin 
        Vy = 8'b0;
    end
    else Vy = result_y;
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
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        Iy2 <= 0;
        Ix2 <= 0;
        IxIt <= 0;
        IyIt <= 0;
        IxIy <= 0;
    end else begin
    if(Iy_en) begin
            Iy2 <= Iy2 + Iy_now2;
            IxIy <= IxIy + IxIy_now;
            IyIt <= IyIt + IyIt_now;
        end
    if(Ix_en) begin
            Ix2 <= Ix2 + Ix_now2;
            IxIt<= IxIt + IxIt_now;
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
        col_reg <= 0;
            if (row_reg == 6) begin
                row_reg <= 0;
            end else begin
                row_reg <= row_reg + 1;
            end
        end else begin
            col_reg <= col_reg + 1;
        end
    end    
end

endmodule

// Leading One Detector
module LOD #(
    parameter W = 11
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


module tb;
    reg clk;
    reg rst_n;
    reg [7:0] a;
    reg [7:0] b;
    wire [15:0] c;
    reg [15:0] data_mem [0:48];
    LK uut (
        .clk(clk),
        .rst_n(rst_n),
        .a(a),
        .b(b),
        .c(c)
    );
    initial begin
        $dumpfile("LK.vcd");
        $dumpvars();
        // $fsdbDumpfile("LK.fsdb");
        // $fsdbDumpvars("+mda", tb, uut);

    end
    initial begin
        clk = 0;
        a=0;
        b=0;
    end
    always #`HCYCLE clk = ~clk; // Clock generation
integer i;
    initial begin
        $readmemh("input_combined.txt", data_mem);
        rst_n = 0; // Reset active

        #`CYCLE; // Wait for reset to be released

        rst_n = 1; // Release reset
        for (i = 0; i < 49; i = i + 1) begin
                {a, b} = data_mem[i];
                #`CYCLE;   // 一個 cycle
            end
        





        $finish; // End simulation
    end
    endmodule

