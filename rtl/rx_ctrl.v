`timescale 1ns / 1ps
module rx_ctrl(
    input clk,
    input rst,
    input valid_byte,
    input [7:0] data,
);

`define RX_IDLE 3'b000
`define RX_WR 3'b010
`define RX_RD 3'b011


reg [2:0] state;


endmodule
