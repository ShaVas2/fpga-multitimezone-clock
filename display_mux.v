module display_mux (
    input  wire [2:0]  mode,
    input  wire [4:0]  city_char,
    input  wire [4:0]  t_hour,
    input  wire [5:0]  t_min,
    input  wire [5:0]  t_sec,
    input  wire [4:0]  d_day,
    input  wire [3:0]  d_month,
    input  wire [6:0]  d_year,
    input  wire [2:0]  weekday,
    input  wire        day_view,
    input  wire [5:0]  sw_min,
    input  wire [5:0]  sw_sec,
    input  wire [6:0]  sw_cs,
    input  wire [6:0]  tm_min,
    input  wire [5:0]  tm_sec,
    input  wire        tm_ringing,
    input  wire [4:0]  al_hour,
    input  wire [5:0]  al_min,
    input  wire        al_armed,
    input  wire        al_ringing,
    input  wire        blink,
    input  wire        temp_neg,
    input  wire [15:0] temp_bcd,
    input  wire        temp_valid,
    input  wire        temp_err,
    output reg  [39:0] chars,
    output reg  [7:0]  dp_on
);

    localparam [4:0] CH_BLANK = 5'd10,
                     CH_MINUS = 5'd11,
                     CH_C     = 5'd12,
                     CH_DEG   = 5'd13,
                     CH_E     = 5'd19,
                     CH_R     = 5'd20,
                     CH_A     = 5'd22,
                     CH_O     = 5'd23,
                     CH_F     = 5'd24,
                     CH_U     = 5'd25,
                     CH_D     = 5'd26,
                     CH_HL    = 5'd27,
                     CH_ML    = 5'd28,
                     CH_J     = 5'd29,
                     CH_L     = 5'd17,
                     CH_N     = 5'd14,
                     CH_T     = 5'd15;

    localparam [2:0] M_TIME  = 3'd0,
                     M_DATE  = 3'd1,
                     M_SW    = 3'd2,
                     M_TIMER = 3'd3,
                     M_ALARM = 3'd4,
                     M_TEMP  = 3'd5;

    reg [6:0] num_a, num_b, num_c;

    always @* begin
        case (mode)
            M_TIME:  begin num_a = {2'b00, t_hour}; num_b = {1'b0, t_min};     num_c = {1'b0, t_sec}; end
            M_DATE:  begin num_a = {2'b00, d_day};  num_b = {3'b000, d_month}; num_c = d_year;        end
            M_TIMER: begin num_a = tm_min;          num_b = {1'b0, tm_sec};    num_c = 7'd0;          end
            M_ALARM: begin num_a = {2'b00, al_hour}; num_b = {1'b0, al_min};    num_c = 7'd0;          end
            default: begin num_a = {1'b0, sw_min};  num_b = {1'b0, sw_sec};    num_c = sw_cs;         end
        endcase
    end

    wire [7:0] bcd_a, bcd_b, bcd_c;

    bin2bcd #(.BIN_W(7), .DIGITS(2)) u_bcd_a (.bin(num_a), .bcd(bcd_a));
    bin2bcd #(.BIN_W(7), .DIGITS(2)) u_bcd_b (.bin(num_b), .bcd(bcd_b));
    bin2bcd #(.BIN_W(7), .DIGITS(2)) u_bcd_c (.bin(num_c), .bcd(bcd_c));

    function [4:0] dg;
        input [3:0] b;
        begin
            dg = {1'b0, b};
        end
    endfunction

    function [19:0] day_name;
        input [2:0] w;
        begin
            case (w)
                3'd0: day_name = {CH_BLANK, 5'd5, CH_U, CH_N};
                3'd1: day_name = {CH_ML, 5'd7, CH_O, CH_N};
                3'd2: day_name = {CH_BLANK, CH_T, CH_U, CH_E};
                3'd3: day_name = {CH_L, CH_J, CH_E, CH_D};
                3'd4: day_name = {CH_BLANK, CH_T, CH_HL, CH_U};
                3'd5: day_name = {CH_BLANK, CH_F, CH_R, 5'd1};
                default: day_name = {CH_BLANK, 5'd5, CH_A, CH_T};
            endcase
        end
    endfunction

    wire [3:0] t_hun  = temp_bcd[15:12];
    wire [3:0] t_ten  = temp_bcd[11:8];
    wire [3:0] t_one  = temp_bcd[7:4];
    wire [3:0] t_tnth = temp_bcd[3:0];
    wire [4:0] sign_ch = temp_neg ? CH_MINUS : CH_BLANK;

    reg [4:0] tc6, tc5, tc4;

    always @* begin
        if (t_hun != 4'd0) begin
            tc6 = sign_ch;
            tc5 = dg(t_hun);
            tc4 = dg(t_ten);
        end else if (t_ten != 4'd0) begin
            tc6 = CH_BLANK;
            tc5 = sign_ch;
            tc4 = dg(t_ten);
        end else begin
            tc6 = CH_BLANK;
            tc5 = CH_BLANK;
            tc4 = sign_ch;
        end
    end

    always @* begin
        case (mode)
            M_DATE: begin
                if (day_view) begin
                    chars = {city_char, CH_BLANK, CH_BLANK, CH_BLANK, day_name(weekday)};
                    dp_on = 8'b0000_0000;
                end else begin
                    chars = {city_char, CH_BLANK,
                             dg(bcd_a[7:4]), dg(bcd_a[3:0]),
                             dg(bcd_b[7:4]), dg(bcd_b[3:0]),
                             dg(bcd_c[7:4]), dg(bcd_c[3:0])};
                    dp_on = 8'b0001_0100;
                end
            end

            M_TIME: begin
                chars = {city_char, CH_BLANK,
                         dg(bcd_a[7:4]), dg(bcd_a[3:0]),
                         dg(bcd_b[7:4]), dg(bcd_b[3:0]),
                         dg(bcd_c[7:4]), dg(bcd_c[3:0])};
                dp_on = 8'b0001_0100;
            end

            M_SW: begin
                chars = {CH_BLANK, CH_BLANK,
                         dg(bcd_a[7:4]), dg(bcd_a[3:0]),
                         dg(bcd_b[7:4]), dg(bcd_b[3:0]),
                         dg(bcd_c[7:4]), dg(bcd_c[3:0])};
                dp_on = 8'b0001_0100;
            end

            M_TIMER: begin
                if (tm_ringing && !blink) begin
                    chars = {8{CH_BLANK}};
                    dp_on = 8'b0000_0000;
                end else begin
                    chars = {CH_BLANK, CH_BLANK, CH_BLANK, CH_BLANK,
                             dg(bcd_a[7:4]), dg(bcd_a[3:0]),
                             dg(bcd_b[7:4]), dg(bcd_b[3:0])};
                    dp_on = 8'b0000_0100;
                end
            end

            M_ALARM: begin
                if (al_ringing && !blink) begin
                    chars = {8{CH_BLANK}};
                    dp_on = 8'b0000_0000;
                end else begin
                    chars = {CH_A,
                             dg(bcd_a[7:4]), dg(bcd_a[3:0]),
                             dg(bcd_b[7:4]), dg(bcd_b[3:0]),
                             al_armed ? CH_BLANK : CH_O,
                             al_armed ? CH_O     : CH_F,
                             al_armed ? 5'd14    : CH_F};
                    dp_on = 8'b0010_0000;
                end
            end

            default: begin
                if (temp_err) begin
                    chars = {CH_BLANK, CH_BLANK, CH_E, CH_R, CH_R,
                             CH_BLANK, CH_BLANK, CH_BLANK};
                    dp_on = 8'b0000_0000;
                end else if (!temp_valid) begin
                    chars = {CH_BLANK, CH_BLANK, CH_MINUS, CH_MINUS,
                             CH_MINUS, CH_MINUS, CH_DEG, CH_C};
                    dp_on = 8'b0000_0000;
                end else begin
                    chars = {CH_BLANK, tc6, tc5, tc4,
                             dg(t_one), dg(t_tnth), CH_DEG, CH_C};
                    dp_on = 8'b0000_1000;
                end
            end
        endcase
    end

endmodule
