`timescale 1ns / 1ps
// Simulation testbench for clock_top (Vivado behavioural simulation).

module tb_clock_top;

    reg        clk   = 1'b0;
    reg        rst_n = 1'b0;
    reg        btnc = 0, btnu = 0, btnd = 0, btnl = 0, btnr = 0;
    reg  [2:0] sw   = 3'b000;
    reg        sw14 = 1'b0;

    wire [15:0] led;
    wire [7:0]  an;
    wire        ca, cb, cc, cd, ce, cf, cg, dp;
    wire        aud_pwm, aud_sd;
    wire        acl_mosi, acl_sclk, acl_csn;
    wire        l16r, l16g, l16b, l17r, l17g, l17b;
    wire        tmp_scl, tmp_sda;
    pullup (tmp_scl);                      // I2C pull-ups 
    pullup (tmp_sda);

    always #5 clk = ~clk;                  

    clock_top #(
        .CLK_HZ      (2_000_000),
        .DEBOUNCE_MS (1)
    ) uut (
        .CLK100MHZ (clk),     .CPU_RESETN (rst_n),
        .BTNC (btnc), .BTNU (btnu), .BTND (btnd), .BTNL (btnl), .BTNR (btnr),
        .SW (sw), .LED (led),
        .CA (ca), .CB (cb), .CC (cc), .CD (cd), .CE (ce), .CF (cf), .CG (cg), .DP (dp),
        .AN (an),
        .TMP_SCL (tmp_scl), .TMP_SDA (tmp_sda),
        .AUD_PWM (aud_pwm), .AUD_SD (aud_sd),
        .SW14 (sw14),
        .ACL_MISO (1'b0), .ACL_MOSI (acl_mosi), .ACL_SCLK (acl_sclk), .ACL_CSN (acl_csn),
        .LED16_R (l16r), .LED16_G (l16g), .LED16_B (l16b),
        .LED17_R (l17r), .LED17_G (l17g), .LED17_B (l17b)
    );

    //Decode the 7-segment display into readable text 
    reg [63:0] display_text = "        ";
    reg [7:0]  ch;
    wire [6:0] seg = ~{cg, cf, ce, cd, cc, cb, ca};
    integer k;
    always @(posedge clk) begin
        case (seg)
            7'h3F: ch = "0";  7'h06: ch = "1";  7'h5B: ch = "2";  7'h4F: ch = "3";
            7'h66: ch = "4";  7'h6D: ch = "5";  7'h7D: ch = "6";  7'h07: ch = "7";
            7'h7F: ch = "8";  7'h6F: ch = "9";  7'h00: ch = " ";  7'h40: ch = "-";
            7'h39: ch = "C";  7'h63: ch = "o";  7'h54: ch = "n";  7'h78: ch = "t";
            7'h73: ch = "P";  7'h38: ch = "L";  7'h7C: ch = "b";  7'h79: ch = "E";
            7'h50: ch = "r";  7'h76: ch = "H";  7'h77: ch = "A";  7'h5C: ch = "o";
            7'h71: ch = "F";  7'h3E: ch = "U";  7'h5E: ch = "d";  7'h74: ch = "h";
            default: ch = "?";
        endcase
        for (k = 0; k < 8; k = k + 1)
            if (!an[k]) display_text[k*8 +: 8] <= ch;
    end

    // Button press: held for 0.1 ms, longer than the sim debounce
    //      (CLK_HZ/1000 * 1 ms = 2000 cycles = 20 us) ----
    task press;
        input integer which;   // 0 C, 1 U, 2 D, 3 L, 4 R
        begin
            case (which)
                0: btnc = 1; 1: btnu = 1; 2: btnd = 1; 3: btnl = 1; 4: btnr = 1;
            endcase
            #100_000;
            btnc = 0; btnu = 0; btnd = 0; btnl = 0; btnr = 0;
            #100_000;
        end
    endtask

    localparam C = 0, U = 1, D = 2, L = 3, R = 4;
    localparam SEC = 20_000_000;            // one clock second in ns (20 ms)

    initial begin
        // 1. Reset
        #1_000;  rst_n = 1;
        // 2. Let the clock run for 2 seconds (TIME screen, India 05:30:00)
        #(2*SEC);
        // 3. Set the time: hour + 1, minute + 1
        press(U); press(D);
        // 4. DATE screen
        press(C);
        // 5. STOPWATCH: start, run 0.5 s, stop
        press(C); press(L); #(SEC/2); press(L);
        // 6. TIMER: set 2 s, start, let it ring for a bit
        press(C); press(D); press(D); press(L);
        #(3*SEC);
        // 7. Silence it with any button
        press(R);
        // 8. Back to TIME (TIMER -> ALARM -> TEMP -> TIME) and pick New York
        press(C); press(C); press(C);
        sw = 3'b101;
        #(SEC);
        $display("Simulation finished at %0t ns", $time);
        $finish;
    end

endmodule
