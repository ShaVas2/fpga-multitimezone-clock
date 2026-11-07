module alarm_clock (
    input  wire       clk,
    input  wire       rst,
    input  wire [4:0] ist_hour,
    input  wire [5:0] ist_min,
    input  wire [5:0] sec,
    input  wire       inc_hour,
    input  wire       inc_min,
    input  wire       toggle,
    input  wire       any_btn,
    output reg  [4:0] al_hour,
    output reg  [5:0] al_min,
    output reg        armed,
    output reg        ringing
);

    wire match = armed && (ist_hour == al_hour) && (ist_min == al_min)
                       && (sec == 6'd0);
    reg  match_d;

    always @(posedge clk) begin
        if (rst) begin
            al_hour <= 5'd7;
            al_min  <= 6'd0;
            armed   <= 1'b0;
            ringing <= 1'b0;
            match_d <= 1'b0;
        end else begin
            match_d <= match;

            if (ringing && any_btn) begin
                ringing <= 1'b0;
            end else begin
                if (match && !match_d)
                    ringing <= 1'b1;

                if (toggle) begin
                    armed <= ~armed;
                    if (armed)
                        ringing <= 1'b0;
                end
                if (inc_hour)
                    al_hour <= (al_hour >= 5'd23) ? 5'd0 : al_hour + 1'b1;
                if (inc_min)
                    al_min  <= (al_min  >= 6'd59) ? 6'd0 : al_min  + 1'b1;
            end
        end
    end

endmodule
