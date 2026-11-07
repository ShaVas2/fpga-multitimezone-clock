module motion_detect #(
    parameter SHAKE_TH    = 64,
    parameter SHAKE_JERKS = 4,
    parameter SHAKE_WIN   = 50,
    parameter TILT_ON   = 32,
    parameter TILT_OFF  = 12,
    parameter TILT_N    = 15,
    parameter TILT_AXIS = 0,
    parameter TILT_FLIP = 0
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              sample_valid,
    input  wire signed [7:0] acc_x,
    input  wire signed [7:0] acc_y,
    input  wire signed [7:0] acc_z,
    input  wire              tilt_en,
    output reg               shake,
    output reg               tilt_left,
    output reg               tilt_right
);

    reg signed [7:0] px, py, pz;
    reg              have_prev;

    wire signed [8:0] dx = acc_x - px;
    wire signed [8:0] dy = acc_y - py;
    wire signed [8:0] dz = acc_z - pz;
    wire [8:0] ax = dx[8] ? -dx : dx;
    wire [8:0] ay = dy[8] ? -dy : dy;
    wire [8:0] az = dz[8] ? -dz : dz;
    wire [10:0] jerk_sum = ax + ay + az;
    wire        jerk     = have_prev && (jerk_sum > SHAKE_TH);

    reg [2:0] jerks;
    reg [6:0] window;
    reg [6:0] holdoff;

    wire signed [7:0] a_raw = (TILT_AXIS == 0) ? acc_x : acc_y;
    wire signed [8:0] a     = TILT_FLIP ? -{a_raw[7], a_raw} : {a_raw[7], a_raw};

    reg       armed;
    reg [4:0] pos_cnt, neg_cnt;

    always @(posedge clk) begin
        if (rst) begin
            px <= 8'sd0; py <= 8'sd0; pz <= 8'sd0; have_prev <= 1'b0;
            jerks <= 3'd0; window <= 7'd0; holdoff <= 7'd0;
            armed <= 1'b1; pos_cnt <= 5'd0; neg_cnt <= 5'd0;
            shake <= 1'b0; tilt_left <= 1'b0; tilt_right <= 1'b0;
        end else begin
            shake      <= 1'b0;
            tilt_left  <= 1'b0;
            tilt_right <= 1'b0;

            if (sample_valid) begin
                px <= acc_x; py <= acc_y; pz <= acc_z; have_prev <= 1'b1;

                if (holdoff != 7'd0)
                    holdoff <= holdoff - 1'b1;

                if (window != 7'd0)
                    window <= window - 1'b1;
                else
                    jerks <= 3'd0;

                if (jerk && holdoff == 7'd0) begin
                    if (window == 7'd0) begin
                        jerks  <= 3'd1;
                        window <= SHAKE_WIN;
                    end else if (jerks == SHAKE_JERKS - 1) begin
                        shake   <= 1'b1;
                        jerks   <= 3'd0;
                        window  <= 7'd0;
                        holdoff <= 7'd100;
                    end else begin
                        jerks <= jerks + 1'b1;
                    end
                end

                if (a > TILT_ON)  pos_cnt <= (pos_cnt == 5'd31) ? pos_cnt : pos_cnt + 1'b1;
                else              pos_cnt <= 5'd0;
                if (a < -TILT_ON) neg_cnt <= (neg_cnt == 5'd31) ? neg_cnt : neg_cnt + 1'b1;
                else              neg_cnt <= 5'd0;

                if (a < TILT_OFF && a > -TILT_OFF)
                    armed <= 1'b1;
                else if (armed && tilt_en && pos_cnt == TILT_N - 1 && a > TILT_ON) begin
                    tilt_right <= 1'b1;
                    armed      <= 1'b0;
                end else if (armed && tilt_en && neg_cnt == TILT_N - 1 && a < -TILT_ON) begin
                    tilt_left  <= 1'b1;
                    armed      <= 1'b0;
                end
            end
        end
    end

endmodule
