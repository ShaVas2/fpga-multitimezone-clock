module seconds_bar (
    input  wire        clk,
    input  wire        rst,
    input  wire [5:0]  sec,
    output reg  [15:0] bar
);

    wire [15:0] bar_c;

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : g_led

            localparam integer T = ((i + 1) * 60 + 15) / 16 - 1;
            assign bar_c[i] = (sec >= T);
        end
    endgenerate

    always @(posedge clk) begin
        if (rst)
            bar <= 16'h0000;
        else
            bar <= bar_c;
    end

endmodule
