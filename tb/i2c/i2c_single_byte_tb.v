`timescale 1ns / 1ps

module i2c_single_byte_tb;

    parameter CLK_FREQ = 50000000;
    parameter I2C_FREQ = 100000;
    localparam CLK_PERIOD = 20;

    reg clk;
    reg rst;
    
    reg        i_gen_start;
    reg        i_gen_stop;
    reg        i_send_byte;
    reg        i_cmd_write;
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
        .i_cmd_write(i_cmd_write),
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

    // Auto-ACK Generation
    reg ack_enable = 0;
    assign io_sda = ack_enable ? 1'b0 : 1'bz;
    
    integer scl_fall_count = 0;
    reg force_nack = 0;
    
    always @(posedge clk) begin
        if (!o_busy) begin
            scl_fall_count = 0;
            ack_enable = 0;
        end
    end
    
    always @(negedge io_scl) begin
        if (o_busy) begin
            scl_fall_count = scl_fall_count + 1;
            
            if (scl_fall_count == 9) begin
                if (!force_nack) ack_enable = 1;
            end else if (scl_fall_count == 10) begin
                ack_enable = 0;
            end
        end
    end
    
    task do_write;
        input [7:0] data;
        input nack_test;
        begin
            force_nack = nack_test;
            @(posedge clk);
            i_tx_data = data;
            i_cmd_write = 1;
            @(posedge clk);
            i_cmd_write = 0;
            
            wait(o_done == 1);
            @(posedge clk);
        end
    endtask

    integer err_count = 0;
    integer i;
    reg [7:0] r_data;

    initial begin
        $dumpfile("sim/waves/i2c_single_byte.vcd");
        $dumpvars(0, i2c_single_byte_tb);
        
        clk = 0;
        rst = 1;
        i_gen_start = 0;
        i_gen_stop = 0;
        i_send_byte = 0;
        i_cmd_write = 0;
        i_tx_data = 0;
        
        #100;
        rst = 0;
        #100;
        
        $display("--- Test 1: Send 0x55 (ACK Expected) ---");
        do_write(8'h55, 0);
        if (o_ack_error === 0)
            $display("PASS: Received ACK, Transaction Completed.");
        else begin
            $display("FAIL: Expected ACK, got NACK");
            err_count = err_count + 1;
        end
        
        $display("--- Test 2: Send 0xAA (ACK Expected) ---");
        do_write(8'hAA, 0);
        if (o_ack_error === 0)
            $display("PASS: Received ACK, Transaction Completed.");
        else begin
            $display("FAIL: Expected ACK, got NACK");
            err_count = err_count + 1;
        end
        
        $display("--- Test 3: 50 Random Bytes (All ACKed) ---");
        for (i = 0; i < 50; i = i + 1) begin
            r_data = $random;
            do_write(r_data, 0);
            if (o_ack_error !== 0) begin
                $display("FAIL: Expected ACK at iter %0d", i);
                err_count = err_count + 1;
            end
        end
        
        $display("--- Test 4: 50 Random Bytes (NACK every 5th) ---");
        for (i = 1; i <= 50; i = i + 1) begin
            r_data = $random;
            if (i % 5 == 0) begin
                do_write(r_data, 1); // Force NACK
                if (o_ack_error !== 1) begin
                    $display("FAIL: Expected NACK at iter %0d", i);
                    err_count = err_count + 1;
                end
            end else begin
                do_write(r_data, 0);
                if (o_ack_error !== 0) begin
                    $display("FAIL: Expected ACK at iter %0d", i);
                    err_count = err_count + 1;
                end
            end
        end
        
        if (err_count == 0)
            $display("\nSUCCESS: All Single-Byte Write tests passed!");
        else
            $display("\nFAILURE: %0d errors found.", err_count);
            
        $finish;
    end

endmodule
