module reciprocal #(
    parameter bits = 27,
    parameter bits_int = 11,
    parameter bits_dec = 16
)(
    input [bits - 1 : 0] sum,
    output [bits_dec : 0] recip  // 1位整數 + bits_dec(16) 位小數   (1.16)
);
    // 第一個 1 一定會出現在小數點下第一位(含)以上的位數
    wire [$clog2(bits_int) - 1 : 0] pos;            // pos = 0 代表是整數最低位 (pos: 0~10)
    wire [$clog2(bits_int + 1) - 1 : 0] pos_real;   // pos_real = 0 代表是小數點下第一位 (pos: 0~11)
    wire valid;
    LOD #(
        .W(bits_int)
    ) LOD_tree (
        .in(sum[bits - 1 : bits_dec]),  // 只拿整數位去檢查，如果回來 valid 是 0，代表第一個 1 在小數點下第一位 
        .pos(pos), 
        .valid(valid)
    );

    assign pos_real = (valid)? (pos + 1) : 0;
    
    reg [11 : 0] a;        // 0.12
    reg [bits_dec : 0] b;  // 1位整數 + bits_dec(16) 位小數 (1.16)
    always @(*) begin 
        case(sum[(bits_dec + pos_real - 2) -: 5]) 
            5'd0: {a, b} = {12'hf84, 17'h10000};
            5'd1: {a, b} = {12'he9a, 17'h0f83e};
            5'd2: {a, b} = {12'hdc5, 17'h0f0f1};
            5'd3: {a, b} = {12'hd01, 17'h0ea0f};
            5'd4: {a, b} = {12'hc4d, 17'h0e38e};
            5'd5: {a, b} = {12'hba7, 17'h0dd68};
            5'd6: {a, b} = {12'hb0e, 17'h0d794};
            5'd7: {a, b} = {12'ha81, 17'h0d20d};
            5'd8: {a, b} = {12'h9fe, 17'h0cccd};
            5'd9: {a, b} = {12'h984, 17'h0c7ce};
            5'd10: {a, b} = {12'h912, 17'h0c30c};
            5'd11: {a, b} = {12'h8a9, 17'h0be83};
            5'd12: {a, b} = {12'h846, 17'h0ba2f};
            5'd13: {a, b} = {12'h7ea, 17'h0b60b};
            5'd14: {a, b} = {12'h794, 17'h0b216};
            5'd15: {a, b} = {12'h743, 17'h0ae4c};
            5'd16: {a, b} = {12'h6f7, 17'h0aaab};
            5'd17: {a, b} = {12'h6b0, 17'h0a72f};
            5'd18: {a, b} = {12'h66d, 17'h0a3d7};
            5'd19: {a, b} = {12'h62e, 17'h0a0a1};
            5'd20: {a, b} = {12'h5f2, 17'h09d8a};
            5'd21: {a, b} = {12'h5ba, 17'h09a91};
            5'd22: {a, b} = {12'h584, 17'h097b4};
            5'd23: {a, b} = {12'h552, 17'h094f2};
            5'd24: {a, b} = {12'h522, 17'h09249};
            5'd25: {a, b} = {12'h4f5, 17'h08fb8};
            5'd26: {a, b} = {12'h4ca, 17'h08d3e};
            5'd27: {a, b} = {12'h4a1, 17'h08ad9};
            5'd28: {a, b} = {12'h47a, 17'h08889};
            5'd29: {a, b} = {12'h455, 17'h0864c};
            5'd30: {a, b} = {12'h432, 17'h08421};
            5'd31: {a, b} = {12'h410, 17'h08208};
            default: {a, b} = {12'h000, 17'h00000};
        endcase
    end

    // b>>16 - a>>12 * sum[bits_dec + pos_real - 6 : bits_dec + pos_real - 15]>>15
    wire [21 : 0] delta;  // a: 12位(0.12)；sum[bits_dec + pos_real - 7 -: 10]: 10位 (小數點下15位 0.00000{10位})
    wire [bits_dec : 0] result;

    // assign delta = a * sum[bits_dec + pos_real - 6 : bits_dec + pos_real - 15];    // 會報錯：Error: Range must be bounded by constant expressions.
    assign delta = a * sum[(bits_dec + pos_real - 7) -: 10];    // 0.00000{22位}
    assign result = b - delta[21 : 11]; // 只取 delta 的前 11 位    // 1.16
    assign recip = (pos_real == 0)? (result << 1) : (result >> (pos_real - 1));
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
reg [26:0] sum;
wire [16:0] recip;
reciprocal r(.sum(sum),.recip(recip));
    initial begin
        $dumpfile("LK.vcd");
        $dumpvars();
        // $fsdbDumpfile("LK.fsdb");
        // $fsdbDumpvars("+mda", tb, uut);

    end

initial begin
    sum=20<<16;
    #50
    $finish;
end
endmodule


