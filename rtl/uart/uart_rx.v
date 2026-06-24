`timescale 1ns / 1ps

module uart_rx #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       i_rx_serial,
    
    output reg  [7:0] o_rx_byte,
    output reg        o_rx_dv
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    // FSM States
    localparam IDLE       = 3'b000;
    localparam START_BIT  = 3'b001;
    localparam DATA_BITS  = 3'b010;
    localparam STOP_BIT   = 3'b011;
    localparam DONE       = 3'b100;
    
    reg [2:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    
    // 2FF Synchronizer
    reg rx_sync_1;
    reg rx_sync_2;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_sync_1 <= 1'b1;
            rx_sync_2 <= 1'b1;
        end else begin
            rx_sync_1 <= i_rx_serial;
            rx_sync_2 <= rx_sync_1;
        end
    end
    
    // FSM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            clk_count <= 16'b0;
            bit_index <= 3'b0;
            o_rx_byte <= 8'b0;
            o_rx_dv   <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    o_rx_dv   <= 1'b0;
                    clk_count <= 16'b0;
                    bit_index <= 3'b0;
                    
                    if (rx_sync_2 == 1'b0) begin  // Start bit detected
                        state <= START_BIT;
                    end
                end
                
                START_BIT: begin
                    // Wait until middle of start bit
                    if (clk_count == (CLKS_PER_BIT - 1) / 2) begin
                        if (rx_sync_2 == 1'b0) begin
                            clk_count <= 16'b0;
                            state     <= DATA_BITS;
                        end else begin
                            // False start bit (glitch)
                            state <= IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end
                
                DATA_BITS: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 16'b0;
                        o_rx_byte[bit_index] <= rx_sync_2; // Sample data bit
                        
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= 3'b0;
                            state     <= STOP_BIT;
                        end
                    end
                end
                
                STOP_BIT: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 16'b0;
                        // For stop bit, we could verify rx_sync_2 == 1'b1
                        // to check for framing errors, but for now just finish
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    o_rx_dv <= 1'b1;
                    state   <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
