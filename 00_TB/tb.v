`define SDFFILE    "../02_SYN/LK_syn.sdf"
`timescale 1ns/10ps
`define CYCLE 10
`define HCYCLE (`CYCLE/2.0)
`define N  74529


module tb;

reg clk;
reg rst_n;
reg [7:0] a,b;

wire valid;
wire [11:0] Vout;

reg [7:0] a_mem [0:(`N-1)];
reg [7:0] b_mem [0:(`N-1)];
reg signed [11:0] answer_mem [0:(`N-1)];

integer i;
integer ans_idx;
integer error_cnt;

LK uut(
    .clk(clk),
    .rst_n(rst_n),
    .a(a),
    .b(b),
    .valid(valid),
    .Vout(Vout)
);

//////////////////////////////////////////////////
// dump
//////////////////////////////////////////////////

initial begin
    $dumpfile("LK.vcd");
    $dumpvars();
    // $fsdbDumpfile("LK.fsdb");
    // $fsdbDumpvars("+mda", tb, uut);
end


//////////////////////////////////////////////////
// clock
//////////////////////////////////////////////////

initial begin
    clk = 0;
    a   = 0;
    b   = 0;
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
            //  $display(
            //     "Expected=%b (%f)",
            //     answer_mem[ans_idx+1],
            //     ans2_decimal);
            //     $display(
            //     "Got     =%b (%f)",
            //     Vout,
            //     vout2_decimal);
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
                !== answer_mem[ans_idx]) begin
               
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

            if($signed(Vout) !== answer_mem[ans_idx+1]) begin
                
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

    $readmemh("../00_TB/a_kitti.txt",a_mem);
    $readmemh("../00_TB/b_kitti.txt",b_mem);

    // answer.txt 一行一個12bit hex
    $readmemh("../00_TB/ans_kitti.txt",answer_mem);

    rst_n = 0;
    ans_idx = 0;
    error_cnt = 0;

    #(`CYCLE*0.4);
    rst_n = 1;


    for(i=0;i<`N;i=i+1) begin

        a = a_mem[i];
        b = b_mem[i];

        #`CYCLE;

    end



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