`timescale 1ns / 1ps

module i2c_clock_stretch_tb;

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
    
    reg stretch_enable = 0;
    assign io_scl = stretch_enable ? 1'b0 : 1'bz;
    
    integer scl_fall_count = 0;
    reg [7:0] rx_byte = 0;
    
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
    
    always @(posedge io_scl) begin
        if (o_busy) begin
            rx_byte = {rx_byte[6:0], io_sda};
        end
    end
    
    always @(negedge io_scl) begin
        if (o_busy) begin
            scl_fall_count = scl_fall_count + 1;
            
            if (scl_fall_count % 9 == 0) begin
                if (scl_fall_count == 9) begin
                    if (rx_byte[7:1] == VALID_SLAVE_ADDR) begin
                        is_addr_match = 1;
                        ack_enable = 1;
                    end
                end else begin
                    if (is_addr_match) begin
                        ack_enable = 1;
                    end
                end
            end else if ((scl_fall_count - 1) % 9 == 0 && scl_fall_count > 1) begin
                ack_enable = 0;
            end
        end
    end
    
    integer current_stretch_cycles = 0;
    
    task trigger_stretch;
        input [31:0] cycles;
        begin
            stretch_enable = 1;
            repeat(cycles) @(posedge clk);
            stretch_enable = 0;
        end
    endtask
    
    reg trigger_stretch_flag = 0;
    
    always @(negedge io_scl) begin
        if (o_busy && current_stretch_cycles > 0) begin
            // Trigger stretch after Address ACK (scl_fall_count == 10)
            // Or after Data ACK (scl_fall_count == 19)
            if (scl_fall_count == 10 || scl_fall_count == 19) begin
                trigger_stretch_flag = 1;
                #1 trigger_stretch_flag = 0;
            end
        end
    end
    
    always @(posedge trigger_stretch_flag) begin
        trigger_stretch(current_stretch_cycles);
    end
    
    task do_write_stretch;
        input [6:0] addr;
        input [2:0] nbytes;
        input [7:0] d0;
        input [7:0] d1;
        input [31:0] stretch_cyc;
        begin
            current_stretch_cycles = stretch_cyc;
            
            @(posedge clk);
            i_slave_addr = addr;
            i_rw = 0; // Write
            i_num_bytes = nbytes;
            i_data_0 = d0;
            i_data_1 = d1;
            i_cmd_write = 1;
            @(posedge clk);
            i_cmd_write = 0;
            
            wait(o_done == 1);
            @(posedge clk);
            current_stretch_cycles = 0;
        end
    endtask

    integer err_count = 0;

    initial begin
        $dumpfile("sim/waves/i2c_clock_stretch.vcd");
        $dumpvars(0, i2c_clock_stretch_tb);
        
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
        
        $display("--- Test 1: Address 0x48, 2 Bytes, Stretch 5 Cycles ---");
        do_write_stretch(7'h48, 2, 8'h11, 8'h22, 5);
        if (o_ack_error === 0)
            $display("PASS: Master survived 5-cycle stretch and finished correctly.");
        else begin
            $display("FAIL: Expected ACK, got NACK");
            err_count = err_count + 1;
        end
        
        $display("--- Test 2: Address 0x48, 2 Bytes, Stretch 1000 Cycles ---");
        // 1000 cycles at 50MHz is 20us (2 full I2C periods)
        do_write_stretch(7'h48, 2, 8'hAA, 8'hBB, 1000);
        if (o_ack_error === 0)
            $display("PASS: Master survived long 1000-cycle stretch.");
        else begin
            $display("FAIL: Expected ACK, got NACK");
            err_count = err_count + 1;
        end
        
        $display("--- Test 3: Address 0x48, 2 Bytes, Random Stretch ---");
        do_write_stretch(7'h48, 2, 8'hCC, 8'hDD, ($random % 500) + 10);
        if (o_ack_error === 0)
            $display("PASS: Master survived random cycle stretch.");
        else begin
            $display("FAIL: Expected ACK, got NACK");
            err_count = err_count + 1;
        end
        
        if (err_count == 0)
            $display("\nSUCCESS: All Clock Stretching tests passed!");
        else
            $display("\nFAILURE: %0d errors found.", err_count);
            
        $finish;
    end

endmodule
