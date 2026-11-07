module time_counter (
    input  wire       clk,
    input  wire       rst,
    input  wire       tick_1hz,
    input  wire       inc_hour,
    input  wire       inc_min,
    output reg  [4:0] hour,
    output reg  [5:0] min,
    output reg  [5:0] sec,
    output reg        day_carry
);

    always @(posedge clk) begin
        if (rst) begin
            hour      <= 5'd0;
            min       <= 6'd0;
            sec       <= 6'd0;
            day_carry <= 1'b0;
        end else begin
            day_carry <= 1'b0;

            if (inc_hour) begin
                hour <= (hour == 5'd23) ? 5'd0 : hour + 1'b1;
            end else if (inc_min) begin
                min  <= (min == 6'd59) ? 6'd0 : min + 1'b1;
                sec  <= 6'd0;
            end else if (tick_1hz) begin
                if (sec == 6'd59) begin
                    sec <= 6'd0;
                    if (min == 6'd59) begin
                        min <= 6'd0;
                        if (hour == 5'd23) begin
                            hour      <= 5'd0;
                            day_carry <= 1'b1;
                        end else begin
                            hour <= hour + 1'b1;
                        end
                    end else begin
                        min <= min + 1'b1;
                    end
                end else begin
                    sec <= sec + 1'b1;
                end
            end
        end
    end

endmodule
