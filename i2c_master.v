module i2c_master #(
    parameter CLK_HZ     = 100_000_000,
    parameter I2C_HZ     = 100_000,
    parameter STRETCH_MS = 1
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       cmd_valid,
    input  wire [1:0] cmd,
    input  wire [7:0] wr_data,
    input  wire       rd_nack,
    output wire       cmd_ready,
    output reg        done,
    output reg  [7:0] rd_data,
    output reg        ack_err,
    input  wire       scl_i,
    input  wire       sda_i,
    output wire       scl_oe,
    output wire       sda_oe
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

    localparam integer QDIV   = CLK_HZ / (4 * I2C_HZ);
    localparam integer Q_M1   = QDIV - 1;
    localparam integer H_M1   = 2 * QDIV - 1;
    localparam integer TW     = (clog2(2 * QDIV) < 1) ? 1 : clog2(2 * QDIV);
    localparam integer SMAX   = (CLK_HZ / 1000) * STRETCH_MS;
    localparam integer SW     = (clog2(SMAX + 1) < 1) ? 1 : clog2(SMAX + 1);

    localparam [1:0] CMD_START = 2'd0,
                     CMD_WRITE = 2'd1,
                     CMD_READ  = 2'd2,
                     CMD_STOP  = 2'd3;

    localparam [1:0] ST_IDLE  = 2'd0,
                     ST_START = 2'd1,
                     ST_BYTE  = 2'd2,
                     ST_STOP  = 2'd3;

    (* ASYNC_REG = "TRUE" *) reg scl_s0, scl_s1;
    (* ASYNC_REG = "TRUE" *) reg sda_s0, sda_s1;

    always @(posedge clk) begin
        scl_s0 <= scl_i;  scl_s1 <= scl_s0;
        sda_s0 <= sda_i;  sda_s1 <= sda_s0;
    end

    wire scl_hi = scl_s1;
    wire sda_in = sda_s1;

    reg [1:0]    state;
    reg [1:0]    ph;
    reg [3:0]    bitn;
    reg [TW-1:0] tmr;
    reg [SW-1:0] scnt;
    reg [7:0]    sh;
    reg          is_read;
    reg          nack_r;
    reg          scl_oe_r;
    reg          sda_oe_r;

    wire wait_scl = (state != ST_IDLE) && (ph == 2'd2);
    wire tmr_zero = (tmr == {TW{1'b0}});
    wire adv      = tmr_zero && (!wait_scl || scl_hi);

    assign cmd_ready = (state == ST_IDLE);
    assign scl_oe    = scl_oe_r;
    assign sda_oe    = sda_oe_r;

    always @(posedge clk) begin
        if (rst) begin
            state    <= ST_IDLE;
            ph       <= 2'd0;
            bitn     <= 4'd0;
            tmr      <= {TW{1'b0}};
            scnt     <= {SW{1'b0}};
            sh       <= 8'd0;
            is_read  <= 1'b0;
            nack_r   <= 1'b0;
            scl_oe_r <= 1'b0;
            sda_oe_r <= 1'b0;
            done     <= 1'b0;
            rd_data  <= 8'd0;
            ack_err  <= 1'b0;
        end else begin
            done <= 1'b0;

            if (!tmr_zero && (!wait_scl || scl_hi))
                tmr <= tmr - 1'b1;

            if (wait_scl && !scl_hi)
                scnt <= scnt + 1'b1;
            else
                scnt <= {SW{1'b0}};

            if (wait_scl && !scl_hi && (scnt == SMAX)) begin

                state    <= ST_IDLE;
                ph       <= 2'd0;
                scl_oe_r <= 1'b0;
                sda_oe_r <= 1'b0;
                ack_err  <= 1'b1;
                done     <= 1'b1;
            end else begin
                case (state)

                ST_IDLE: begin
                    if (cmd_valid) begin
                        ph      <= 2'd0;
                        tmr     <= Q_M1;
                        ack_err <= 1'b0;
                        case (cmd)
                            CMD_START: begin
                                state <= ST_START;
                            end
                            CMD_WRITE: begin
                                state   <= ST_BYTE;
                                bitn    <= 4'd0;
                                sh      <= wr_data;
                                is_read <= 1'b0;
                            end
                            CMD_READ: begin
                                state   <= ST_BYTE;
                                bitn    <= 4'd0;
                                sh      <= 8'd0;
                                is_read <= 1'b1;
                                nack_r  <= rd_nack;
                            end
                            default: begin
                                state <= ST_STOP;
                            end
                        endcase
                    end
                end

                ST_START: begin
                    if (adv) begin
                        case (ph)
                            2'd0: begin ph <= 2'd1; sda_oe_r <= 1'b0; tmr <= Q_M1; end
                            2'd1: begin ph <= 2'd2; scl_oe_r <= 1'b0; tmr <= H_M1; end
                            2'd2: begin ph <= 2'd3; sda_oe_r <= 1'b1; tmr <= H_M1; end
                            default: begin
                                scl_oe_r <= 1'b1;
                                state    <= ST_IDLE;
                                done     <= 1'b1;
                            end
                        endcase
                    end
                end

                ST_BYTE: begin
                    if (adv) begin
                        case (ph)
                            2'd0: begin
                                ph  <= 2'd1;
                                tmr <= Q_M1;
                                if (bitn != 4'd8)
                                    sda_oe_r <= is_read ? 1'b0 : ~sh[7];
                                else
                                    sda_oe_r <= is_read ? ~nack_r : 1'b0;
                            end
                            2'd1: begin
                                ph       <= 2'd2;
                                tmr      <= Q_M1;
                                scl_oe_r <= 1'b0;
                            end
                            2'd2: begin
                                ph  <= 2'd3;
                                tmr <= Q_M1;
                                if (bitn != 4'd8)
                                    sh <= {sh[6:0], sda_in};
                                else if (!is_read)
                                    ack_err <= sda_in;
                            end
                            default: begin
                                scl_oe_r <= 1'b1;
                                if (bitn == 4'd8) begin
                                    if (is_read)
                                        rd_data <= sh;

                                    state <= ST_IDLE;
                                    done  <= 1'b1;
                                end else begin
                                    bitn <= bitn + 1'b1;
                                    ph   <= 2'd0;
                                    tmr  <= Q_M1;
                                end
                            end
                        endcase
                    end
                end

                default: begin
                    if (adv) begin
                        case (ph)
                            2'd0: begin ph <= 2'd1; sda_oe_r <= 1'b1; tmr <= Q_M1; end
                            2'd1: begin ph <= 2'd2; scl_oe_r <= 1'b0; tmr <= H_M1; end
                            2'd2: begin ph <= 2'd3; sda_oe_r <= 1'b0; tmr <= H_M1; end
                            default: begin
                                state <= ST_IDLE;
                                done  <= 1'b1;
                            end
                        endcase
                    end
                end

                endcase
            end
        end
    end

endmodule
