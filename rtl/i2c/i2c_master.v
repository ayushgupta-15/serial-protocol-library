`timescale 1ns / 1ps

module i2c_master #(
    parameter CLK_FREQ = 50000000,
    parameter I2C_FREQ = 100000  // 100 kHz Standard Mode
)(
    input  wire clk,
    input  wire rst,
    
    // Commands for P1
    input  wire i_gen_start,
    input  wire i_gen_stop,
    output reg  o_busy,
    
    // I2C Bus (Open-Drain)
    inout  wire io_scl,
    inout  wire io_sda,
    
    // Detection Outputs (for verification)
    output wire o_start_detect,
    output wire o_stop_detect
);

    // I2C Timing: 100kHz = 10us period
    localparam QUARTER_PERIOD = CLK_FREQ / (4 * I2C_FREQ);
    
    reg [1:0] state;
    localparam IDLE = 0, START = 1, STOP = 2;
    
    reg [15:0] clk_count;
    reg [2:0]  step_count;
    
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
            clk_count <= 0;
            step_count <= 0;
        end else begin
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
                    end
                end
                
                START: begin
                    if (clk_count == QUARTER_PERIOD - 1) begin
                        clk_count <= 0;
                        step_count <= step_count + 1'b1;
                        
                        case (step_count)
                            0: begin
                                // SDA goes LOW
                                sda_oe <= 1'b1;
                            end
                            1: begin
                                // SCL goes LOW
                                scl_oe <= 1'b1;
                            end
                            2: begin
                                state <= IDLE;
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
                            0: begin
                                // SCL goes HIGH
                                scl_oe <= 1'b0;
                            end
                            1: begin
                                // SDA goes HIGH
                                sda_oe <= 1'b0;
                            end
                            2: begin
                                state <= IDLE;
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
