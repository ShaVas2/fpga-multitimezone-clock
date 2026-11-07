module date_counter #(
    parameter INIT_DAY   = 1,
    parameter INIT_MONTH = 1,
    parameter INIT_YEAR  = 26
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       day_carry,
    input  wire       inc_day,
    input  wire       inc_month,
    input  wire       inc_year,
    input  wire       day_fwd,
    input  wire       day_back,
    output reg  [4:0] utc_day,
    output reg  [3:0] utc_month,
    output reg  [6:0] utc_year,
    output reg  [4:0] city_day,
    output reg  [3:0] city_month,
    output reg  [6:0] city_year
);

    function [4:0] days_in_month;
        input [3:0] m;
        input [6:0] y;
        begin
            case (m)
                4'd2:                      days_in_month = (y[1:0] == 2'b00) ? 5'd29 : 5'd28;
                4'd4, 4'd6, 4'd9, 4'd11:   days_in_month = 5'd30;
                default:                   days_in_month = 5'd31;
            endcase
        end
    endfunction

    function [4:0] clamp_day;
        input [4:0] d;
        input [3:0] m;
        input [6:0] y;
        reg   [4:0] dim;
        begin
            dim       = days_in_month(m, y);
            clamp_day = (d > dim) ? dim : d;
        end
    endfunction

    reg [4:0] nxt_day;
    reg [3:0] nxt_month;
    reg [6:0] nxt_year;

    always @* begin
        if (utc_day >= days_in_month(utc_month, utc_year)) begin
            nxt_day = 5'd1;
            if (utc_month == 4'd12) begin
                nxt_month = 4'd1;
                nxt_year  = (utc_year == 7'd99) ? 7'd0 : utc_year + 1'b1;
            end else begin
                nxt_month = utc_month + 1'b1;
                nxt_year  = utc_year;
            end
        end else begin
            nxt_day   = utc_day + 1'b1;
            nxt_month = utc_month;
            nxt_year  = utc_year;
        end
    end

    reg [4:0] prv_day;
    reg [3:0] prv_month;
    reg [6:0] prv_year;

    always @* begin
        if (utc_day <= 5'd1) begin
            if (utc_month <= 4'd1) begin
                prv_month = 4'd12;
                prv_year  = (utc_year == 7'd0) ? 7'd99 : utc_year - 1'b1;
            end else begin
                prv_month = utc_month - 1'b1;
                prv_year  = utc_year;
            end
            prv_day = days_in_month(prv_month, prv_year);
        end else begin
            prv_day   = utc_day - 1'b1;
            prv_month = utc_month;
            prv_year  = utc_year;
        end
    end

    always @* begin
        if (day_fwd) begin
            city_day   = nxt_day;
            city_month = nxt_month;
            city_year  = nxt_year;
        end else if (day_back) begin
            city_day   = prv_day;
            city_month = prv_month;
            city_year  = prv_year;
        end else begin
            city_day   = utc_day;
            city_month = utc_month;
            city_year  = utc_year;
        end
    end

    wire [3:0] m_new = (utc_month >= 4'd12) ? 4'd1 : utc_month + 1'b1;
    wire [6:0] y_new = (utc_year  >= 7'd99) ? 7'd0 : utc_year  + 1'b1;

    always @(posedge clk) begin
        if (rst) begin
            utc_day   <= INIT_DAY;
            utc_month <= INIT_MONTH;
            utc_year  <= INIT_YEAR;
        end else if (day_carry) begin
            utc_day   <= nxt_day;
            utc_month <= nxt_month;
            utc_year  <= nxt_year;
        end else if (inc_day) begin
            utc_day   <= (utc_day >= days_in_month(utc_month, utc_year))
                         ? 5'd1 : utc_day + 1'b1;
        end else if (inc_month) begin
            utc_month <= m_new;
            utc_day   <= clamp_day(utc_day, m_new, utc_year);
        end else if (inc_year) begin
            utc_year  <= y_new;
            utc_day   <= clamp_day(utc_day, utc_month, y_new);
        end
    end

endmodule
