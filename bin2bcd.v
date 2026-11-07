module bin2bcd #(
    parameter BIN_W  = 7,
    parameter DIGITS = 2
)(
    input  wire [BIN_W-1:0]    bin,
    output reg  [4*DIGITS-1:0] bcd
);

    integer i, d;
    reg [4*DIGITS-1:0] s;

    always @* begin
        s = {4*DIGITS{1'b0}};
        for (i = BIN_W - 1; i >= 0; i = i - 1) begin

            for (d = 0; d < DIGITS; d = d + 1) begin
                if (s[4*d +: 4] >= 4'd5)
                    s[4*d +: 4] = s[4*d +: 4] + 4'd3;
            end

            s = {s[4*DIGITS-2:0], bin[i]};
        end
        bcd = s;
    end

endmodule
