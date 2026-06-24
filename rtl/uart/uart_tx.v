`timescale 1ns / 1ps

module uart_tx #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       i_tx_dv,    // start transmission
    input  wire [7:0] i_tx_byte,  // byte to send
    
    output reg        o_tx_serial,
    output reg        o_tx_done
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    // FSM States
    localparam IDLE       = 3'b000;
    localparam START_BIT  = 3'b001;
    localparam DATA_BITS  = 3'b010;
    localparam STOP_BIT   = 3'b011;
    localparam DONE       = 3'b100;
    
    reg [2:0]  state;
    reg [7:0]  tx_data;
    reg [2:0]  bit_index;
    reg [15:0] clk_count;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= IDLE;
            o_tx_serial <= 1'b1; // Idle state is HIGH
            o_tx_done   <= 1'b0;
            tx_data     <= 8'b0;
            bit_index   <= 3'b0;
            clk_count   <= 16'b0;
        end else begin
            case (state)
                IDLE: begin
                    o_tx_serial <= 1'b1;
                    o_tx_done   <= 1'b0;
                    clk_count   <= 16'b0;
                    bit_index   <= 3'b0;
                    
                    if (i_tx_dv) begin
                        tx_data   <= i_tx_byte;
                        state     <= START_BIT;
                    end
                end
                
                START_BIT: begin
                    o_tx_serial <= 1'b0; // Start bit is LOW
                    
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 16'b0;
                        state     <= DATA_BITS;
                    end
                end
                
                DATA_BITS: begin
                    o_tx_serial <= tx_data[bit_index];
                    
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 16'b0;
                        
                        // Check if we sent all bits
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= 3'b0;
                            state     <= STOP_BIT;
                        end
                    end
                end
                
                STOP_BIT: begin
                    o_tx_serial <= 1'b1; // Stop bit is HIGH
                    
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 16'b0;
                        state     <= DONE;
                    end
                end
                
                DONE: begin
                    o_tx_done <= 1'b1;
                    state     <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
