`timescale 1ns / 1ps

module spi_modes_tb;

    parameter CLK_FREQ   = 50000000;
    parameter SPI_FREQ   = 1000000;
    parameter DATA_WIDTH = 8;
    localparam CLK_PERIOD = 20;

    reg clk;
    reg rst;
    
    // Control arrays and wires
    reg  [3:0] m_tx_dv;
    reg  [DATA_WIDTH-1:0] m_tx_byte [0:3];
    wire [DATA_WIDTH-1:0] m_rx_byte [0:3];
    wire [3:0] m_rx_dv;
    wire [3:0] m_ready;
    
    reg  [DATA_WIDTH-1:0] s_tx_byte [0:3];
    wire [DATA_WIDTH-1:0] s_rx_byte [0:3];
    wire [3:0] s_rx_dv;
    
    wire [3:0] w_sclk;
    wire [3:0] w_mosi;
    wire [3:0] w_miso;
    wire [3:0] w_ss;
    
    // Instantiate all 4 modes
    // Mode 0
    spi_master #(.CPOL(0), .CPHA(0)) m0 (.clk(clk), .rst(rst), .i_tx_dv(m_tx_dv[0]), .i_tx_byte(m_tx_byte[0]), .o_rx_byte(m_rx_byte[0]), .o_rx_dv(m_rx_dv[0]), .o_ready(m_ready[0]), .o_sclk(w_sclk[0]), .o_mosi(w_mosi[0]), .i_miso(w_miso[0]), .o_ss(w_ss[0]));
    spi_slave  #(.CPOL(0), .CPHA(0)) s0 (.clk(clk), .rst(rst), .i_sclk(w_sclk[0]), .i_mosi(w_mosi[0]), .o_miso(w_miso[0]), .i_ss(w_ss[0]), .i_tx_byte(s_tx_byte[0]), .o_rx_byte(s_rx_byte[0]), .o_rx_dv(s_rx_dv[0]));

    // Mode 1
    spi_master #(.CPOL(0), .CPHA(1)) m1 (.clk(clk), .rst(rst), .i_tx_dv(m_tx_dv[1]), .i_tx_byte(m_tx_byte[1]), .o_rx_byte(m_rx_byte[1]), .o_rx_dv(m_rx_dv[1]), .o_ready(m_ready[1]), .o_sclk(w_sclk[1]), .o_mosi(w_mosi[1]), .i_miso(w_miso[1]), .o_ss(w_ss[1]));
    spi_slave  #(.CPOL(0), .CPHA(1)) s1 (.clk(clk), .rst(rst), .i_sclk(w_sclk[1]), .i_mosi(w_mosi[1]), .o_miso(w_miso[1]), .i_ss(w_ss[1]), .i_tx_byte(s_tx_byte[1]), .o_rx_byte(s_rx_byte[1]), .o_rx_dv(s_rx_dv[1]));

    // Mode 2
    spi_master #(.CPOL(1), .CPHA(0)) m2 (.clk(clk), .rst(rst), .i_tx_dv(m_tx_dv[2]), .i_tx_byte(m_tx_byte[2]), .o_rx_byte(m_rx_byte[2]), .o_rx_dv(m_rx_dv[2]), .o_ready(m_ready[2]), .o_sclk(w_sclk[2]), .o_mosi(w_mosi[2]), .i_miso(w_miso[2]), .o_ss(w_ss[2]));
    spi_slave  #(.CPOL(1), .CPHA(0)) s2 (.clk(clk), .rst(rst), .i_sclk(w_sclk[2]), .i_mosi(w_mosi[2]), .o_miso(w_miso[2]), .i_ss(w_ss[2]), .i_tx_byte(s_tx_byte[2]), .o_rx_byte(s_rx_byte[2]), .o_rx_dv(s_rx_dv[2]));

    // Mode 3
    spi_master #(.CPOL(1), .CPHA(1)) m3 (.clk(clk), .rst(rst), .i_tx_dv(m_tx_dv[3]), .i_tx_byte(m_tx_byte[3]), .o_rx_byte(m_rx_byte[3]), .o_rx_dv(m_rx_dv[3]), .o_ready(m_ready[3]), .o_sclk(w_sclk[3]), .o_mosi(w_mosi[3]), .i_miso(w_miso[3]), .o_ss(w_ss[3]));
    spi_slave  #(.CPOL(1), .CPHA(1)) s3 (.clk(clk), .rst(rst), .i_sclk(w_sclk[3]), .i_mosi(w_mosi[3]), .o_miso(w_miso[3]), .i_ss(w_ss[3]), .i_tx_byte(s_tx_byte[3]), .o_rx_byte(s_rx_byte[3]), .o_rx_dv(s_rx_dv[3]));

    always #(CLK_PERIOD/2) clk = ~clk;
    
    integer err_count = 0;
    
    task test_mode;
        input integer mode;
        input [7:0] test_m_tx;
        input [7:0] test_s_tx;
        begin
            @(posedge clk);
            s_tx_byte[mode] <= test_s_tx;
            m_tx_byte[mode] <= test_m_tx;
            m_tx_dv[mode]   <= 1'b1;
            
            @(posedge clk);
            m_tx_dv[mode]   <= 1'b0;
            
            // Wait for master to finish receiving
            while (m_rx_dv[mode] !== 1'b1) @(posedge clk);
            
            if (m_rx_byte[mode] === test_s_tx && s_rx_byte[mode] === test_m_tx) begin
                // PASS
            end else begin
                $display("FAIL Mode %0d: Expected (M_RX=%h, S_RX=%h) | Got (M_RX=%h, S_RX=%h)",
                         mode, test_s_tx, test_m_tx, m_rx_byte[mode], s_rx_byte[mode]);
                err_count = err_count + 1;
            end
            
            // Wait for SS to deassert and be ready
            while (m_ready[mode] !== 1'b1) @(posedge clk);
            #1000;
        end
    endtask

    integer i, m;
    reg [7:0] t_m, t_s;

    initial begin
        $dumpfile("sim/waves/spi_modes.vcd");
        $dumpvars(0, spi_modes_tb);
        
        clk = 0;
        rst = 1;
        m_tx_dv = 0;
        for (i=0; i<4; i=i+1) begin
            m_tx_byte[i] = 0;
            s_tx_byte[i] = 0;
        end
        
        #100;
        rst = 0;
        #100;
        
        for (m = 0; m < 4; m = m + 1) begin
            $display("--- Testing Mode %0d ---", m);
            test_mode(m, 8'h55, 8'hAA);
            test_mode(m, 8'hAA, 8'h55);
            test_mode(m, 8'h00, 8'hFF);
            test_mode(m, 8'hFF, 8'h00);
            
            // 25 random transactions per mode
            for (i = 0; i < 25; i = i + 1) begin
                t_m = $random;
                t_s = $random;
                test_mode(m, t_m, t_s);
            end
            $display("Mode %0d testing complete.", m);
        end
        
        if (err_count == 0)
            $display("\nSUCCESS: All modes integration tests passed!");
        else
            $display("\nFAILURE: %0d errors found.", err_count);
            
        $finish;
    end

endmodule
