`timescale 1ns / 1ps

module uart_top #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst,
    
    // TX Interface
    input  wire       i_tx_dv,
    input  wire [7:0] i_tx_byte,
    output wire       o_tx_done,
    
    // RX Interface
    output wire [7:0] o_rx_byte,
    output wire       o_rx_dv,
    
    // Serial Loopback connection
    output wire       o_tx_serial,
    input  wire       i_rx_serial
);

    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) tx_inst (
        .clk(clk),
        .rst(rst),
        .i_tx_dv(i_tx_dv),
        .i_tx_byte(i_tx_byte),
        .o_tx_serial(o_tx_serial),
        .o_tx_done(o_tx_done)
    );
    
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) rx_inst (
        .clk(clk),
        .rst(rst),
        .i_rx_serial(i_rx_serial),
        .o_rx_byte(o_rx_byte),
        .o_rx_dv(o_rx_dv)
    );

endmodule
