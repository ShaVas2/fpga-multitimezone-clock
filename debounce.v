module debounce #(
    parameter WIDTH       = 1,
    parameter CLK_HZ      = 100_000_000,
    parameter DEBOUNCE_MS = 10
)(
    input  wire             clk,
    input  wire             rst,
    input  wire [WIDTH-1:0] din,
    output wire [WIDTH-1:0] level,
    output wire [WIDTH-1:0] rise
);

    function integer clog2;
        input integer v;
        integer t;
        begin
            clog2 = 0;
            for (t = v - 1; t > 0; t = t >> 1)
                clog2 = clog2 + 1;
        end
    endfunction

    localparam integer CNT_MAX = (CLK_HZ / 1000) * DEBOUNCE_MS;
    localparam         CW      = (clog2(CNT_MAX) < 1) ? 1 : clog2(CNT_MAX);

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : g_bit

            (* ASYNC_REG = "TRUE" *) reg s0, s1;
            reg [CW-1:0] cnt;
            reg          stable;
            reg          rise_r;

            always @(posedge clk) begin
                s0 <= din[i];
                s1 <= s0;
            end

            always @(posedge clk) begin
                if (rst) begin
                    cnt    <= {CW{1'b0}};
                    stable <= 1'b0;
                    rise_r <= 1'b0;
                end else begin
                    rise_r <= 1'b0;
                    if (s1 == stable) begin
                        cnt <= {CW{1'b0}};
                    end else if (cnt == CNT_MAX - 1) begin
                        cnt    <= {CW{1'b0}};
                        stable <= s1;
                        rise_r <= s1;
                    end else begin
                        cnt <= cnt + 1'b1;
                    end
                end
            end

            assign level[i] = stable;
            assign rise[i]  = rise_r;

        end
    endgenerate

endmodule
