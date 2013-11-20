`timescale 1ns / 1ps
module SDBoot(
    input clk,
    input rst,

    output [6:0] cmd,
    output reg SDctrl_start,
    output en_clk,
    output [7:0] div_clk,
    output reg cs,
    input sclk,
    input SDctrl_valid_status,
    input [6:0] SDctrl_status,
    input SDctrl_available, 

    output [1:0] status
);

`define RESET 3'b000
`define CMD0 3'b001
`define CMD1 3'b010
`define WAIT_STATUS 3'b011
`define FINISH 3'b100

reg [2:0] state;
reg [3:0] cnt;
reg [6:0] result;
reg sclk_q;
reg available_q;


always @(posedge clk) begin
  if (rst == 1'b1) begin
    state <= `RESET;
    cnt <= 4'b0000;
    cs <= 1'b1;
    result <= 7'b0000000;
    SDctrl_start <= 1'b0;
    sclk_q<= 1'b0;
    available_q <= 1'b0;
  end
  else begin
    sclk_q <= sclk;
    available_q <=SDctrl_available;
    if (SDctrl_valid_status == 1'b1) begin
      result <= SDctrl_status;
    end

    if (available_q == 1'b0 && SDctrl_available == 1'b1 && SDctrl_start == 1'b1 ) begin
      SDctrl_start <= 1'b0;
    end
  
    case(state)
      `RESET: begin
        if (cnt == 4'b1111) begin
          state <= `CMD0;
          SDctrl_start <= 1'b1;
          cs <= 1'b0;
        end
        else begin
          if (sclk_q == 1'b0 && sclk == 1'b1) begin
            cnt <= cnt +1;
          end
        end
      end
      `CMD0: begin
        if (available_q == 1'b1 && SDctrl_available == 1'b1 && result == 7'h01 && 
            SDctrl_start ==1'b0 && sclk_q == 1'b1 && sclk == 1'b0) begin
          SDctrl_start <= 1'b1;
          state <= `CMD1;
        end
        else begin
          state <= `CMD0;
        end
      end
      `CMD1: begin
        if (SDctrl_available == 1'b1 && result == 7'h00 && SDctrl_start == 1'b0) begin
          state <= `FINISH;
        end
        else if (SDctrl_available == 1'b1 && result == 7'h01 && SDctrl_start == 1'b0 && 
                 sclk_q == 1'b1 && sclk == 1'b0 ) begin
          state <= `WAIT_STATUS;
        end
        else begin
          state <= `CMD1;
        end
      end
      `WAIT_STATUS: begin
        if (available_q ==1'b1 && SDctrl_available == 1'b1 && result == 7'h01 && SDctrl_start == 1'b0) begin
          SDctrl_start <= 1'b1;
          state<=`CMD1;
        end
      end
      `FINISH: begin
      end
    endcase
  end
end

assign div_clk = (state == `FINISH) ? 8'h00 : 8'hff;
assign en_clk = 1'b1;
assign cmd = (state == `FINISH) ? 7'h11 :
             (state == `CMD1 || state == `WAIT_STATUS) ? 7'h01 : 7'h00;


endmodule
