`timescale 1ns / 1ps

module spi_slave_tb;

    parameter DATA_WIDTH = 8;
    localparam CLK_PERIOD = 20; // 50 MHz
    localparam SPI_HALF_PERIOD = 500; // 1 MHz half-period (500 ns)

    reg clk;
    reg rst;
    
    reg i_sclk;
    reg i_mosi;
    reg i_ss;
    wire o_miso;
    
    reg [DATA_WIDTH-1:0] i_tx_byte;
    wire [DATA_WIDTH-1:0] o_rx_byte;
    wire o_rx_dv;
    
    spi_slave #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .i_sclk(i_sclk),
        .i_mosi(i_mosi),
        .o_miso(o_miso),
        .i_ss(i_ss),
        .i_tx_byte(i_tx_byte),
        .o_rx_byte(o_rx_byte),
        .o_rx_dv(o_rx_dv)
    );
    
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // Master Receive Register
    reg [DATA_WIDTH-1:0] master_rx_reg;
    
    task master_transmit;
        input [DATA_WIDTH-1:0] mosi_data;
        integer i;
        begin
            i_ss = 1'b0;
            #(SPI_HALF_PERIOD);
            
            for (i = DATA_WIDTH-1; i >= 0; i = i - 1) begin
                // Drive MOSI
                i_mosi = mosi_data[i];
                // Leading edge (Rising)
                i_sclk = 1'b1;
                
                // Sample MISO mid-cycle
                #(SPI_HALF_PERIOD/2);
                master_rx_reg[i] = o_miso;
                #(SPI_HALF_PERIOD/2);
                
                // Trailing edge (Falling)
                i_sclk = 1'b0;
                #(SPI_HALF_PERIOD);
            end
            
            i_ss = 1'b1;
            #(SPI_HALF_PERIOD * 2);
        end
    endtask

    integer err_count = 0;
    integer i;
    reg [7:0] random_mosi;
    reg [7:0] random_miso;

    initial begin
        $dumpfile("sim/waves/spi_slave.vcd");
        $dumpvars(0, spi_slave_tb);
        
        clk = 0;
        rst = 1;
        i_sclk = 0;
        i_mosi = 0;
        i_ss = 1;
        i_tx_byte = 0;
        master_rx_reg = 0;
        
        #100;
        rst = 0;
        #100;
        
        $display("--- Test 1: Master sends 0x55, Slave transmits 0xAA ---");
        i_tx_byte = 8'hAA;
        master_transmit(8'h55);
        
        if (o_rx_byte === 8'h55 && master_rx_reg === 8'hAA)
            $display("PASS");
        else begin
            $display("FAIL: Slave rx=%h, Master rx=%h", o_rx_byte, master_rx_reg);
            err_count = err_count + 1;
        end
        
        $display("--- Test 2: Master sends 0x00, Slave transmits 0xFF ---");
        i_tx_byte = 8'hFF;
        master_transmit(8'h00);
        
        if (o_rx_byte === 8'h00 && master_rx_reg === 8'hFF)
            $display("PASS");
        else begin
            $display("FAIL: Slave rx=%h, Master rx=%h", o_rx_byte, master_rx_reg);
            err_count = err_count + 1;
        end
        
        $display("--- Test 3: 50 Randomized Transactions ---");
        for (i = 0; i < 50; i = i + 1) begin
            random_mosi = $random;
            random_miso = $random;
            i_tx_byte = random_miso;
            
            master_transmit(random_mosi);
            
            if (o_rx_byte !== random_mosi || master_rx_reg !== random_miso) begin
                $display("FAIL at iter %0d: expected mosi=%h, got %h | expected miso=%h, got %h", 
                         i, random_mosi, o_rx_byte, random_miso, master_rx_reg);
                err_count = err_count + 1;
            end
        end
        
        if (err_count == 0)
            $display("SUCCESS: All tests passed!");
        else
            $display("FAILURE: %0d errors", err_count);
            
        $finish;
    end

endmodule
