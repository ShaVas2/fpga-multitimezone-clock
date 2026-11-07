module weekday (
    input  wire       clk,
    input  wire       rst,
    input  wire [4:0] day,
    input  wire [3:0] month,
    input  wire [6:0] year,
    output reg  [2:0] weekday
);

    function [2:0] tbl;
        input [3:0] m;
        begin
            case (m)
                4'd1:  tbl = 3'd0;  4'd2:  tbl = 3'd3;  4'd3:  tbl = 3'd2;
                4'd4:  tbl = 3'd5;  4'd5:  tbl = 3'd0;  4'd6:  tbl = 3'd3;
                4'd7:  tbl = 3'd5;  4'd8:  tbl = 3'd1;  4'd9:  tbl = 3'd4;
                4'd10: tbl = 3'd6;  4'd11: tbl = 3'd2;  default: tbl = 3'd4;
            endcase
        end
    endfunction

    function [2:0] mod7;
        input [12:0] x;
        reg   [5:0]  f1;
        reg   [3:0]  f2;
        reg   [3:0]  f3;
        begin
            f1   = x[2:0] + x[5:3] + x[8:6] + x[11:9] + {2'b00, x[12]};
            f2   = f1[2:0] + f1[5:3];
            f3   = f2[2:0] + {2'b00, f2[3]};
            mod7 = (f3 >= 4'd7) ? f3 - 4'd7 : f3[2:0];
        end
    endfunction

    wire        jan_feb = (month <= 4'd2);
    wire [11:0] Y       = 12'd2000 + {5'd0, year} - {11'd0, jan_feb};
    wire [12:0] sum     = {1'b0, Y} + {3'd0, Y[11:2]} - 13'd15
                        + {10'd0, tbl(month)} + {8'd0, day};

    reg  [12:0] sum_r;

    always @(posedge clk) begin
        if (rst) sum_r <= 13'd0;
        else     sum_r <= sum;
    end

    always @(posedge clk) begin
        if (rst) weekday <= 3'd0;
        else     weekday <= mod7(sum_r);
    end

endmodule
