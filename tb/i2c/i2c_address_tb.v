`timescale 1ns / 1ps

module i2c_address_tb;

    parameter CLK_FREQ = 50000000;
    parameter I2C_FREQ = 100000;
    localparam CLK_PERIOD = 20;

    reg clk;
    reg rst;
    
    reg        i_gen_start;
    reg        i_gen_stop;
    reg        i_send_byte;
    reg        i_cmd_write;
    reg  [6:0] i_slave_addr;
    reg        i_rw;
    reg  [7:0] i_tx_data;
    wire       o_busy;
    wire       o_done;
    wire       o_ack_error;
    
    wire io_scl;
    wire io_sda;
    
    pullup(io_scl);
    pullup(io_sda);

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
        .i_slave_addr(i_slave_addr),
        .i_rw(i_rw),
        .i_tx_data(i_tx_data),
        .o_busy(o_busy),
        .o_done(o_done),
        .o_ack_error(o_ack_error),
        .io_scl(io_scl),
        .io_sda(io_sda),
        .o_start_detect(),
        .o_stop_detect()
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // Advanced Auto-ACK Generation (Decodes Address)
    reg ack_enable = 0;
    assign io_sda = ack_enable ? 1'b0 : 1'bz;
    
    integer scl_fall_count = 0;
    reg [7:0] rx_byte = 0;
    
    // Define the valid slave address
    localparam VALID_SLAVE_ADDR = 7'h48;
    
    reg is_addr_match = 0;
    
    always @(posedge clk) begin
        if (!o_busy) begin
            scl_fall_count = 0;
            ack_enable = 0;
            rx_byte = 0;
            is_addr_match = 0;
        end
    end
    
    // Sample SDA on SCL rising edge
    always @(posedge io_scl) begin
        if (o_busy) begin
            rx_byte = {rx_byte[6:0], io_sda};
        end
    end
    
    always @(negedge io_scl) begin
        if (o_busy) begin
            scl_fall_count = scl_fall_count + 1;
            
            // End of First Byte (Address Phase)
            if (scl_fall_count == 9) begin
                if (rx_byte[7:1] == VALID_SLAVE_ADDR) begin
                    is_addr_match = 1;
                    ack_enable = 1; // ACK the address
                end else begin
                    is_addr_match = 0;
                    ack_enable = 0; // NACK the address
                end
            end else if (scl_fall_count == 10) begin
                ack_enable = 0;
            end 
            // End of Second Byte (Data Phase)
            else if (scl_fall_count == 18) begin
                if (is_addr_match) begin
                    ack_enable = 1; // ACK the data
                end
            end else if (scl_fall_count == 19) begin
                ack_enable = 0;
            end
        end
    end
    
    task do_write;
        input [6:0] addr;
        input [7:0] data;
        begin
            @(posedge clk);
            i_slave_addr = addr;
            i_rw = 0; // Write
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
    reg [6:0] r_addr;

    initial begin
        $dumpfile("sim/waves/i2c_address.vcd");
        $dumpvars(0, i2c_address_tb);
        
        clk = 0;
        rst = 1;
        i_gen_start = 0;
        i_gen_stop = 0;
        i_send_byte = 0;
        i_cmd_write = 0;
        i_slave_addr = 0;
        i_rw = 0;
        i_tx_data = 0;
        
        #100;
        rst = 0;
        #100;
        
        $display("--- Test 1: Valid Address (0x48) - Expect ACK ---");
        do_write(7'h48, 8'h55);
        if (o_ack_error === 0)
            $display("PASS: Received ACK for Address and Data");
        else begin
            $display("FAIL: Expected ACK, got NACK");
            err_count = err_count + 1;
        end
        
        $display("--- Test 2: Invalid Address (0x33) - Expect NACK ---");
        do_write(7'h33, 8'hAA);
        if (o_ack_error === 1)
            $display("PASS: Received NACK immediately after Address");
        else begin
            $display("FAIL: Expected NACK, got ACK");
            err_count = err_count + 1;
        end
        
        $display("--- Test 3: Random Addresses (Only 0x48 ACKs) ---");
        for (i = 0; i < 50; i = i + 1) begin
            r_addr = $random;
            do_write(r_addr, $random);
            if (r_addr == 7'h48) begin
                if (o_ack_error !== 0) begin
                    $display("FAIL: Expected ACK for 0x48 at iter %0d", i);
                    err_count = err_count + 1;
                end
            end else begin
                if (o_ack_error !== 1) begin
                    $display("FAIL: Expected NACK for %h at iter %0d", r_addr, i);
                    err_count = err_count + 1;
                end
            end
        end
        
        if (err_count == 0)
            $display("\nSUCCESS: All Address Phase tests passed!");
        else
            $display("\nFAILURE: %0d errors found.", err_count);
            
        $finish;
    end

endmodule
