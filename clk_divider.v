module clk_divider #(
    parameter CLK_HZ = 100_000_000
)(
    input  wire clk,
    input  wire rst,
    output reg  tick_1khz,
    output reg  tick_100hz,
    output reg  tick_1hz
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

    localparam integer DIV_1K = CLK_HZ / 1000;
    localparam         CW     = (clog2(DIV_1K) < 1) ? 1 : clog2(DIV_1K);

    reg [CW-1:0] cnt_1k;
    reg [3:0]    cnt_100;
    reg [6:0]    cnt_1;

    always @(posedge clk) begin
        if (rst) begin
            cnt_1k     <= {CW{1'b0}};
            cnt_100    <= 4'd0;
            cnt_1      <= 7'd0;
            tick_1khz  <= 1'b0;
            tick_100hz <= 1'b0;
            tick_1hz   <= 1'b0;
        end else begin
            tick_1khz  <= 1'b0;
            tick_100hz <= 1'b0;
            tick_1hz   <= 1'b0;

            if (cnt_1k == DIV_1K - 1) begin
                cnt_1k    <= {CW{1'b0}};
                tick_1khz <= 1'b1;

                if (cnt_100 == 4'd9) begin
                    cnt_100    <= 4'd0;
                    tick_100hz <= 1'b1;

                    if (cnt_1 == 7'd99) begin
                        cnt_1    <= 7'd0;
                        tick_1hz <= 1'b1;
                    end else begin
                        cnt_1 <= cnt_1 + 1'b1;
                    end
                end else begin
                    cnt_100 <= cnt_100 + 1'b1;
                end
            end else begin
                cnt_1k <= cnt_1k + 1'b1;
            end
        end
    end

endmodule
