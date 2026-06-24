`timescale 1ns / 1ps

module uart_loopback_tb;

    parameter CLK_FREQ  = 50000000;
    parameter BAUD_RATE = 115200;
    localparam BIT_PERIOD = 1000000000 / BAUD_RATE; // in ns

    reg        clk;
    reg        rst;
    
    reg        i_tx_dv;
    reg  [7:0] i_tx_byte;
    wire       o_tx_done;
    
    wire [7:0] o_rx_byte;
    wire       o_rx_dv;
    
    wire       serial_wire; // Loopback wire
    
    uart_top #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst(rst),
        .i_tx_dv(i_tx_dv),
        .i_tx_byte(i_tx_byte),
        .o_tx_done(o_tx_done),
        .o_rx_byte(o_rx_byte),
        .o_rx_dv(o_rx_dv),
        .o_tx_serial(serial_wire),
        .i_rx_serial(serial_wire) // Wired together!
    );
    
    always #10 clk = ~clk;
    
    integer i;
    reg [7:0] test_bytes [0:3];
    reg [7:0] random_byte;
    integer errors = 0;
    
    task send_and_verify;
        input [7:0] send_byte;
        begin
            @(posedge clk);
            i_tx_byte <= send_byte;
            i_tx_dv   <= 1'b1;
            @(posedge clk);
            i_tx_dv   <= 1'b0;
            
            // Wait for rx to finish
            @(posedge o_rx_dv);
            @(posedge clk);
            
            if (o_rx_byte === send_byte) begin
                $display("PASS: Transmitted %h, Received %h", send_byte, o_rx_byte);
            end else begin
                $display("FAIL: Transmitted %h, Received %h", send_byte, o_rx_byte);
                errors = errors + 1;
            end
            
            // TX finishes full stop bit after RX finishes sampling mid-stop bit
            // Give enough delay for TX to reach IDLE state before next byte
            #(2 * BIT_PERIOD);
        end
    endtask

    initial begin
        $dumpfile("sim/waves/uart_loopback.vcd");
        $dumpvars(0, uart_loopback_tb);
        
        clk = 0;
        rst = 1;
        i_tx_dv = 0;
        i_tx_byte = 8'h00;
        
        #100;
        rst = 0;
        #100;
        
        $display("--- Starting Specific Byte Tests ---");
        test_bytes[0] = 8'h00;
        test_bytes[1] = 8'h55;
        test_bytes[2] = 8'hAA;
        test_bytes[3] = 8'hFF;
        
        for (i = 0; i < 4; i = i + 1) begin
            send_and_verify(test_bytes[i]);
        end
        
        $display("\n--- Starting Random Regression Test (100 Bytes) ---");
        for (i = 0; i < 100; i = i + 1) begin
            random_byte = $random;
            send_and_verify(random_byte);
        end
        
        $display("\n--- Loopback Test Completed ---");
        if (errors == 0) begin
            $display("SUCCESS: All tests passed!");
        end else begin
            $display("FAILURE: %0d errors detected.", errors);
        end
        $finish;
    end

endmodule
