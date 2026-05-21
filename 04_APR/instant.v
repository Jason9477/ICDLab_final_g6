

module CHIP ( clk, rst_n, a, b, valid, Vout);
  input [7:0] a;
  input [7:0] b;
  output  valid;
  output [11:0] Vout;
  input clk, rst_n;

  
  
  wire [7:0] i_data_a_i;
  wire [7:0] i_data_b_i;
  wire  i_valid_o;
  wire [11:0] i_data_o;
  wire i_clk_p_i, i_reset_n_i;
  wire n_logic0,n_logic1;
  LK LK_in( .clk(i_clk_p_i), .rst_n(i_reset_n_i), .a(i_data_a_i), .b(i_data_b_i), .valid(i_valid_o), .Vout(i_data_o) );
  
  TIE0 ipad_n_logic0(.O(n_logic0));
  TIE1 ipad_n_logic1(.O(n_logic1));
  XMD ipad_clk_p_i (.O(i_clk_p_i), .I(clk), .PU(n_logic0), .PD(n_logic0), .SMT(n_logic0));
  XMD ipad_reset_n_i (.O(i_reset_n_i), .I(rst_n), .PU(n_logic0), .PD(n_logic0), .SMT(n_logic0));
  XMD ipad_data_a_i_0 (.O(i_data_a_i[0]), .I(a[0]), .PU(n_logic0), .PD(n_logic0), .SMT(n_logic0));
  XMD ipad_data_a_i_1 (.O(i_data_a_i[1]), .I(a[1]), .PU(n_logic0), .PD(n_logic0), .SMT(n_logic0));
  XMD ipad_data_a_i_2 (.O(i_data_a_i[2]), .I(a[2]), .PU(n_logic0), .PD(n_logic0), .SMT(n_logic0));
  XMD ipad_data_a_i_3 (.O(i_data_a_i[3]), .I(a[3]), .PU(n_logic0), .PD(n_logic0), .SMT(n_logic0));
  XMD ipad_data_a_i_4 (.O(i_data_a_i[4]), .I(a[4]), .PU(n_logic0), .PD(n_logic0), .SMT(n_logic0));
  XMD ipad_data_a_i_5 (.O(i_data_a_i[5]), .I(a[5]), .PU(n_logic0), .PD(n_logic0), .SMT(n_logic0));
  XMD ipad_data_a_i_6 (.O(i_data_a_i[6]), .I(a[6]), .PU(n_logic0), .PD(n_logic0), .SMT(n_logic0));
  XMD ipad_data_a_i_7 (.O(i_data_a_i[7]), .I(a[7]), .PU(n_logic0), .PD(n_logic0), .SMT(n_logic0));
  XMD ipad_data_b_i_0 (.O(i_data_b_i[0]), .I(b[0]), .PU(n_logic0), .PD(n_logic0), .SMT(n_logic0));
  XMD ipad_data_b_i_1 (.O(i_data_b_i[1]), .I(b[1]), .PU(n_logic0), .PD(n_logic0), .SMT(n_logic0));
  XMD ipad_data_b_i_2 (.O(i_data_b_i[2]), .I(b[2]), .PU(n_logic0), .PD(n_logic0), .SMT(n_logic0));
  XMD ipad_data_b_i_3 (.O(i_data_b_i[3]), .I(b[3]), .PU(n_logic0), .PD(n_logic0), .SMT(n_logic0));
  XMD ipad_data_b_i_4 (.O(i_data_b_i[4]), .I(b[4]), .PU(n_logic0), .PD(n_logic0), .SMT(n_logic0));
  XMD ipad_data_b_i_5 (.O(i_data_b_i[5]), .I(b[5]), .PU(n_logic0), .PD(n_logic0), .SMT(n_logic0));
  XMD ipad_data_b_i_6 (.O(i_data_b_i[6]), .I(b[6]), .PU(n_logic0), .PD(n_logic0), .SMT(n_logic0));
  XMD ipad_data_b_i_7 (.O(i_data_b_i[7]), .I(b[7]), .PU(n_logic0), .PD(n_logic0), .SMT(n_logic0));
  
  
  YA2GSD ipad_data_o_0 (.O(Vout[0]), .I(i_data_o[0]), .E(n_logic1), .E2(n_logic0), .E4(n_logic0), .E8(n_logic0), .SR(n_logic0));
  YA2GSD ipad_data_o_1 (.O(Vout[1]), .I(i_data_o[1]), .E(n_logic1), .E2(n_logic0), .E4(n_logic0), .E8(n_logic0), .SR(n_logic0));
  YA2GSD ipad_data_o_2 (.O(Vout[2]), .I(i_data_o[2]), .E(n_logic1), .E2(n_logic0), .E4(n_logic0), .E8(n_logic0), .SR(n_logic0));
  YA2GSD ipad_data_o_3 (.O(Vout[3]), .I(i_data_o[3]), .E(n_logic1), .E2(n_logic0), .E4(n_logic0), .E8(n_logic0), .SR(n_logic0));
  YA2GSD ipad_data_o_4 (.O(Vout[4]), .I(i_data_o[4]), .E(n_logic1), .E2(n_logic0), .E4(n_logic0), .E8(n_logic0), .SR(n_logic0));
  YA2GSD ipad_data_o_5 (.O(Vout[5]), .I(i_data_o[5]), .E(n_logic1), .E2(n_logic0), .E4(n_logic0), .E8(n_logic0), .SR(n_logic0));
  YA2GSD ipad_data_o_6 (.O(Vout[6]), .I(i_data_o[6]), .E(n_logic1), .E2(n_logic0), .E4(n_logic0), .E8(n_logic0), .SR(n_logic0));
  YA2GSD ipad_data_o_7 (.O(Vout[7]), .I(i_data_o[7]), .E(n_logic1), .E2(n_logic0), .E4(n_logic0), .E8(n_logic0), .SR(n_logic0));
  YA2GSD ipad_data_o_8 (.O(Vout[8]), .I(i_data_o[8]), .E(n_logic1), .E2(n_logic0), .E4(n_logic0), .E8(n_logic0), .SR(n_logic0));
  YA2GSD ipad_data_o_9 (.O(Vout[9]), .I(i_data_o[9]), .E(n_logic1), .E2(n_logic0), .E4(n_logic0), .E8(n_logic0), .SR(n_logic0));
  YA2GSD ipad_data_o_10 (.O(Vout[10]), .I(i_data_o[10]), .E(n_logic1), .E2(n_logic0), .E4(n_logic0), .E8(n_logic0), .SR(n_logic0));
  YA2GSD ipad_data_o_11 (.O(Vout[11]), .I(i_data_o[11]), .E(n_logic1), .E2(n_logic0), .E4(n_logic0), .E8(n_logic0), .SR(n_logic0));
  YA2GSD ipad_valid_o (.O(valid), .I(i_valid_o), .E(n_logic1), .E2(n_logic0), .E4(n_logic0), .E8(n_logic0), .SR(n_logic0));

endmodule

