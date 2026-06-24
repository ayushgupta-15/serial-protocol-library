`timescale 1ns / 1ps

module uart_tx_tb;

    parameter CLK_FREQ  = 50000000;
    parameter BAUD_RATE = 115200;
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    reg        clk;
    reg        rst;
    reg        i_tx_dv;
    reg  [7:0] i_tx_byte;
    
    wire       o_tx_serial;
    wire       o_tx_done;
    
    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst(rst),
        .i_tx_dv(i_tx_dv),
        .i_tx_byte(i_tx_byte),
        .o_tx_serial(o_tx_serial),
        .o_tx_done(o_tx_done)
    );
    
    // 50 MHz clock generation -> 20ns period -> 10ns half-period
    always #10 clk = ~clk;
    
    initial begin
        $dumpfile("sim/uart_tx.vcd");
        $dumpvars(0, uart_tx_tb);
        
        clk = 0;
        rst = 1;
        i_tx_dv = 0;
        i_tx_byte = 8'h00;
        
        #100;
        rst = 0;
        #100;
        
        // Test 1: Transmit 0x00
        $display("Starting Test 1: Transmit 0x00");
        @(posedge clk);
        i_tx_byte <= 8'h00;
        i_tx_dv <= 1;
        @(posedge clk);
        i_tx_dv <= 0;
        
        @(posedge o_tx_done);
        @(posedge clk);
        $display("Test 1 Finished");
        #1000;
        
        // Test 2: Transmit 0xFF
        $display("Starting Test 2: Transmit 0xFF");
        @(posedge clk);
        i_tx_byte <= 8'hFF;
        i_tx_dv <= 1;
        @(posedge clk);
        i_tx_dv <= 0;
        
        @(posedge o_tx_done);
        @(posedge clk);
        $display("Test 2 Finished");
        #1000;
        
        // Test 3: Transmit 0x55 (01010101)
        $display("Starting Test 3: Transmit 0x55");
        @(posedge clk);
        i_tx_byte <= 8'h55;
        i_tx_dv <= 1;
        @(posedge clk);
        i_tx_dv <= 0;
        
        @(posedge o_tx_done);
        @(posedge clk);
        $display("Test 3 Finished");
        #1000;
        
        $display("All tests completed successfully.");
        $finish;
    end

endmodule
