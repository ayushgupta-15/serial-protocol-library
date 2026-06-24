`timescale 1ns / 1ps

module spi_master_tb;

    parameter CLK_FREQ   = 50000000;
    parameter SPI_FREQ   = 1000000;
    parameter DATA_WIDTH = 8;
    localparam CLKS_PER_HALF_BIT = CLK_FREQ / (2 * SPI_FREQ);
    
    reg clk;
    reg rst;
    
    reg                   i_tx_dv;
    reg  [DATA_WIDTH-1:0] i_tx_byte;
    wire [DATA_WIDTH-1:0] o_rx_byte;
    wire                  o_rx_dv;
    wire                  o_ready;
    
    wire o_sclk;
    wire o_mosi;
    reg  i_miso;
    wire o_ss;
    
    spi_master #(
        .CLK_FREQ(CLK_FREQ),
        .SPI_FREQ(SPI_FREQ),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .i_tx_dv(i_tx_dv),
        .i_tx_byte(i_tx_byte),
        .o_rx_byte(o_rx_byte),
        .o_rx_dv(o_rx_dv),
        .o_ready(o_ready),
        .o_sclk(o_sclk),
        .o_mosi(o_mosi),
        .i_miso(i_miso),
        .o_ss(o_ss)
    );
    
    always #10 clk = ~clk;
    
    // Mock SPI Slave (Mode 0)
    // Mode 0: Sample on rising SCLK, shift on falling SCLK
    reg [DATA_WIDTH-1:0] slave_shift_reg = 8'hA5;
    integer bit_count = 0;
    
    always @(negedge o_ss) begin
        slave_shift_reg = 8'hA5;
        i_miso = slave_shift_reg[DATA_WIDTH-1];
        bit_count = DATA_WIDTH - 1;
    end
    
    always @(negedge o_sclk) begin
        if (!o_ss) begin
            if (bit_count > 0) begin
                bit_count = bit_count - 1;
                slave_shift_reg = {slave_shift_reg[DATA_WIDTH-2:0], 1'b0};
                i_miso = slave_shift_reg[DATA_WIDTH-1];
            end
        end
    end
    
    initial begin
        $dumpfile("sim/waves/spi_master.vcd");
        $dumpvars(0, spi_master_tb);
        
        clk = 0;
        rst = 1;
        i_tx_dv = 0;
        i_tx_byte = 0;
        i_miso = 0;
        
        #100;
        rst = 0;
        #100;
        
        $display("--- Starting SPI Master Mode 0 Test ---");
        
        @(posedge clk);
        i_tx_byte <= 8'hC3;
        i_tx_dv <= 1'b1;
        @(posedge clk);
        i_tx_dv <= 1'b0;
        
        @(posedge o_rx_dv);
        @(posedge clk);
        
        if (o_rx_byte === 8'hA5) begin
            $display("PASS: Master received %h from Slave", o_rx_byte);
        end else begin
            $display("FAIL: Master received %h (Expected A5)", o_rx_byte);
        end
        
        #1000;
        $display("All SPI tests completed.");
        $finish;
    end

endmodule
