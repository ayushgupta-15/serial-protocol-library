`timescale 1ns / 1ps

module baud_gen_tb;

    parameter CLK_FREQ = 50000000;
    parameter BAUD_RATE = 115200;
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    reg clk;
    reg rst;
    wire baud_tick;

    baud_gen #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst(rst),
        .baud_tick(baud_tick)
    );

    always #10 clk = ~clk;

    initial begin
        $dumpfile("sim/waves/baud_gen.vcd");
        $dumpvars(0, baud_gen_tb);

        clk = 0;
        rst = 1;
        #100;
        rst = 0;
        
        // Wait for first tick
        @(posedge baud_tick);
        $display("Tick 1 occurred at time %0t", $time);
        
        // Wait for second tick to check period
        @(posedge baud_tick);
        $display("Tick 2 occurred at time %0t", $time);
        
        #100;
        $display("Baud generator test completed.");
        $finish;
    end

endmodule
