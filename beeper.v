module beeper #(
    parameter CLK_HZ  = 100_000_000,
    parameter TONE_HZ = 2000,
    parameter BEEP_MS = 125
)(
    input  wire clk,
    input  wire rst,
    input  wire enable,
    output wire pwm_low,
    output wire aud_sd,
    output wire blink
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

    localparam integer HALF_TONE = CLK_HZ / (2 * TONE_HZ);
    localparam integer BEEP_CYC  = (CLK_HZ / 1000) * BEEP_MS;
    localparam TW = (clog2(HALF_TONE) < 1) ? 1 : clog2(HALF_TONE);
    localparam BW = (clog2(BEEP_CYC)  < 1) ? 1 : clog2(BEEP_CYC);

    reg [TW-1:0] tcnt;
    reg [BW-1:0] bcnt;
    reg          tone;
    reg          beep_on;
    reg          sd_r;

    always @(posedge clk) begin
        if (rst || !enable) begin
            tcnt    <= {TW{1'b0}};
            bcnt    <= {BW{1'b0}};
            tone    <= 1'b0;
            beep_on <= 1'b1;
            sd_r    <= 1'b0;
        end else begin
            sd_r <= 1'b1;

            if (tcnt == HALF_TONE - 1) begin
                tcnt <= {TW{1'b0}};
                tone <= ~tone;
            end else begin
                tcnt <= tcnt + 1'b1;
            end

            if (bcnt == BEEP_CYC - 1) begin
                bcnt    <= {BW{1'b0}};
                beep_on <= ~beep_on;
            end else begin
                bcnt <= bcnt + 1'b1;
            end
        end
    end

    assign pwm_low = sd_r & beep_on & ~tone;
    assign aud_sd  = sd_r;
    assign blink   = sd_r & beep_on;

endmodule
