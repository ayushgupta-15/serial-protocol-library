`timescale 1ns / 1ps

module spi_master #(
    parameter CLK_FREQ = 50000000,
    parameter SPI_FREQ = 1000000, // 1 MHz
    parameter DATA_WIDTH = 8
)(
    input  wire                  clk,
    input  wire                  rst,
    
    // Control interface
    input  wire                  i_tx_dv,
    input  wire [DATA_WIDTH-1:0] i_tx_byte,
    output reg  [DATA_WIDTH-1:0] o_rx_byte,
    output reg                   o_rx_dv,
    output reg                   o_ready,
    
    // SPI interface
    output reg                   o_sclk,
    output reg                   o_mosi,
    input  wire                  i_miso,
    output reg                   o_ss
);

    localparam CLKS_PER_HALF_BIT = CLK_FREQ / (2 * SPI_FREQ);
    
    // FSM States
    localparam IDLE      = 2'b00;
    localparam ASSERT_SS = 2'b01;
    localparam SHIFT     = 2'b10;
    localparam DONE      = 2'b11;
    
    reg [1:0] state;
    reg [15:0] clk_count;
    reg [2:0] bit_index; // Assuming DATA_WIDTH=8
    reg [DATA_WIDTH-1:0] tx_data;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            o_sclk     <= 1'b0; // CPOL=0
            o_mosi     <= 1'b0;
            o_ss       <= 1'b1; // Active low
            o_rx_byte  <= 0;
            o_rx_dv    <= 1'b0;
            o_ready    <= 1'b1;
            clk_count  <= 0;
            bit_index  <= DATA_WIDTH - 1; // MSB first
            tx_data    <= 0;
        end else begin
            case (state)
                IDLE: begin
                    o_sclk    <= 1'b0; // CPOL=0
                    o_ss      <= 1'b1; // Idle high
                    o_rx_dv   <= 1'b0;
                    o_ready   <= 1'b1;
                    clk_count <= 0;
                    
                    if (i_tx_dv) begin
                        o_ready   <= 1'b0;
                        tx_data   <= i_tx_byte;
                        o_mosi    <= i_tx_byte[DATA_WIDTH - 1]; // Setup first bit
                        bit_index <= DATA_WIDTH - 1;
                        state     <= ASSERT_SS;
                    end
                end
                
                ASSERT_SS: begin
                    o_ss <= 1'b0; // Assert CS
                    // Wait half a clock to let slave see SS=0 and setup MISO.
                    if (clk_count == CLKS_PER_HALF_BIT - 1) begin
                        clk_count <= 0;
                        state     <= SHIFT;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end
                
                SHIFT: begin
                    if (clk_count == CLKS_PER_HALF_BIT - 1) begin
                        clk_count <= 0;
                        o_sclk <= ~o_sclk; // Toggle clock
                        
                        if (o_sclk == 1'b0) begin
                            // SCLK: LOW -> HIGH (Rising Edge). CPOL=0 means Leading Edge.
                            // Sample MISO
                            o_rx_byte[bit_index] <= i_miso;
                        end else begin
                            // SCLK: HIGH -> LOW (Falling Edge). CPOL=0 means Trailing Edge.
                            // Shift MOSI
                            if (bit_index == 0) begin
                                // Finished shifting last bit
                                state <= DONE;
                            end else begin
                                bit_index <= bit_index - 1'b1;
                                o_mosi    <= tx_data[bit_index - 1'b1];
                            end
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end
                
                DONE: begin
                    o_sclk <= 1'b0;
                    if (clk_count == CLKS_PER_HALF_BIT - 1) begin
                        clk_count <= 0;
                        o_ss      <= 1'b1;
                        o_rx_dv   <= 1'b1;
                        state     <= IDLE;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
