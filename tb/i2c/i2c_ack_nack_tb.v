`timescale 1ns / 1ps

module i2c_ack_nack_tb;

    parameter CLK_FREQ = 50000000;
    parameter I2C_FREQ = 100000;
    localparam CLK_PERIOD = 20;

    reg clk;
    reg rst;
    
    reg        i_gen_start;
    reg        i_gen_stop;
    reg        i_send_byte;
    reg  [7:0] i_tx_data;
    wire       o_busy;
    wire       o_done;
    wire       o_ack_error;
    
    wire io_scl;
    wire io_sda;
    
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
        .i_send_byte(i_send_byte),
        .i_tx_data(i_tx_data),
        .o_busy(o_busy),
        .o_done(o_done),
        .o_ack_error(o_ack_error),
        .io_scl(io_scl),
        .io_sda(io_sda),
        .o_start_detect(o_start_detect),
        .o_stop_detect(o_stop_detect)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // Simple Slave ACK Generation
    reg ack_enable = 0;
    assign io_sda = ack_enable ? 1'b0 : 1'bz;
    
    task send_byte;
        input [7:0] data;
        input       force_ack;
        begin
            @(posedge clk);
            i_tx_data = data;
            i_send_byte = 1;
            @(posedge clk);
            i_send_byte = 0;
            
            // Wait for 8 SCL falling edges (the 8 data bits)
            repeat(8) @(negedge io_scl);
            
            // At the end of the 8th bit, slave decides to pull ACK or not
            if (force_ack) ack_enable = 1;
            
            // Wait for 9th SCL falling edge (end of ACK cycle)
            @(negedge io_scl);
            ack_enable = 0;
            
            // Wait for master to say done
            wait(o_done == 1);
            @(posedge clk);
        end
    endtask

    integer err_count = 0;
    integer i;

    initial begin
        $dumpfile("sim/waves/i2c_ack_nack.vcd");
        $dumpvars(0, i2c_ack_nack_tb);
        
        clk = 0;
        rst = 1;
        i_gen_start = 0;
        i_gen_stop = 0;
        i_send_byte = 0;
        i_tx_data = 0;
        
        #100;
        rst = 0;
        #100;
        
        // Setup initial bus state (IDLE) -> Generate START to pull SCL low.
        @(posedge clk);
        i_gen_start = 1;
        @(posedge clk);
        i_gen_start = 0;
        wait(o_done == 1);
        @(posedge clk);
        
        $display("--- Test 1: Slave ACK (Expect ACK Error = 0) ---");
        send_byte(8'h55, 1); // 1 means force_ack
        if (o_ack_error === 0)
            $display("PASS: Received ACK");
        else begin
            $display("FAIL: Expected ACK, got NACK");
            err_count = err_count + 1;
        end
        
        $display("--- Test 2: Slave NACK (Expect ACK Error = 1) ---");
        send_byte(8'hAA, 0); // 0 means do not drive ACK (NACK)
        if (o_ack_error === 1)
            $display("PASS: Received NACK");
        else begin
            $display("FAIL: Expected NACK, got ACK");
            err_count = err_count + 1;
        end
        
        $display("--- Test 3: Random Bytes Regression (ACK) ---");
        for (i = 0; i < 4; i = i + 1) begin
            send_byte($random, 1);
            if (o_ack_error !== 0) begin
                $display("FAIL: Expected ACK during regression.");
                err_count = err_count + 1;
            end
        end
        
        // Stop
        @(posedge clk);
        i_gen_stop = 1;
        @(posedge clk);
        i_gen_stop = 0;
        wait(o_done == 1);
        
        if (err_count == 0)
            $display("SUCCESS: All ACK/NACK tests passed!");
        else
            $display("FAILURE: %0d errors found.", err_count);
            
        $finish;
    end

endmodule
