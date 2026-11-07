module reset_sync #(
    parameter STRETCH = 16
)(
    input  wire clk,
    input  wire rst_btn_n,
    output wire rst
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

    localparam CW = (clog2(STRETCH) < 1) ? 1 : clog2(STRETCH);

    (* ASYNC_REG = "TRUE" *) reg [1:0] sync = 2'b00;
    reg [CW-1:0] cnt   = {CW{1'b0}};
    reg          rst_r = 1'b1;

    always @(posedge clk) begin
        sync <= {sync[0], rst_btn_n};
    end

    always @(posedge clk) begin
        if (!sync[1]) begin
            cnt   <= {CW{1'b0}};
            rst_r <= 1'b1;
        end else if (cnt != STRETCH - 1) begin
            cnt   <= cnt + 1'b1;
            rst_r <= 1'b1;
        end else begin
            rst_r <= 1'b0;
        end
    end

    assign rst = rst_r;

endmodule
