module stopwatch (
    input  wire       clk,
    input  wire       rst,
    input  wire       tick_100hz,
    input  wire       start_stop,
    input  wire       clear,
    output reg  [5:0] sw_min,
    output reg  [5:0] sw_sec,
    output reg  [6:0] sw_cs,
    output reg        running
);

    always @(posedge clk) begin
        if (rst || clear) begin
            sw_min  <= 6'd0;
            sw_sec  <= 6'd0;
            sw_cs   <= 7'd0;
            running <= 1'b0;
        end else begin
            if (start_stop)
                running <= ~running;

            if (running && tick_100hz) begin
                if (sw_cs == 7'd99) begin
                    sw_cs <= 7'd0;
                    if (sw_sec == 6'd59) begin
                        sw_sec <= 6'd0;
                        sw_min <= (sw_min == 6'd59) ? 6'd0 : sw_min + 1'b1;
                    end else begin
                        sw_sec <= sw_sec + 1'b1;
                    end
                end else begin
                    sw_cs <= sw_cs + 1'b1;
                end
            end
        end
    end

endmodule
