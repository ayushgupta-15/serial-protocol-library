`timescale 1ns / 1ps

module baud_gen #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD_RATE = 115200
)(
    input  wire clk,
    input  wire rst,
    output reg  baud_tick
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    reg [15:0] count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 16'b0;
            baud_tick <= 1'b0;
        end else begin
            if (count == CLKS_PER_BIT - 1) begin
                count <= 16'b0;
                baud_tick <= 1'b1;
            end else begin
                count <= count + 1'b1;
                baud_tick <= 1'b0;
            end
        end
    end

endmodule
