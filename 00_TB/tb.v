
module tb;
    reg clk;
    reg rst_n;
    reg [7:0] a;
    reg [7:0] b;
    wire [11:0] Vout;
    reg [7:0] a_mem [0:9700];
    reg [7:0] b_mem [0:9700];
    reg in_en;
    wire valid;
    
    LK uut (
        .clk(clk),
        .rst_n(rst_n),
        .a(a),
        .b(b),
        .in_en(in_en),
        .valid(valid),
        .Vout(Vout)
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

reg [11:0] prev_Vout;
reg prev_valid;

// 為了方便計算與列印，宣告兩個實數（real）變數來存放轉換後的十進位數值
real vout1_decimal;
real vout2_decimal;

always @(posedge clk) begin
    if (valid) begin
        if (prev_valid) begin
            // 💡 核心轉換邏輯：
            // 1. 先用 [11:0] 截取後 12 位
            // 2. 用 $signed() 將其視為 12-bit 二補數負數
            // 3. 除以 256.0 (也就是 2^8)，把小數點往左強行推 8 位，還原成真實的十進位實數
            vout1_decimal = $signed(prev_Vout[11:0]) / 256.0;
            vout2_decimal = $signed(Vout[11:0])     / 256.0;

            // 🎯 同時印出原本的二進位，以及轉換後的人類直觀十進位（保留 7 位小數）
            $display("Vout1_bin=%b  Vout2_bin=%b", prev_Vout[11:0], Vout[11:0]);
            $display("Vout1_dec=%.8f  Vout2_dec=%.8f", vout1_decimal, vout2_decimal);
            $display("---------------------------------------------------------");
        end

        prev_Vout  <= Vout;   // 儲存這次的數值
        prev_valid <= 1;
    end
    else begin
        prev_valid <= 0;     // 中斷連續 valid
    end
end

integer i;
    initial begin
        $readmemh("a.txt", a_mem);
        $readmemh("b.txt", b_mem);
        rst_n = 0; // Reset active

        #`CYCLE; // Wait for reset to be released
        in_en = 1;
        rst_n = 1; // Release reset
        for (i = 0; i < 9701; i = i + 1) begin
                a = a_mem[i];
                b = b_mem[i];
                #`CYCLE;   // 一個 cycle
            end




        in_en=0;
        #300
        $finish; // End simulation
    end
    endmodule

