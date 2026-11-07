module adxl362_spi #(
    parameter CLK_HZ    = 100_000_000,
    parameter SCLK_HZ   = 1_000_000,
    parameter SAMPLE_MS = 10
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              acl_miso,
    output reg               acl_mosi,
    output reg               acl_sclk,
    output reg               acl_csn,
    output reg signed [7:0]  acc_x,
    output reg signed [7:0]  acc_y,
    output reg signed [7:0]  acc_z,
    output reg               sample_valid
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

    localparam integer HALF   = CLK_HZ / (2 * SCLK_HZ);
    localparam integer HW     = (clog2(HALF) < 1) ? 1 : clog2(HALF);
    localparam integer WAIT10 = (CLK_HZ / 1000) * 10;
    localparam integer SAMPLE = (CLK_HZ / 1000) * SAMPLE_MS;
    localparam integer DLY    = (WAIT10 > SAMPLE) ? WAIT10 : SAMPLE;
    localparam integer DW     = (clog2(DLY + 1) < 1) ? 1 : clog2(DLY + 1);

    localparam [1:0] Q_RESET = 2'd0,
                     Q_POWER = 2'd1,
                     Q_READ  = 2'd2;

    localparam [2:0] E_DELAY = 3'd0,
                     E_START = 3'd1,
                     E_LOW   = 3'd2,
                     E_HIGH  = 3'd3,
                     E_END   = 3'd4;

    (* ASYNC_REG = "TRUE" *) reg miso_s0, miso_s1;

    always @(posedge clk) begin
        miso_s0 <= acl_miso;
        miso_s1 <= miso_s0;
    end

    reg [2:0]    est;
    reg [1:0]    step;
    reg [DW-1:0] dly;
    reg [HW-1:0] hcnt;
    reg [2:0]    bitn;
    reg [2:0]    byten;
    reg [2:0]    nbytes;
    reg [7:0]    tx, rx;
    reg [7:0]    rx0, rx1;

    function [7:0] tx_byte;
        input [1:0] s;
        input [2:0] b;
        begin
            case (s)
                Q_RESET: tx_byte = (b == 3'd0) ? 8'h0A : (b == 3'd1) ? 8'h1F : 8'h52;
                Q_POWER: tx_byte = (b == 3'd0) ? 8'h0A : (b == 3'd1) ? 8'h2D : 8'h02;
                default: tx_byte = (b == 3'd0) ? 8'h0B : (b == 3'd1) ? 8'h08 : 8'h00;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            est          <= E_DELAY;
            step         <= Q_RESET;
            dly          <= WAIT10 - 1;
            hcnt         <= {HW{1'b0}};
            bitn         <= 3'd7;
            byten        <= 3'd0;
            nbytes       <= 3'd3;
            tx           <= 8'h00;
            rx           <= 8'h00;
            rx0          <= 8'h00;
            rx1          <= 8'h00;
            acl_csn      <= 1'b1;
            acl_sclk     <= 1'b0;
            acl_mosi     <= 1'b0;
            acc_x        <= 8'sd0;
            acc_y        <= 8'sd0;
            acc_z        <= 8'sd0;
            sample_valid <= 1'b0;
        end else begin
            sample_valid <= 1'b0;

            case (est)
            E_DELAY: begin
                if (dly == {DW{1'b0}}) begin
                    est <= E_START;
                end else begin
                    dly <= dly - 1'b1;
                end
            end

            E_START: begin
                acl_csn  <= 1'b0;
                acl_sclk <= 1'b0;
                byten    <= 3'd0;
                bitn     <= 3'd7;
                nbytes   <= (step == Q_READ) ? 3'd5 : 3'd3;
                tx       <= tx_byte(step, 3'd0);
                acl_mosi <= tx_byte(step, 3'd0) >> 7;
                hcnt     <= HALF - 1;
                est      <= E_LOW;
            end

            E_LOW: begin
                if (hcnt == {HW{1'b0}}) begin
                    acl_sclk <= 1'b1;
                    hcnt     <= HALF - 1;
                    est      <= E_HIGH;
                end else begin
                    hcnt <= hcnt - 1'b1;
                end
            end

            E_HIGH: begin
                if (hcnt == {HW{1'b0}}) begin

                    rx       <= {rx[6:0], miso_s1};
                    acl_sclk <= 1'b0;
                    hcnt     <= HALF - 1;
                    if (bitn != 3'd0) begin
                        bitn     <= bitn - 1'b1;
                        acl_mosi <= tx[bitn - 1'b1];
                        est      <= E_LOW;
                    end else begin

                        if (step == Q_READ) begin
                            if (byten == 3'd2) rx0 <= {rx[6:0], miso_s1};
                            if (byten == 3'd3) rx1 <= {rx[6:0], miso_s1};
                            if (byten == 3'd4) begin
                                acc_x        <= rx0;
                                acc_y        <= rx1;
                                acc_z        <= {rx[6:0], miso_s1};
                                sample_valid <= 1'b1;
                            end
                        end
                        if (byten == nbytes - 1'b1) begin
                            est <= E_END;
                        end else begin
                            byten    <= byten + 1'b1;
                            bitn     <= 3'd7;
                            tx       <= tx_byte(step, byten + 1'b1);
                            acl_mosi <= tx_byte(step, byten + 1'b1) >> 7;
                            est      <= E_LOW;
                        end
                    end
                end else begin
                    hcnt <= hcnt - 1'b1;
                end
            end

            default: begin
                if (hcnt == {HW{1'b0}}) begin
                    acl_csn  <= 1'b1;
                    acl_mosi <= 1'b0;
                    case (step)
                        Q_RESET: begin step <= Q_POWER; dly <= WAIT10 - 1; end
                        Q_POWER: begin step <= Q_READ;  dly <= WAIT10 - 1; end
                        default: begin step <= Q_READ;  dly <= SAMPLE - 1; end
                    endcase
                    est <= E_DELAY;
                end else begin
                    hcnt <= hcnt - 1'b1;
                end
            end
            endcase
        end
    end

endmodule
