module divide(
    input wire clk,
    input wire rst,
    input wire enable,
    input wire [14 : 0] up,     // 6.9
    input wire [15 : 0] down,   // 7.9
    output reg [24 : 0] out    // 15.10    
);
    reg [4 : 0] counter;
    wire [24 : 0] in;
    reg [24 : 0] A;
    wire ans;

    assign in = {up, 10'b0};
    assign ans = (A >= down)? 1'b1 : 1'b0;
    always @(posedge clk, posedge rst) begin 
        if(rst) begin 
            counter <= 24;
            A <= 0;
            out <= 0;
        end
        else begin 
            if(enable) begin 
                counter <= counter - 1;
                A[0] <= (counter <= 24)? in[counter] : 0;
                A[24 : 1] <= A - ((ans)? down : 0);
                out[0] <= ans;
                out[24 : 1] <= out[23 : 0];
            end

            else begin 
                counter <= 24;
                A <= 0;
                out <= 0;
            end
            
        end
    end

endmodule
