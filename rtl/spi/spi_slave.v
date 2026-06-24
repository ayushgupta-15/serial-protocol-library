`timescale 1ns / 1ps

module spi_slave #(
    parameter DATA_WIDTH = 8
)(
    input  wire                  clk,
    input  wire                  rst,
    
    // SPI interface
    input  wire                  i_sclk,
    input  wire                  i_mosi,
    output reg                   o_miso,
    input  wire                  i_ss,
    
    // Data interface
    input  wire [DATA_WIDTH-1:0] i_tx_byte,
    output reg  [DATA_WIDTH-1:0] o_rx_byte,
    output reg                   o_rx_dv
);

    // Synchronizers for Clock Domain Crossing and Edge Detection
    reg [2:0] sclk_sync;
    reg [2:0] ss_sync;
    reg [1:0] mosi_sync;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sclk_sync <= 3'b000;
            ss_sync   <= 3'b111;
            mosi_sync <= 2'b00;
        end else begin
            sclk_sync <= {sclk_sync[1:0], i_sclk};
            ss_sync   <= {ss_sync[1:0], i_ss};
            mosi_sync <= {mosi_sync[0], i_mosi};
        end
    end
    
    wire sclk_rising  = (sclk_sync[2:1] == 2'b01);
    wire sclk_falling = (sclk_sync[2:1] == 2'b10);
    wire ss_active    = ~ss_sync[1];
    wire ss_falling   = (ss_sync[2:1] == 2'b10);
    
    reg [$clog2(DATA_WIDTH):0] bit_count;
    reg [DATA_WIDTH-1:0]       tx_reg;
    reg [DATA_WIDTH-1:0]       rx_reg;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            o_miso    <= 1'b0;
            o_rx_byte <= 0;
            o_rx_dv   <= 1'b0;
            bit_count <= 0;
            tx_reg    <= 0;
            rx_reg    <= 0;
        end else begin
            o_rx_dv <= 1'b0;
            
            if (ss_active) begin
                if (ss_falling) begin
                    // Load TX data and drive first bit (MSB) to MISO
                    tx_reg <= i_tx_byte;
                    o_miso <= i_tx_byte[DATA_WIDTH-1];
                    bit_count <= DATA_WIDTH;
                end else if (sclk_rising) begin
                    // Mode 0: Sample MOSI on leading edge
                    rx_reg <= {rx_reg[DATA_WIDTH-2:0], mosi_sync[1]};
                end else if (sclk_falling) begin
                    // Mode 0: Shift next bit to MISO on trailing edge
                    tx_reg <= {tx_reg[DATA_WIDTH-2:0], 1'b0};
                    o_miso <= tx_reg[DATA_WIDTH-2];
                    bit_count <= bit_count - 1'b1;
                    
                    if (bit_count == 1) begin
                        o_rx_byte <= rx_reg;
                        o_rx_dv   <= 1'b1;
                    end
                end
            end else begin
                o_miso <= 1'b0; // Or high-Z
            end
        end
    end

endmodule
