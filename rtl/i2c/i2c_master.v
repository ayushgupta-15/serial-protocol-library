`timescale 1ns / 1ps

module i2c_master #(
    parameter CLK_FREQ = 50000000,
    parameter I2C_FREQ = 100000  // 100 kHz Standard Mode
)(
    input  wire clk,
    input  wire rst,
    
    // Commands
    input  wire       i_gen_start,
    input  wire       i_gen_stop,
    input  wire       i_send_byte,
    input  wire [7:0] i_tx_data,
    
    output reg        o_busy,
    output reg        o_done,         // Pulse when a command finishes
    output reg        o_ack_error,    // 0 = ACK, 1 = NACK
    
    // I2C Bus (Open-Drain)
    inout  wire       io_scl,
    inout  wire       io_sda,
    
    // Monitors
    output wire       o_start_detect,
    output wire       o_stop_detect
);

    // I2C Timing: 100kHz = 10us period
    localparam QUARTER_PERIOD = CLK_FREQ / (4 * I2C_FREQ);
    
    localparam IDLE      = 3'd0;
    localparam START     = 3'd1;
    localparam SEND_BYTE = 3'd2;
    localparam WAIT_ACK  = 3'd3;
    localparam STOP      = 3'd4;
    
    reg [2:0] state;
    reg [15:0] clk_count;
    reg [1:0]  step_count;
    reg [2:0]  bit_index;
    reg [7:0]  tx_reg;
    
    // Output enables (active high drives 0, inactive high-Z is pulled up by resistor)
    reg scl_oe;
    reg sda_oe;
    
    assign io_scl = scl_oe ? 1'b0 : 1'bz;
    assign io_sda = sda_oe ? 1'b0 : 1'bz;
    
    // Bus monitoring synchronizers
    reg [2:0] scl_sync;
    reg [2:0] sda_sync;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scl_sync <= 3'b111;
            sda_sync <= 3'b111;
        end else begin
            scl_sync <= {scl_sync[1:0], io_scl};
            sda_sync <= {sda_sync[1:0], io_sda};
        end
    end
    
    // Detection logic
    // START: SDA falling while SCL is high
    wire sda_falling = (sda_sync[2:1] == 2'b10);
    wire sda_rising  = (sda_sync[2:1] == 2'b01);
    wire scl_high    = (scl_sync[1] == 1'b1);
    
    assign o_start_detect = sda_falling & scl_high;
    assign o_stop_detect  = sda_rising & scl_high;
    
    // Generation logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            scl_oe <= 1'b0; // High-Z (1)
            sda_oe <= 1'b0; // High-Z (1)
            o_busy <= 1'b0;
            o_done <= 1'b0;
            o_ack_error <= 1'b0;
            clk_count <= 0;
            step_count <= 0;
            bit_index <= 0;
            tx_reg <= 0;
        end else begin
            o_done <= 1'b0; // Default
            
            case (state)
                IDLE: begin
                    o_busy <= 1'b0;
                    clk_count <= 0;
                    step_count <= 0;
                    
                    if (i_gen_start) begin
                        state <= START;
                        o_busy <= 1'b1;
                        scl_oe <= 1'b0; // Ensure SCL is high-Z (high)
                        sda_oe <= 1'b0; // Ensure SDA is high-Z (high)
                    end else if (i_gen_stop) begin
                        state <= STOP;
                        o_busy <= 1'b1;
                        scl_oe <= 1'b1; // Pull SCL low
                        sda_oe <= 1'b1; // Pull SDA low
                    end else if (i_send_byte) begin
                        state <= SEND_BYTE;
                        o_busy <= 1'b1;
                        tx_reg <= i_tx_data;
                        bit_index <= 3'd7; // MSB first
                    end
                end
                
                START: begin
                    if (clk_count == QUARTER_PERIOD - 1) begin
                        clk_count <= 0;
                        step_count <= step_count + 1'b1;
                        
                        case (step_count)
                            0: sda_oe <= 1'b1; // SDA goes LOW
                            1: scl_oe <= 1'b1; // SCL goes LOW
                            2: begin
                                state <= IDLE;
                                o_done <= 1'b1;
                            end
                        endcase
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end
                
                STOP: begin
                    if (clk_count == QUARTER_PERIOD - 1) begin
                        clk_count <= 0;
                        step_count <= step_count + 1'b1;
                        
                        case (step_count)
                            0: scl_oe <= 1'b0; // SCL goes HIGH
                            1: sda_oe <= 1'b0; // SDA goes HIGH
                            2: begin
                                state <= IDLE;
                                o_done <= 1'b1;
                            end
                        endcase
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end
                
                SEND_BYTE: begin
                    if (clk_count == QUARTER_PERIOD - 1) begin
                        clk_count <= 0;
                        step_count <= step_count + 1'b1;
                        
                        case (step_count)
                            0: begin
                                // Q0: SCL is low, update SDA
                                sda_oe <= ~tx_reg[bit_index]; // OE=1 pulls low (0), OE=0 releases (1)
                            end
                            1: begin
                                // Q1: SCL goes high
                                scl_oe <= 1'b0;
                            end
                            2: begin
                                // Q2: SCL is high, data is valid
                            end
                            3: begin
                                // Q3: SCL goes low
                                scl_oe <= 1'b1;
                                
                                if (bit_index == 0) begin
                                    state <= WAIT_ACK;
                                end else begin
                                    bit_index <= bit_index - 1'b1;
                                end
                            end
                        endcase
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end
                
                WAIT_ACK: begin
                    if (clk_count == QUARTER_PERIOD - 1) begin
                        clk_count <= 0;
                        step_count <= step_count + 1'b1;
                        
                        case (step_count)
                            0: begin
                                // Q0: Release SDA so slave can drive ACK
                                sda_oe <= 1'b0;
                            end
                            1: begin
                                // Q1: SCL goes high
                                scl_oe <= 1'b0;
                            end
                            2: begin
                                // Q2: SCL is high. Sample ACK
                                o_ack_error <= sda_sync[1]; // 0 = ACK, 1 = NACK
                            end
                            3: begin
                                // Q3: SCL goes low
                                scl_oe <= 1'b1;
                                state <= IDLE;
                                o_done <= 1'b1;
                            end
                        endcase
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule
