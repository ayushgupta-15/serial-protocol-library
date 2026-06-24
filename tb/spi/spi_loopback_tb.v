`timescale 1ns / 1ps

module spi_loopback_tb;

    parameter CLK_FREQ   = 50000000;
    parameter SPI_FREQ   = 1000000;
    parameter DATA_WIDTH = 8;
    localparam CLK_PERIOD = 20; // 50 MHz

    reg clk;
    reg rst;
    
    // Master control interface
    reg                   m_tx_dv;
    reg  [DATA_WIDTH-1:0] m_tx_byte;
    wire [DATA_WIDTH-1:0] m_rx_byte;
    wire                  m_rx_dv;
    wire                  m_ready;
    
    // Slave control interface
    reg  [DATA_WIDTH-1:0] s_tx_byte;
    wire [DATA_WIDTH-1:0] s_rx_byte;
    wire                  s_rx_dv;
    
    // SPI wires
    wire w_sclk;
    wire w_mosi;
    wire w_miso;
    wire w_ss;
    
    spi_master #(
        .CLK_FREQ(CLK_FREQ),
        .SPI_FREQ(SPI_FREQ),
        .DATA_WIDTH(DATA_WIDTH)
    ) master_inst (
        .clk(clk),
        .rst(rst),
        .i_tx_dv(m_tx_dv),
        .i_tx_byte(m_tx_byte),
        .o_rx_byte(m_rx_byte),
        .o_rx_dv(m_rx_dv),
        .o_ready(m_ready),
        .o_sclk(w_sclk),
        .o_mosi(w_mosi),
        .i_miso(w_miso),
        .o_ss(w_ss)
    );
    
    spi_slave #(
        .DATA_WIDTH(DATA_WIDTH)
    ) slave_inst (
        .clk(clk),
        .rst(rst),
        .i_sclk(w_sclk),
        .i_mosi(w_mosi),
        .o_miso(w_miso),
        .i_ss(w_ss),
        .i_tx_byte(s_tx_byte),
        .o_rx_byte(s_rx_byte),
        .o_rx_dv(s_rx_dv)
    );
    
    always #(CLK_PERIOD/2) clk = ~clk;
    
    integer err_count = 0;
    
    task send_and_verify;
        input [DATA_WIDTH-1:0] test_m_tx;
        input [DATA_WIDTH-1:0] test_s_tx;
        begin
            @(posedge clk);
            s_tx_byte <= test_s_tx;
            m_tx_byte <= test_m_tx;
            m_tx_dv   <= 1'b1;
            
            @(posedge clk);
            m_tx_dv   <= 1'b0;
            
            // Wait for master to finish receiving
            @(posedge m_rx_dv);
            @(posedge clk);
            
            if (m_rx_byte === test_s_tx && s_rx_byte === test_m_tx) begin
                $display("PASS: Master sent %h (received %h), Slave sent %h (received %h)", 
                         test_m_tx, s_rx_byte, test_s_tx, m_rx_byte);
            end else begin
                $display("FAIL: Expected (M_RX=%h, S_RX=%h) | Got (M_RX=%h, S_RX=%h)",
                         test_s_tx, test_m_tx, m_rx_byte, s_rx_byte);
                err_count = err_count + 1;
            end
            
            // Wait for SS to deassert and be ready
            wait(m_ready == 1'b1);
            #1000;
        end
    endtask

    integer i;
    reg [7:0] rand_m;
    reg [7:0] rand_s;

    initial begin
        $dumpfile("sim/waves/spi_loopback.vcd");
        $dumpvars(0, spi_loopback_tb);
        
        clk = 0;
        rst = 1;
        m_tx_dv = 0;
        m_tx_byte = 0;
        s_tx_byte = 0;
        
        #100;
        rst = 0;
        #100;
        
        $display("--- Integration Test 1 ---");
        send_and_verify(8'h55, 8'hAA);
        
        $display("--- Integration Test 2 ---");
        send_and_verify(8'h00, 8'hFF);
        
        $display("--- Random Regression Test (50 Bytes) ---");
        for (i = 0; i < 50; i = i + 1) begin
            rand_m = $random;
            rand_s = $random;
            send_and_verify(rand_m, rand_s);
        end
        
        if (err_count == 0)
            $display("\nSUCCESS: All integration tests passed!");
        else
            $display("\nFAILURE: %0d errors found.", err_count);
            
        $finish;
    end

endmodule
