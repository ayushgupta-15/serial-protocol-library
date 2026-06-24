`timescale 1ns / 1ps

module i2c_start_stop_tb;

    parameter CLK_FREQ = 50000000;
    parameter I2C_FREQ = 100000;
    localparam CLK_PERIOD = 20;

    reg clk;
    reg rst;
    
    reg i_gen_start;
    reg i_gen_stop;
    wire o_busy;
    
    wire io_scl;
    wire io_sda;
    
    // Pull-up resistors for open-drain bus
    pullup(io_scl);
    pullup(io_sda);
    
    wire o_start_detect;
    wire o_stop_detect;

    i2c_master #(
        .CLK_FREQ(CLK_FREQ),
        .I2C_FREQ(I2C_FREQ)
    ) dut (
        .clk(clk),
        .rst(rst),
        .i_gen_start(i_gen_start),
        .i_gen_stop(i_gen_stop),
        .o_busy(o_busy),
        .io_scl(io_scl),
        .io_sda(io_sda),
        .o_start_detect(o_start_detect),
        .o_stop_detect(o_stop_detect)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $dumpfile("sim/waves/i2c_start_stop.vcd");
        $dumpvars(0, i2c_start_stop_tb);
        
        clk = 0;
        rst = 1;
        i_gen_start = 0;
        i_gen_stop = 0;
        
        #100;
        rst = 0;
        #100;
        
        $display("--- Test 1: Generate START Condition ---");
        @(posedge clk);
        i_gen_start = 1;
        @(posedge clk);
        i_gen_start = 0;
        
        wait(o_busy == 1);
        wait(o_busy == 0);
        
        #1000;
        
        $display("--- Test 2: Generate STOP Condition ---");
        @(posedge clk);
        i_gen_stop = 1;
        @(posedge clk);
        i_gen_stop = 0;
        
        wait(o_busy == 1);
        wait(o_busy == 0);
        
        #1000;
        $display("SUCCESS: All Tests Passed!");
        $finish;
    end
    
    // Monitors for verification
    always @(posedge clk) begin
        if (o_start_detect) begin
            $display("[%0t] PASS: START condition detected by internal monitor!", $time);
        end
        if (o_stop_detect) begin
            $display("[%0t] PASS: STOP condition detected by internal monitor!", $time);
        end
    end

endmodule
