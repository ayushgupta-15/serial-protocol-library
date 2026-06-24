`timescale 1ns / 1ps

module i2c_multi_byte_tb;

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
    reg  [7:0] i_data_0;
    reg  [7:0] i_data_1;
    reg  [7:0] i_data_2;
    reg  [7:0] i_data_3;
    reg  [2:0] i_num_bytes;
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
        .i_data_0(i_data_0),
        .i_data_1(i_data_1),
        .i_data_2(i_data_2),
        .i_data_3(i_data_3),
        .i_num_bytes(i_num_bytes),
        .o_busy(o_busy),
        .o_done(o_done),
        .o_ack_error(o_ack_error),
        .io_scl(io_scl),
        .io_sda(io_sda),
        .o_start_detect(),
        .o_stop_detect()
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    reg ack_enable = 0;
    assign io_sda = ack_enable ? 1'b0 : 1'bz;
    
    integer scl_fall_count = 0;
    reg [7:0] rx_byte = 0;
    
    localparam VALID_SLAVE_ADDR = 7'h48;
    reg is_addr_match = 0;
    
    // NACK injection logic
    reg inject_nack = 0;
    integer nack_at_byte = 0; // 0=Addr, 1=Data0, 2=Data1, etc.
    integer current_byte_idx = 0;
    
    always @(posedge clk) begin
        if (!o_busy) begin
            scl_fall_count = 0;
            ack_enable = 0;
            rx_byte = 0;
            is_addr_match = 0;
            current_byte_idx = 0;
        end
    end
    
    always @(posedge io_scl) begin
        if (o_busy) begin
            rx_byte = {rx_byte[6:0], io_sda};
        end
    end
    
    always @(negedge io_scl) begin
        if (o_busy) begin
            scl_fall_count = scl_fall_count + 1;
            
            // Check if we are at an ACK phase
            // Address phase ends at count 9. Data phases at 18, 27, 36, 45...
            if (scl_fall_count % 9 == 0) begin
                if (scl_fall_count == 9) begin
                    // Address phase
                    if (rx_byte[7:1] == VALID_SLAVE_ADDR) begin
                        is_addr_match = 1;
                        if (inject_nack && nack_at_byte == 0) ack_enable = 0;
                        else ack_enable = 1;
                    end else begin
                        is_addr_match = 0;
                        ack_enable = 0;
                    end
                end else begin
                    // Data phase
                    current_byte_idx = (scl_fall_count / 9) - 1;
                    if (is_addr_match) begin
                        if (inject_nack && nack_at_byte == current_byte_idx) ack_enable = 0;
                        else ack_enable = 1;
                    end
                end
            end else if ((scl_fall_count - 1) % 9 == 0 && scl_fall_count > 1) begin
                // End of ACK phase (counts 10, 19, 28, 37...)
                ack_enable = 0;
            end
        end
    end
    
    task do_write_multi;
        input [6:0] addr;
        input [2:0] nbytes;
        input [7:0] d0;
        input [7:0] d1;
        input [7:0] d2;
        input [7:0] d3;
        input       nack_inj;
        input [2:0] nack_idx;
        begin
            inject_nack = nack_inj;
            nack_at_byte = nack_idx;
            
            @(posedge clk);
            i_slave_addr = addr;
            i_rw = 0; // Write
            i_num_bytes = nbytes;
            i_data_0 = d0;
            i_data_1 = d1;
            i_data_2 = d2;
            i_data_3 = d3;
            i_cmd_write = 1;
            @(posedge clk);
            i_cmd_write = 0;
            
            wait(o_done == 1);
            @(posedge clk);
            inject_nack = 0; // Reset
        end
    endtask

    integer err_count = 0;
    integer i;
    reg [2:0] rand_len;

    initial begin
        $dumpfile("sim/waves/i2c_multi_byte.vcd");
        $dumpvars(0, i2c_multi_byte_tb);
        
        clk = 0;
        rst = 1;
        i_gen_start = 0;
        i_gen_stop = 0;
        i_send_byte = 0;
        i_cmd_write = 0;
        i_slave_addr = 0;
        i_rw = 0;
        i_data_0 = 0;
        i_data_1 = 0;
        i_data_2 = 0;
        i_data_3 = 0;
        i_num_bytes = 1;
        
        #100;
        rst = 0;
        #100;
        
        $display("--- Test 1: Address 0x48, 3 Bytes (0x11, 0x22, 0x33) ---");
        do_write_multi(7'h48, 3, 8'h11, 8'h22, 8'h33, 8'h00, 0, 0);
        if (o_ack_error === 0)
            $display("PASS: All bytes ACKed");
        else begin
            $display("FAIL: Expected ACK, got NACK");
            err_count = err_count + 1;
        end
        
        $display("--- Test 2: Address 0x48, 4 Bytes, NACK on 3rd byte (idx 3) ---");
        // NACK at byte index 3 (which is Data 2). Addr is 0, D0 is 1, D1 is 2, D2 is 3.
        do_write_multi(7'h48, 4, 8'hAA, 8'hBB, 8'hCC, 8'hDD, 1, 3);
        if (o_ack_error === 1)
            $display("PASS: Transaction aborted correctly due to NACK");
        else begin
            $display("FAIL: Expected NACK, got ACK");
            err_count = err_count + 1;
        end
        
        $display("--- Test 3: 100 Randomized Multi-Byte Transfers ---");
        for (i = 0; i < 100; i = i + 1) begin
            rand_len = ($random % 4) + 1; // 1 to 4
            do_write_multi(7'h48, rand_len, $random, $random, $random, $random, 0, 0);
            if (o_ack_error !== 0) begin
                $display("FAIL: Expected ACK at iter %0d", i);
                err_count = err_count + 1;
            end
        end
        
        if (err_count == 0)
            $display("\nSUCCESS: All Multi-Byte tests passed!");
        else
            $display("\nFAILURE: %0d errors found.", err_count);
            
        $finish;
    end

endmodule
