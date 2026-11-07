module mode_fsm (
    input  wire       clk,
    input  wire       rst,
    input  wire       btn_mode,
    input  wire       btn_up,
    input  wire       btn_down,
    input  wire       btn_left,
    input  wire       btn_right,
    input  wire       btn_prev,
    output reg  [2:0] mode,
    output reg        inc_hour,
    output reg        inc_min,
    output reg        inc_day,
    output reg        inc_month,
    output reg        inc_year,
    output reg        sw_start_stop,
    output reg        sw_clear,
    output reg        tm_inc_min,
    output reg        tm_inc_sec,
    output reg        tm_start_stop,
    output reg        tm_clear,
    output reg        al_inc_hour,
    output reg        al_inc_min,
    output reg        al_toggle,
    output reg        day_view
);

    localparam [2:0] M_TIME  = 3'd0,
                     M_DATE  = 3'd1,
                     M_SW    = 3'd2,
                     M_TIMER = 3'd3,
                     M_ALARM = 3'd4,
                     M_TEMP  = 3'd5;

    always @(posedge clk) begin
        if (rst)
            mode <= M_TIME;
        else if (btn_mode)
            mode <= (mode >= M_TEMP) ? M_TIME : mode + 1'b1;
        else if (btn_prev)
            mode <= (mode == M_TIME || mode > M_TEMP) ? M_TEMP : mode - 1'b1;
    end

    always @(posedge clk) begin
        if (rst) begin
            inc_hour      <= 1'b0;
            inc_min       <= 1'b0;
            inc_day       <= 1'b0;
            inc_month     <= 1'b0;
            inc_year      <= 1'b0;
            sw_start_stop <= 1'b0;
            sw_clear      <= 1'b0;
            tm_inc_min    <= 1'b0;
            tm_inc_sec    <= 1'b0;
            tm_start_stop <= 1'b0;
            tm_clear      <= 1'b0;
            al_inc_hour   <= 1'b0;
            al_inc_min    <= 1'b0;
            al_toggle     <= 1'b0;
            day_view      <= 1'b0;
        end else begin
            inc_hour      <= (mode == M_TIME)  & btn_up;
            inc_min       <= (mode == M_TIME)  & btn_down;
            inc_day       <= (mode == M_DATE)  & btn_up;
            inc_month     <= (mode == M_DATE)  & btn_down;
            inc_year      <= (mode == M_DATE)  & btn_left;
            sw_start_stop <= (mode == M_SW)    & btn_left;
            sw_clear      <= (mode == M_SW)    & btn_right;
            tm_inc_min    <= (mode == M_TIMER) & btn_up;
            tm_inc_sec    <= (mode == M_TIMER) & btn_down;
            tm_start_stop <= (mode == M_TIMER) & btn_left;
            tm_clear      <= (mode == M_TIMER) & btn_right;
            al_inc_hour   <= (mode == M_ALARM) & btn_up;
            al_inc_min    <= (mode == M_ALARM) & btn_down;
            al_toggle     <= (mode == M_ALARM) & btn_left;
            if ((mode == M_DATE) & btn_right)
                day_view  <= ~day_view;
        end
    end

endmodule
