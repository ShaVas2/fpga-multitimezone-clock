module rgb_mood #(
    parameter SHIFT = 3
)(
    input  wire               clk,
    input  wire               rst,
    input  wire signed [12:0] temp_raw,
    input  wire               temp_valid,
    input  wire               temp_err,
    input  wire [2:0]         city_sel,
    output reg                led16_r,
    output reg                led16_g,
    output reg                led16_b,
    output reg                led17_r,
    output reg                led17_g,
    output reg                led17_b
);

    wire signed [13:0] rel = {temp_raw[12], temp_raw} - 14'sd256;
    wire [7:0] t = (rel < 0) ? 8'd0 : (rel > 14'sd255) ? 8'd255 : rel[7:0];

    reg [7:0] r16, g16, b16;

    always @(posedge clk) begin
        if (rst || !temp_valid) begin
            r16 <= 8'd0;   g16 <= 8'd0;   b16 <= 8'd0;
        end else if (temp_err) begin
            r16 <= 8'd64;  g16 <= 8'd0;   b16 <= 8'd0;
        end else if (!t[7]) begin
            r16 <= 8'd0;
            g16 <= {t[6:0], 1'b0};
            b16 <= 8'd255 - {t[6:0], 1'b0};
        end else begin
            r16 <= {t[6:0], 1'b0};
            g16 <= 8'd255 - {t[6:0], 1'b0};
            b16 <= 8'd0;
        end
    end

    reg [7:0] r17, g17, b17;

    always @(posedge clk) begin
        if (rst) begin
            r17 <= 8'd0; g17 <= 8'd0; b17 <= 8'd0;
        end else begin
            case (city_sel)
                3'd0: begin r17 <= 8'd255; g17 <= 8'd80;  b17 <= 8'd0;   end
                3'd1: begin r17 <= 8'd170; g17 <= 8'd170; b17 <= 8'd170; end
                3'd2: begin r17 <= 8'd0;   g17 <= 8'd0;   b17 <= 8'd255; end
                3'd4: begin r17 <= 8'd255; g17 <= 8'd0;   b17 <= 8'd0;   end
                3'd5: begin r17 <= 8'd0;   g17 <= 8'd255; b17 <= 8'd0;   end
                default: begin r17 <= 8'd150; g17 <= 8'd0; b17 <= 8'd255; end
            endcase
        end
    end

    reg [7:0] pwm;

    always @(posedge clk) begin
        if (rst) begin
            pwm     <= 8'd0;
            led16_r <= 1'b0; led16_g <= 1'b0; led16_b <= 1'b0;
            led17_r <= 1'b0; led17_g <= 1'b0; led17_b <= 1'b0;
        end else begin
            pwm     <= pwm + 1'b1;
            led16_r <= pwm < (r16 >> SHIFT);
            led16_g <= pwm < (g16 >> SHIFT);
            led16_b <= pwm < (b16 >> SHIFT);
            led17_r <= pwm < (r17 >> SHIFT);
            led17_g <= pwm < (g17 >> SHIFT);
            led17_b <= pwm < (b17 >> SHIFT);
        end
    end

endmodule
