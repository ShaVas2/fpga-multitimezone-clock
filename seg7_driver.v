module seg7_driver (
    input  wire        clk,
    input  wire        rst,
    input  wire        scan_tick,
    input  wire [39:0] chars,
    input  wire [7:0]  dp_on,
    output reg  [6:0]  seg_n,
    output reg         dp_n,
    output reg  [7:0]  an_n
);

    function [6:0] decode;
        input [4:0] code;
        begin
            case (code)
                5'd0:  decode = 7'h3F;
                5'd1:  decode = 7'h06;
                5'd2:  decode = 7'h5B;
                5'd3:  decode = 7'h4F;
                5'd4:  decode = 7'h66;
                5'd5:  decode = 7'h6D;
                5'd6:  decode = 7'h7D;
                5'd7:  decode = 7'h07;
                5'd8:  decode = 7'h7F;
                5'd9:  decode = 7'h6F;
                5'd10: decode = 7'h00;
                5'd11: decode = 7'h40;
                5'd12: decode = 7'h39;
                5'd13: decode = 7'h63;
                5'd14: decode = 7'h54;
                5'd15: decode = 7'h78;
                5'd16: decode = 7'h73;
                5'd17: decode = 7'h38;
                5'd18: decode = 7'h7C;
                5'd19: decode = 7'h79;
                5'd20: decode = 7'h50;
                5'd21: decode = 7'h76;
                5'd22: decode = 7'h77;
                5'd23: decode = 7'h5C;
                5'd24: decode = 7'h71;
                5'd25: decode = 7'h3E;
                5'd26: decode = 7'h5E;
                5'd27: decode = 7'h74;
                5'd28: decode = 7'h31;
                5'd29: decode = 7'h0E;
                default: decode = 7'h00;
            endcase
        end
    endfunction

    reg  [2:0] idx;
    wire [4:0] cur_char = chars[idx*5 +: 5];
    wire       cur_dp   = dp_on[idx];

    always @(posedge clk) begin
        if (rst)
            idx <= 3'd0;
        else if (scan_tick)
            idx <= idx + 1'b1;
    end

    always @(posedge clk) begin
        if (rst) begin
            seg_n <= 7'h7F;
            dp_n  <= 1'b1;
            an_n  <= 8'hFF;
        end else begin
            seg_n <= ~decode(cur_char);
            dp_n  <= ~cur_dp;
            an_n  <= ~(8'b0000_0001 << idx);
        end
    end

endmodule
