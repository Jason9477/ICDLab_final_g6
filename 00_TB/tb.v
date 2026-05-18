`define SDFFILE    "../02_SYN/LK_syn.sdf"
`timescale 1ns/10ps
`define CYCLE 10
`define HCYCLE (`CYCLE/2.0)

module tb;
    reg clk;
    reg rst_n;
    reg [7:0] a;
    reg [7:0] b;
    wire [11:0] Vout;
    reg [7:0] a_mem [0:97];
    reg [7:0] b_mem [0:97];
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
        always @(posedge clk) begin
        if (valid)
            $display("valid=1  Vout = %h", Vout);
    end
integer i;
    initial begin
        $readmemh("../00_TB/a.txt", a_mem);
        $readmemh("../00_TB/b.txt", b_mem);
        rst_n = 0; // Reset active

        #`CYCLE; // Wait for reset to be released
        in_en = 1;
        rst_n = 1; // Release reset
        for (i = 0; i < 98; i = i + 1) begin
                a = a_mem[i];
                b = b_mem[i];
                #`CYCLE;   // 一個 cycle
            end




        in_en=0;
        #300
        $finish; // End simulation
    end
    endmodule

