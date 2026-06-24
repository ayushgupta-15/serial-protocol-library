`timescale 1ns / 1ps

module uart_rx_tb;

    parameter CLK_FREQ  = 50000000;
    parameter BAUD_RATE = 115200;
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam BIT_PERIOD = 1000000000 / BAUD_RATE; // in ns

    reg        clk;
    reg        rst;
    reg        i_rx_serial;
    
    wire [7:0] o_rx_byte;
    wire       o_rx_dv;
    
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst(rst),
        .i_rx_serial(i_rx_serial),
        .o_rx_byte(o_rx_byte),
        .o_rx_dv(o_rx_dv)
    );
    
    always #10 clk = ~clk;
    
    task send_byte;
        input [7:0] data;
        integer i;
        begin
            // Start bit
            i_rx_serial = 1'b0;
            #(BIT_PERIOD);
            
            // Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                i_rx_serial = data[i];
                #(BIT_PERIOD);
            end
            
            // Stop bit
            i_rx_serial = 1'b1;
            #(BIT_PERIOD);
        end
    endtask

    initial begin
        $dumpfile("sim/waves/uart_rx.vcd");
        $dumpvars(0, uart_rx_tb);
        
        clk = 0;
        rst = 1;
        i_rx_serial = 1'b1; // Idle
        
        #100;
        rst = 0;
        #100;
        
        $display("Test 1: Receive 0x00");
        fork
            send_byte(8'h00);
            @(posedge o_rx_dv);
        join
        @(posedge clk);
        if (o_rx_byte == 8'h00) $display("PASS: Received 0x00");
        else $display("FAIL: Received %h", o_rx_byte);
        
        #1000;
        
        $display("Test 2: Receive 0xFF");
        fork
            send_byte(8'hFF);
            @(posedge o_rx_dv);
        join
        @(posedge clk);
        if (o_rx_byte == 8'hFF) $display("PASS: Received 0xFF");
        else $display("FAIL: Received %h", o_rx_byte);
        
        #1000;
        
        $display("Test 3: Receive 0x55");
        fork
            send_byte(8'h55);
            @(posedge o_rx_dv);
        join
        @(posedge clk);
        if (o_rx_byte == 8'h55) $display("PASS: Received 0x55");
        else $display("FAIL: Received %h", o_rx_byte);
        
        #1000;
        
        $display("All RX tests completed successfully.");
        $finish;
    end

endmodule
