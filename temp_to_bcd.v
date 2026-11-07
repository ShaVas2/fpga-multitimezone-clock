module temp_to_bcd (
    input  wire               clk,
    input  wire               rst,
    input  wire signed [12:0] temp_raw,
    output reg                neg,
    output reg         [15:0] temp_bcd
);

    wire        sign = temp_raw[12];
    wire [13:0] ext  = {temp_raw[12], temp_raw};
    wire [13:0] mag  = sign ? (~ext + 14'd1) : ext;

    wire [17:0] scaled = {1'b0, mag, 3'b000} + {3'b000, mag, 1'b0} + 18'd8;

    reg  [11:0] tenths_r;
    reg         sign_r;

    always @(posedge clk) begin
        if (rst) begin
            tenths_r <= 12'd0;
            sign_r   <= 1'b0;
        end else begin
            tenths_r <= scaled[15:4];
            sign_r   <= sign;
        end
    end

    reg  [11:0] bin_sh;
    reg  [15:0] bcd_sh;
    reg  [3:0]  cnt;
    reg         sign_hold;

    function [3:0] add3;
        input [3:0] d;
        begin
            add3 = (d >= 4'd5) ? d + 4'd3 : d;
        end
    endfunction

    wire [15:0] bcd_adj = {add3(bcd_sh[15:12]), add3(bcd_sh[11:8]),
                           add3(bcd_sh[7:4]),   add3(bcd_sh[3:0])};

    always @(posedge clk) begin
        if (rst) begin
            bin_sh    <= 12'd0;
            bcd_sh    <= 16'd0;
            cnt       <= 4'd0;
            sign_hold <= 1'b0;
            neg       <= 1'b0;
            temp_bcd  <= 16'd0;
        end else if (cnt == 4'd0) begin

            bin_sh    <= tenths_r;
            bcd_sh    <= 16'd0;
            sign_hold <= sign_r;
            cnt       <= 4'd1;
        end else begin

            bcd_sh <= {bcd_adj[14:0], bin_sh[11]};
            bin_sh <= {bin_sh[10:0], 1'b0};

            if (cnt == 4'd12) begin

                temp_bcd <= {bcd_adj[14:0], bin_sh[11]};
                neg      <= sign_hold;
                cnt      <= 4'd0;
            end else begin
                cnt <= cnt + 1'b1;
            end
        end
    end

endmodule
