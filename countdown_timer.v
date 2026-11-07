module countdown_timer #(
    parameter RING_S = 30
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       tick_100hz,
    input  wire       inc_min,
    input  wire       inc_sec,
    input  wire       start_stop,
    input  wire       clear,
    input  wire       any_btn,
    output reg  [6:0] tm_min,
    output reg  [5:0] tm_sec,
    output reg        running,
    output reg        ringing
);

    localparam integer RING_TICKS = RING_S * 100;

    function integer clog2;
        input integer v;
        integer t;
        begin
            clog2 = 0;
            for (t = v - 1; t > 0; t = t >> 1)
                clog2 = clog2 + 1;
        end
    endfunction

    localparam RW = (clog2(RING_TICKS + 1) < 1) ? 1 : clog2(RING_TICKS + 1);

    reg [6:0]    cs;
    reg [RW-1:0] ring_cnt;

    wire is_zero = (tm_min == 7'd0) && (tm_sec == 6'd0);
    wire last_s  = (tm_min == 7'd0) && (tm_sec == 6'd1);

    always @(posedge clk) begin
        if (rst || clear) begin
            tm_min   <= 7'd0;
            tm_sec   <= 6'd0;
            running  <= 1'b0;
            ringing  <= 1'b0;
            cs       <= 7'd0;
            ring_cnt <= {RW{1'b0}};
        end else if (ringing && any_btn) begin

            ringing  <= 1'b0;
            ring_cnt <= {RW{1'b0}};
        end else begin

            if (ringing && tick_100hz) begin
                if (ring_cnt == RING_TICKS - 1) begin
                    ringing  <= 1'b0;
                    ring_cnt <= {RW{1'b0}};
                end else begin
                    ring_cnt <= ring_cnt + 1'b1;
                end
            end

            if (start_stop) begin
                if (running) begin
                    running <= 1'b0;
                end else if (!is_zero) begin
                    running <= 1'b1;
                    cs      <= 7'd0;
                end
            end else if (!running) begin

                if (inc_min)
                    tm_min <= (tm_min >= 7'd99) ? 7'd0 : tm_min + 1'b1;
                else if (inc_sec)
                    tm_sec <= (tm_sec >= 6'd59) ? 6'd0 : tm_sec + 1'b1;
            end else if (tick_100hz) begin

                if (cs == 7'd99) begin
                    cs <= 7'd0;
                    if (tm_sec == 6'd0) begin
                        tm_sec <= 6'd59;
                        tm_min <= tm_min - 1'b1;
                    end else begin
                        tm_sec <= tm_sec - 1'b1;
                    end
                    if (last_s) begin
                        running  <= 1'b0;
                        ringing  <= 1'b1;
                        ring_cnt <= {RW{1'b0}};
                    end
                end else begin
                    cs <= cs + 1'b1;
                end
            end
        end
    end

endmodule
