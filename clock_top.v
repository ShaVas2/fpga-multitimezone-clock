module clock_top #(
    parameter CLK_HZ      = 100_000_000,
    parameter DEBOUNCE_MS = 10,
    parameter I2C_HZ      = 100_000,
    parameter POLL_MS     = 250,
    parameter INIT_DAY    = 1,
    parameter INIT_MONTH  = 1,
    parameter INIT_YEAR   = 26
)(
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire        BTNC,
    input  wire        BTNU,
    input  wire        BTND,
    input  wire        BTNL,
    input  wire        BTNR,
    input  wire [2:0]  SW,
    output wire [15:0] LED,
    output wire        CA,
    output wire        CB,
    output wire        CC,
    output wire        CD,
    output wire        CE,
    output wire        CF,
    output wire        CG,
    output wire        DP,
    output wire [7:0]  AN,
    inout  wire        TMP_SCL,
    inout  wire        TMP_SDA,
    output wire        AUD_PWM,
    output wire        AUD_SD,
    input  wire        SW14,
    input  wire        ACL_MISO,
    output wire        ACL_MOSI,
    output wire        ACL_SCLK,
    output wire        ACL_CSN,
    output wire        LED16_R,
    output wire        LED16_G,
    output wire        LED16_B,
    output wire        LED17_R,
    output wire        LED17_G,
    output wire        LED17_B
);

    wire clk = CLK100MHZ;

    wire rst;
    wire tick_1khz, tick_100hz, tick_1hz;

    reset_sync #(.STRETCH(16)) u_rst (
        .clk       (clk),
        .rst_btn_n (CPU_RESETN),
        .rst       (rst)
    );

    clk_divider #(.CLK_HZ(CLK_HZ)) u_div (
        .clk        (clk),
        .rst        (rst),
        .tick_1khz  (tick_1khz),
        .tick_100hz (tick_100hz),
        .tick_1hz   (tick_1hz)
    );

    wire [4:0] btn_pulse;
    wire [2:0] city_sel;
    wire       tilt_en;

    debounce #(.WIDTH(5), .CLK_HZ(CLK_HZ), .DEBOUNCE_MS(DEBOUNCE_MS)) u_db_btn (
        .clk   (clk),
        .rst   (rst),
        .din   ({BTNR, BTNL, BTND, BTNU, BTNC}),
        .level (),
        .rise  (btn_pulse)
    );

    debounce #(.WIDTH(4), .CLK_HZ(CLK_HZ), .DEBOUNCE_MS(DEBOUNCE_MS)) u_db_sw (
        .clk   (clk),
        .rst   (rst),
        .din   ({SW14, SW}),
        .level ({tilt_en, city_sel}),
        .rise  ()
    );

    wire signed [7:0] acc_x, acc_y, acc_z;
    wire              acc_valid;
    wire              shake, tilt_left, tilt_right;

    adxl362_spi #(.CLK_HZ(CLK_HZ)) u_acl (
        .clk          (clk),
        .rst          (rst),
        .acl_miso     (ACL_MISO),
        .acl_mosi     (ACL_MOSI),
        .acl_sclk     (ACL_SCLK),
        .acl_csn      (ACL_CSN),
        .acc_x        (acc_x),
        .acc_y        (acc_y),
        .acc_z        (acc_z),
        .sample_valid (acc_valid)
    );

    motion_detect #(.TILT_AXIS(0), .TILT_FLIP(0)) u_motion (
        .clk          (clk),
        .rst          (rst),
        .sample_valid (acc_valid),
        .acc_x        (acc_x),
        .acc_y        (acc_y),
        .acc_z        (acc_z),
        .tilt_en      (tilt_en),
        .shake        (shake),
        .tilt_left    (tilt_left),
        .tilt_right   (tilt_right)
    );

    wire [2:0] mode;
    wire inc_hour, inc_min, inc_day, inc_month, inc_year;
    wire sw_start_stop, sw_clear;
    wire tm_inc_min, tm_inc_sec, tm_start_stop, tm_clear;
    wire al_inc_hour, al_inc_min, al_toggle;
    wire day_view;

    mode_fsm u_mode (
        .clk           (clk),
        .rst           (rst),
        .btn_mode      (btn_pulse[0] | tilt_right),
        .btn_up        (btn_pulse[1]),
        .btn_down      (btn_pulse[2]),
        .btn_left      (btn_pulse[3]),
        .btn_right     (btn_pulse[4]),
        .btn_prev      (tilt_left),
        .mode          (mode),
        .inc_hour      (inc_hour),
        .inc_min       (inc_min),
        .inc_day       (inc_day),
        .inc_month     (inc_month),
        .inc_year      (inc_year),
        .sw_start_stop (sw_start_stop),
        .sw_clear      (sw_clear),
        .tm_inc_min    (tm_inc_min),
        .tm_inc_sec    (tm_inc_sec),
        .tm_start_stop (tm_start_stop),
        .tm_clear      (tm_clear),
        .al_inc_hour   (al_inc_hour),
        .al_inc_min    (al_inc_min),
        .al_toggle     (al_toggle),
        .day_view      (day_view)
    );

    reg any_btn;

    always @(posedge clk) begin
        if (rst)
            any_btn <= 1'b0;
        else
            any_btn <= (|btn_pulse) | shake;
    end

    wire [4:0] utc_hour;
    wire [5:0] utc_min, utc_sec;
    wire       day_carry;

    time_counter u_time (
        .clk       (clk),
        .rst       (rst),
        .tick_1hz  (tick_1hz),
        .inc_hour  (inc_hour),
        .inc_min   (inc_min),
        .hour      (utc_hour),
        .min       (utc_min),
        .sec       (utc_sec),
        .day_carry (day_carry)
    );

    wire [4:0] city_hour;
    wire [5:0] city_min;
    wire       day_fwd, day_back;
    wire [4:0] city_char;
    wire [5:0] city_led;

    wire [4:0] city_hour_c;
    wire [5:0] city_min_c;
    wire       day_fwd_c, day_back_c;
    wire [4:0] city_char_c;
    wire [5:0] city_led_c;

    timezone_offset u_tz (
        .city_sel  (city_sel),
        .utc_hour  (utc_hour),
        .utc_min   (utc_min),
        .city_hour (city_hour_c),
        .city_min  (city_min_c),
        .day_fwd   (day_fwd_c),
        .day_back  (day_back_c),
        .city_char (city_char_c),
        .city_led  (city_led_c)
    );

    reg [4:0] city_hour_r, city_char_r;
    reg [5:0] city_min_r, city_led_r;
    reg       day_fwd_r, day_back_r;

    always @(posedge clk) begin
        if (rst) begin
            city_hour_r <= 5'd0;
            city_min_r  <= 6'd0;
            day_fwd_r   <= 1'b0;
            day_back_r  <= 1'b0;
            city_char_r <= 5'd17;
            city_led_r  <= 6'b001000;
        end else begin
            city_hour_r <= city_hour_c;
            city_min_r  <= city_min_c;
            day_fwd_r   <= day_fwd_c;
            day_back_r  <= day_back_c;
            city_char_r <= city_char_c;
            city_led_r  <= city_led_c;
        end
    end

    assign city_hour = city_hour_r;
    assign city_min  = city_min_r;
    assign day_fwd   = day_fwd_r;
    assign day_back  = day_back_r;
    assign city_char = city_char_r;
    assign city_led  = city_led_r;

    wire [4:0] city_day_c;
    wire [3:0] city_month_c;
    wire [6:0] city_year_c;

    date_counter #(
        .INIT_DAY   (INIT_DAY),
        .INIT_MONTH (INIT_MONTH),
        .INIT_YEAR  (INIT_YEAR)
    ) u_date (
        .clk        (clk),
        .rst        (rst),
        .day_carry  (day_carry),
        .inc_day    (inc_day),
        .inc_month  (inc_month),
        .inc_year   (inc_year),
        .day_fwd    (day_fwd),
        .day_back   (day_back),
        .utc_day    (),
        .utc_month  (),
        .utc_year   (),
        .city_day   (city_day_c),
        .city_month (city_month_c),
        .city_year  (city_year_c)
    );

    reg [4:0] city_day;
    reg [3:0] city_month;
    reg [6:0] city_year;

    always @(posedge clk) begin
        if (rst) begin
            city_day   <= 5'd1;
            city_month <= 4'd1;
            city_year  <= 7'd0;
        end else begin
            city_day   <= city_day_c;
            city_month <= city_month_c;
            city_year  <= city_year_c;
        end
    end

    wire [2:0] city_wday;

    weekday u_wday (
        .clk     (clk),
        .rst     (rst),
        .day     (city_day),
        .month   (city_month),
        .year    (city_year),
        .weekday (city_wday)
    );

    wire [5:0] sw_min, sw_sec;
    wire [6:0] sw_cs;
    wire       sw_running;

    stopwatch u_sw (
        .clk        (clk),
        .rst        (rst),
        .tick_100hz (tick_100hz),
        .start_stop (sw_start_stop),
        .clear      (sw_clear),
        .sw_min     (sw_min),
        .sw_sec     (sw_sec),
        .sw_cs      (sw_cs),
        .running    (sw_running)
    );

    wire [6:0] tm_min;
    wire [5:0] tm_sec;
    wire       tm_running, tm_ringing;

    countdown_timer #(.RING_S(30)) u_timer (
        .clk        (clk),
        .rst        (rst),
        .tick_100hz (tick_100hz),
        .inc_min    (tm_inc_min),
        .inc_sec    (tm_inc_sec),
        .start_stop (tm_start_stop),
        .clear      (tm_clear),
        .any_btn    (any_btn),
        .tm_min     (tm_min),
        .tm_sec     (tm_sec),
        .running    (tm_running),
        .ringing    (tm_ringing)
    );

    wire [4:0] ist_hour_c;
    wire [5:0] ist_min_c;

    timezone_offset u_tz_ist (
        .city_sel  (3'd0),
        .utc_hour  (utc_hour),
        .utc_min   (utc_min),
        .city_hour (ist_hour_c),
        .city_min  (ist_min_c),
        .day_fwd   (),
        .day_back  (),
        .city_char (),
        .city_led  ()
    );

    reg [4:0] ist_hour;
    reg [5:0] ist_min;

    always @(posedge clk) begin
        if (rst) begin
            ist_hour <= 5'd0;
            ist_min  <= 6'd0;
        end else begin
            ist_hour <= ist_hour_c;
            ist_min  <= ist_min_c;
        end
    end

    wire [4:0] al_hour;
    wire [5:0] al_min;
    wire       al_armed, al_ringing;

    alarm_clock u_alarm (
        .clk      (clk),
        .rst      (rst),
        .ist_hour (ist_hour),
        .ist_min  (ist_min),
        .sec      (utc_sec),
        .inc_hour (al_inc_hour),
        .inc_min  (al_inc_min),
        .toggle   (al_toggle),
        .any_btn  (any_btn),
        .al_hour  (al_hour),
        .al_min   (al_min),
        .armed    (al_armed),
        .ringing  (al_ringing)
    );

    wire ringing_any = tm_ringing | al_ringing;

    wire pwm_low, aud_en, blink;

    beeper #(
        .CLK_HZ  (CLK_HZ),
        .TONE_HZ (2000),
        .BEEP_MS (125)
    ) u_beep (
        .clk     (clk),
        .rst     (rst),
        .enable  (ringing_any),
        .pwm_low (pwm_low),
        .aud_sd  (aud_en),
        .blink   (blink)
    );

    assign AUD_PWM = pwm_low ? 1'b0 : 1'bz;
    assign AUD_SD  = aud_en;

    wire               scl_oe, sda_oe;
    wire signed [12:0] temp_raw;
    wire               temp_valid, i2c_err;

    assign TMP_SCL = scl_oe ? 1'b0 : 1'bz;
    assign TMP_SDA = sda_oe ? 1'b0 : 1'bz;

    temp_sensor_adt7420 #(
        .CLK_HZ   (CLK_HZ),
        .I2C_HZ   (I2C_HZ),
        .POLL_MS  (POLL_MS),
        .DEV_ADDR (7'h4B)
    ) u_temp (
        .clk        (clk),
        .rst        (rst),
        .scl_i      (TMP_SCL),
        .sda_i      (TMP_SDA),
        .scl_oe     (scl_oe),
        .sda_oe     (sda_oe),
        .temp_raw   (temp_raw),
        .temp_valid (temp_valid),
        .i2c_err    (i2c_err)
    );

    wire        temp_neg;
    wire [15:0] temp_bcd;

    temp_to_bcd u_tbcd (
        .clk      (clk),
        .rst      (rst),
        .temp_raw (temp_raw),
        .neg      (temp_neg),
        .temp_bcd (temp_bcd)
    );

    wire [39:0] chars;
    wire [7:0]  dp_on;
    wire [6:0]  seg_n;
    wire        dp_n;
    wire [7:0]  an_n;

    display_mux u_dmux (
        .mode       (mode),
        .city_char  (city_char),
        .t_hour     (city_hour),
        .t_min      (city_min),
        .t_sec      (utc_sec),
        .d_day      (city_day),
        .d_month    (city_month),
        .d_year     (city_year),
        .weekday    (city_wday),
        .day_view   (day_view),
        .sw_min     (sw_min),
        .sw_sec     (sw_sec),
        .sw_cs      (sw_cs),
        .tm_min     (tm_min),
        .tm_sec     (tm_sec),
        .tm_ringing (tm_ringing),
        .al_hour    (al_hour),
        .al_min     (al_min),
        .al_armed   (al_armed),
        .al_ringing (al_ringing),
        .blink      (blink),
        .temp_neg   (temp_neg),
        .temp_bcd   (temp_bcd),
        .temp_valid (temp_valid),
        .temp_err   (i2c_err),
        .chars      (chars),
        .dp_on      (dp_on)
    );

    reg [39:0] chars_r;
    reg [7:0]  dp_on_r;

    always @(posedge clk) begin
        if (rst) begin
            chars_r <= {8{5'd10}};
            dp_on_r <= 8'h00;
        end else begin
            chars_r <= chars;
            dp_on_r <= dp_on;
        end
    end

    seg7_driver u_seg (
        .clk       (clk),
        .rst       (rst),
        .scan_tick (tick_1khz),
        .chars     (chars_r),
        .dp_on     (dp_on_r),
        .seg_n     (seg_n),
        .dp_n      (dp_n),
        .an_n      (an_n)
    );

    assign {CG, CF, CE, CD, CC, CB, CA} = seg_n;
    assign DP = dp_n;
    assign AN = an_n;

    wire [5:0]  mode_onehot = 6'b000001 << mode;
    wire [15:0] led_normal  = {sw_running, i2c_err, mode_onehot,
                               al_armed, tm_running, city_led};

    wire [15:0] sec_bar;

    seconds_bar u_bar (
        .clk (clk),
        .rst (rst),
        .sec (utc_sec),
        .bar (sec_bar)
    );

    rgb_mood u_rgb (
        .clk        (clk),
        .rst        (rst),
        .temp_raw   (temp_raw),
        .temp_valid (temp_valid),
        .temp_err   (i2c_err),
        .city_sel   (city_sel),
        .led16_r    (LED16_R),
        .led16_g    (LED16_G),
        .led16_b    (LED16_B),
        .led17_r    (LED17_R),
        .led17_g    (LED17_G),
        .led17_b    (LED17_B)
    );

    reg [15:0] led_r;

    always @(posedge clk) begin
        if (rst)
            led_r <= 16'h0000;
        else if (ringing_any)
            led_r <= {16{blink}};
        else if (mode == 3'd0)
            led_r <= sec_bar;
        else
            led_r <= led_normal;
    end

    assign LED = led_r;

endmodule
