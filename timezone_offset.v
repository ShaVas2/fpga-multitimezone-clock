module timezone_offset #(
    parameter integer OFF_LOCAL_H = 5,   parameter integer OFF_LOCAL_M = 30,
    parameter integer OFF_TOKYO_H = 9,   parameter integer OFF_TOKYO_M = 0,
    parameter integer OFF_PARIS_H = 2,   parameter integer OFF_PARIS_M = 0,
    parameter integer OFF_LONDON_H = 1,  parameter integer OFF_LONDON_M = 0,
    parameter integer OFF_BEIJING_H = 8, parameter integer OFF_BEIJING_M = 0,
    parameter integer OFF_NY_H = -4,     parameter integer OFF_NY_M = 0
)(
    input  wire [2:0] city_sel,
    input  wire [4:0] utc_hour,
    input  wire [5:0] utc_min,
    output reg  [4:0] city_hour,
    output reg  [5:0] city_min,
    output reg        day_fwd,
    output reg        day_back,
    output reg  [4:0] city_char,
    output reg  [5:0] city_led
);

    localparam [4:0] CH_N = 5'd14,
                     CH_T = 5'd15,
                     CH_P = 5'd16,
                     CH_L = 5'd17,
                     CH_B = 5'd18,
                     CH_H = 5'd21;

    integer off_h;
    integer off_m;
    integer m_sum;
    integer h_sum;

    always @* begin

        case (city_sel)
            3'd0: begin off_h = OFF_LOCAL_H;   off_m = OFF_LOCAL_M;   city_char = CH_H; city_led = 6'b000001; end
            3'd1: begin off_h = OFF_TOKYO_H;   off_m = OFF_TOKYO_M;   city_char = CH_T; city_led = 6'b000010; end
            3'd2: begin off_h = OFF_PARIS_H;   off_m = OFF_PARIS_M;   city_char = CH_P; city_led = 6'b000100; end
            3'd4: begin off_h = OFF_BEIJING_H; off_m = OFF_BEIJING_M; city_char = CH_B; city_led = 6'b010000; end
            3'd5: begin off_h = OFF_NY_H;      off_m = OFF_NY_M;      city_char = CH_N; city_led = 6'b100000; end
            default: begin off_h = OFF_LONDON_H; off_m = OFF_LONDON_M; city_char = CH_L; city_led = 6'b001000; end
        endcase

        m_sum = utc_min;
        m_sum = m_sum + off_m;
        h_sum = utc_hour;
        h_sum = h_sum + off_h;
        if (m_sum >= 60) begin
            m_sum = m_sum - 60;
            h_sum = h_sum + 1;
        end

        if (h_sum >= 24) begin
            h_sum    = h_sum - 24;
            day_fwd  = 1'b1;
            day_back = 1'b0;
        end else if (h_sum < 0) begin
            h_sum    = h_sum + 24;
            day_fwd  = 1'b0;
            day_back = 1'b1;
        end else begin
            day_fwd  = 1'b0;
            day_back = 1'b0;
        end

        city_hour = h_sum[4:0];
        city_min  = m_sum[5:0];
    end

endmodule
