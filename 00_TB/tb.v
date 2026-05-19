
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
    // $dumpfile("LK.vcd");
    // $dumpvars();
    $fsdbDumpfile("LK.fsdb");
    $fsdbDumpvars("+mda", tb, uut);
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