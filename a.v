`timescale 1ns/10ps
`define CYCLE 10
`define HCYCLE (`CYCLE/2.0)


module LK (
    input clk,
    input rst_n,
    input [7:0] a,
    input [7:0] b,
    output reg [15:0] c
);
    // reg [7:0] img1[0:48] ;
    reg [7:0] img1[0:13] ;
    reg [3:0] row_reg;
    reg [3:0] col_reg;
    // reg signed [8:0] Ix[0:24];
    reg signed [8:0] Ix[0:4];
    // reg signed [8:0] It[0:24];
    reg signed [8:0] It[0:4];
    // reg signed [8:0] Iy[0:24];
    // reg [5:0]counter ;
    reg [21:0] Ix2;
    reg [21:0] Iy2;
    reg signed [21:0] IxIy;
    reg signed [21:0] IxIt;
    reg signed [21:0] IyIt;
    reg signed [8:0] Ix_now ;
    reg signed [8:0] Iy_now ;
    reg signed [8:0] It_now;
    wire [15:0] Ix_now2 = Ix_now * Ix_now;
    wire [15:0] Iy_now2 = Iy_now * Iy_now;
    //================================沒用
    wire signed [8:0] Ix_0 = Ix[0];
    wire signed [8:0] Ix_1 = Ix[1];
    wire signed [8:0] Ix_2 = Ix[2];
    wire signed [8:0] Ix_3 = Ix[3];
    wire signed [8:0] Ix_4 = Ix[4];
    wire signed [8:0] Ix_5 = Ix[5];
    wire signed [8:0] Ix_6 = Ix[6];
    wire signed [8:0] Ix_7 = Ix[7];
    wire signed [8:0] Ix_8 = Ix[8]; 
    wire signed [8:0] Ix_9 = Ix[9];
    wire signed [8:0] Ix_10 = Ix[10];
    wire signed [8:0] Ix_11 = Ix[11];
    wire signed [8:0] Ix_12 = Ix[12];
    wire signed [8:0] Ix_13 = Ix[13];
    wire signed [8:0] Ix_14 = Ix[14];
    wire [7:0] img1_0 = img1[0];
    wire [7:0] img1_1 = img1[1];
    wire [7:0] img1_2 = img1[2];
    wire [7:0] img1_3 = img1[3];
    wire [7:0] img1_4 = img1[4];
    wire [7:0] img1_5 = img1[5];
    wire [7:0] img1_6 = img1[6];
    wire [7:0] img1_7 = img1[7];
    wire [7:0] img1_8 = img1[8];
    wire [7:0] img1_9 = img1[9];
    wire [7:0] img1_10 = img1[10];
    wire [7:0] img1_11 = img1[11];  
    wire [7:0] img1_12 = img1[12];
    wire [7:0] img1_13 = img1[13];
    wire [7:0] img1_14 = img1[14];
    wire [7:0] img1_15 = img1[15];
    wire [7:0] img1_16 = img1[16];
    wire [8:0] It_0 = It[0];
    wire [8:0] It_1 = It[1];
    wire [8:0] It_2 = It[2];
    wire [8:0] It_3 = It[3];
    wire [8:0] It_4 = It[4];
    wire [8:0] It_5 = It[5];
    wire [8:0] It_6 = It[6];
    wire [8:0] It_7 = It[7];
    wire [8:0] It_8 = It[8];
    wire [8:0] It_9 = It[9];
    wire [8:0] It_10 = It[10];
    wire [8:0] It_11 = It[11];  
    wire [8:0] It_12 = It[12];
    wire [8:0] It_13 = It[13];
    wire [8:0] It_14 = It[14];
    wire [8:0] It_15 = It[15];
    wire [8:0] It_16 = It[16];
    wire [8:0] Iy_0 = Iy[0];
    wire [8:0] Iy_1 = Iy[1];
    wire [8:0] Iy_2 = Iy[2];
    wire [8:0] Iy_3 = Iy[3];
    wire [8:0] Iy_4 = Iy[4];
    wire [8:0] Iy_5 = Iy[5];
    wire [8:0] Iy_6 = Iy[6];
    wire [8:0] Iy_7 = Iy[7];
    wire [8:0] Iy_8 = Iy[8];
    wire [8:0] Iy_9 = Iy[9];
    wire [8:0] Iy_10 = Iy[10];
    wire [8:0] Iy_11 = Iy[11];
    wire [8:0] Iy_12 = Iy[12];
    wire [8:0] Iy_13 = Iy[13];
    wire [8:0] Iy_14 = Iy[14];
    wire [8:0] Iy_15 = Iy[15];
    wire [8:0] Iy_16 = Iy[16];
//================================

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
wire signed [15:0] IxIt_now = Ix_now*It[4];
wire signed [15:0] IyIt_now = Iy_now*It[0];
wire signed [15:0] IxIy_now = Iy_now*Ix[0];

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
        $readmemh("input.txt", data_mem);
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

