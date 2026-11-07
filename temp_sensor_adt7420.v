module temp_sensor_adt7420 #(
    parameter CLK_HZ   = 100_000_000,
    parameter I2C_HZ   = 100_000,
    parameter POLL_MS  = 250,
    parameter DEV_ADDR = 7'h4B
)(
    input  wire               clk,
    input  wire               rst,
    input  wire               scl_i,
    input  wire               sda_i,
    output wire               scl_oe,
    output wire               sda_oe,
    output reg  signed [12:0] temp_raw,
    output reg                temp_valid,
    output reg                i2c_err
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

    localparam integer POLL_CYC = (CLK_HZ / 1000) * POLL_MS;
    localparam integer PW       = (clog2(POLL_CYC) < 1) ? 1 : clog2(POLL_CYC);

    localparam [1:0] CMD_START = 2'd0,
                     CMD_WRITE = 2'd1,
                     CMD_READ  = 2'd2,
                     CMD_STOP  = 2'd3;

    localparam [7:0] ADDR_W   = {DEV_ADDR[6:0], 1'b0};
    localparam [7:0] ADDR_R   = {DEV_ADDR[6:0], 1'b1};
    localparam [7:0] REG_TEMP = 8'h00;
    localparam [7:0] REG_CFG  = 8'h03;
    localparam [7:0] CFG_VAL  = 8'h00;

    localparam [3:0] S_INIT_START = 4'd0,
                     S_INIT_AW    = 4'd1,
                     S_INIT_REG   = 4'd2,
                     S_INIT_VAL   = 4'd3,
                     S_INIT_STOP  = 4'd4,
                     S_RD_START   = 4'd5,
                     S_RD_AW      = 4'd6,
                     S_RD_REG     = 4'd7,
                     S_RD_RSTART  = 4'd8,
                     S_RD_AR      = 4'd9,
                     S_RD_MSB     = 4'd10,
                     S_RD_LSB     = 4'd11,
                     S_RD_STOP    = 4'd12,
                     S_ERR_STOP   = 4'd13;

    localparam [1:0] C_ISSUE = 2'd0,
                     C_WAIT  = 2'd1,
                     C_DELAY = 2'd2;

    reg        cmd_valid;
    reg  [1:0] cmd;
    reg  [7:0] wr_data;
    reg        rd_nack;
    wire       cmd_ready;
    wire       done;
    wire [7:0] rd_data;
    wire       ack_err;

    i2c_master #(
        .CLK_HZ (CLK_HZ),
        .I2C_HZ (I2C_HZ)
    ) u_i2c (
        .clk       (clk),
        .rst       (rst),
        .cmd_valid (cmd_valid),
        .cmd       (cmd),
        .wr_data   (wr_data),
        .rd_nack   (rd_nack),
        .cmd_ready (cmd_ready),
        .done      (done),
        .rd_data   (rd_data),
        .ack_err   (ack_err),
        .scl_i     (scl_i),
        .sda_i     (sda_i),
        .scl_oe    (scl_oe),
        .sda_oe    (sda_oe)
    );

    reg [1:0] step_cmd;
    reg [7:0] step_data;
    reg       step_nack;
    reg [3:0] step;

    always @* begin
        step_data = 8'h00;
        step_nack = 1'b0;
        case (step)
            S_INIT_START: step_cmd = CMD_START;
            S_INIT_AW:    begin step_cmd = CMD_WRITE; step_data = ADDR_W;   end
            S_INIT_REG:   begin step_cmd = CMD_WRITE; step_data = REG_CFG;  end
            S_INIT_VAL:   begin step_cmd = CMD_WRITE; step_data = CFG_VAL;  end
            S_INIT_STOP:  step_cmd = CMD_STOP;
            S_RD_START:   step_cmd = CMD_START;
            S_RD_AW:      begin step_cmd = CMD_WRITE; step_data = ADDR_W;   end
            S_RD_REG:     begin step_cmd = CMD_WRITE; step_data = REG_TEMP; end
            S_RD_RSTART:  step_cmd = CMD_START;
            S_RD_AR:      begin step_cmd = CMD_WRITE; step_data = ADDR_R;   end
            S_RD_MSB:     begin step_cmd = CMD_READ;  step_nack = 1'b0;     end
            S_RD_LSB:     begin step_cmd = CMD_READ;  step_nack = 1'b1;     end
            default:      step_cmd = CMD_STOP;
        endcase
    end

    reg [1:0]    cstate;
    reg [3:0]    resume;
    reg [PW-1:0] dly;
    reg [7:0]    msb, lsb;

    always @(posedge clk) begin
        if (rst) begin
            cstate     <= C_ISSUE;
            step       <= S_INIT_START;
            resume     <= S_RD_START;
            dly        <= {PW{1'b0}};
            cmd_valid  <= 1'b0;
            cmd        <= CMD_STOP;
            wr_data    <= 8'h00;
            rd_nack    <= 1'b0;
            msb        <= 8'h00;
            lsb        <= 8'h00;
            temp_raw   <= 13'sd0;
            temp_valid <= 1'b0;
            i2c_err    <= 1'b0;
        end else begin
            cmd_valid <= 1'b0;

            case (cstate)

            C_ISSUE: begin
                if (cmd_ready) begin
                    cmd       <= step_cmd;
                    wr_data   <= step_data;
                    rd_nack   <= step_nack;
                    cmd_valid <= 1'b1;
                    cstate    <= C_WAIT;
                end
            end

            C_WAIT: begin
                if (done) begin
                    if (ack_err && step != S_ERR_STOP) begin

                        i2c_err <= 1'b1;
                        step    <= S_ERR_STOP;
                        cstate  <= C_ISSUE;
                    end else begin
                        case (step)
                            S_RD_MSB: begin
                                msb    <= rd_data;
                                step   <= S_RD_LSB;
                                cstate <= C_ISSUE;
                            end
                            S_RD_LSB: begin
                                lsb    <= rd_data;
                                step   <= S_RD_STOP;
                                cstate <= C_ISSUE;
                            end
                            S_INIT_STOP: begin
                                resume <= S_RD_START;
                                dly    <= POLL_CYC - 1;
                                cstate <= C_DELAY;
                            end
                            S_RD_STOP: begin
                                temp_raw   <= {msb, lsb[7:3]};
                                temp_valid <= 1'b1;
                                i2c_err    <= 1'b0;
                                resume     <= S_RD_START;
                                dly        <= POLL_CYC - 1;
                                cstate     <= C_DELAY;
                            end
                            S_ERR_STOP: begin
                                resume <= S_INIT_START;
                                dly    <= POLL_CYC - 1;
                                cstate <= C_DELAY;
                            end
                            default: begin
                                step   <= step + 1'b1;
                                cstate <= C_ISSUE;
                            end
                        endcase
                    end
                end
            end

            default: begin
                if (dly == {PW{1'b0}}) begin
                    step   <= resume;
                    cstate <= C_ISSUE;
                end else begin
                    dly <= dly - 1'b1;
                end
            end

            endcase
        end
    end

endmodule
