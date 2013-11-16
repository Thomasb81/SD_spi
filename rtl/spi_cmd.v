module spi_cmd(
input clk,
input rst,

input [6:0] cmd,
input [31:0] idata,
input en,

input sclk,
output mosi,
input miso, 


output [31:0] resp_long_status,
output [6:0] resp_status,
output valid_status,

output reg rdy

);

reg [3:0] cpt;

wire [45:0] cmd_message;
wire [7:0] data;
wire [2:0] spi_state;
wire known_cmd;
wire spi_en;
wire valid_status_internal;
reg valid_status_internal_q;

reg sclk_q;
reg en_q;
reg [39:0] rsp_message;

wire sclk_en;


assign cmd_message = (cmd == 6'd0) ?  46'h000000000095 :
                     (cmd == 6'd1) ?  46'h010000000095 : //wrong CRC
                     (cmd == 6'd8) ?  46'h08000001aa87 : // useless ?
                     (cmd == 6'd41) ? 46'h2900000000e5 :   
                     (cmd == 6'd12) ? 46'h0c0000000000 : // wrong CRC
                     (cmd == 6'd16) ? {6'h10,idata,8'h00} : //wrong CRC
                     (cmd == 6'd17) ? {6'h11,idata,8'h00} : //wrong CRC
                     (cmd == 6'd18) ? {6'h12,idata,8'h00} : //wrong CRC
                     (cmd == 6'd55) ? 46'h3700000065 :
                                      46'hffffffffffff;

assign data = (cpt == 4'd0)  ? {2'b01,cmd_message[45:40]} : 
               (cpt == 4'd1)  ? cmd_message[39:32] :
               (cpt == 4'd2)  ? cmd_message[31:24] :
               (cpt == 4'd3)  ? cmd_message[23:16] :
               (cpt == 4'd4)  ? cmd_message[15:8] :
               (cpt == 4'd5)  ? cmd_message[7:0] : 
               8'hff;

//Send command processus
always @(posedge clk) begin
  if (rst == 1'b1) begin
    cpt <= 0;
  end
  else begin
    if (en == 1'b1 ) begin
      if ( sclk_en == 1'b1) begin
        if (spi_state == 3'b000 && cpt < 4'd6)begin
          cpt <= cpt +1;
        end
      end
    end
    else begin
      cpt <= 0;
    end
  end
end

//readback processus
always @(posedge clk) begin 
  if (rst == 1'b1) begin
    rsp_message <= 40'hFFFFFFFFF;
  end
  else begin
    if (sclk_q == 1'b0 && sclk == 1'b1) begin
      rsp_message <= {rsp_message[38:0],miso};
    end
  end
end


assign known_cmd = (cmd == 6'd0 || cmd == 6'd1 || 
                    cmd == 6'd8 || cmd == 6'd41 || 
                    cmd == 6'd12 || cmd == 6'd16 || 
                    cmd == 6'd17 || cmd == 6'd18 || 
                    cmd == 6'd55);
assign valid_status_internal = (cpt == 6 && rsp_message[39] ==1'b0 && known_cmd && rdy== 1'b0) ? 1'b1 : 1'b0;

assign resp_status = rsp_message[38:32];
assign resp_long_status = rsp_message[31:0];
assign valid_status = valid_status_internal_q == 1'b0 && valid_status_internal == 1'b1;

//ready handling and valid status
always @(posedge clk) begin
  if (rst == 1'b1) begin
    rdy <= 1'b1;
    en_q <= 1'b0;
    valid_status_internal_q <= 1'b0;
  end
  else begin
    en_q <= en;
    valid_status_internal_q <= valid_status_internal;
    if (en_q ==1'b0 && en == 1'b1) begin
      rdy <= 1'b0; 
    end
    else if (known_cmd == 1'b1 && cpt == 6 && valid_status == 1'b1 && cmd != 6'd12) begin
      rdy <= 1'b1;
    end
    else if (cmd == 6'd12 && cpt == 6 && rsp_message == 40'hfffffffff) begin
      rdy <= 1'b1;
    end
  end


end



// Handle edge detection on sclk
always @(posedge clk) begin
  if (rst == 1'b1) begin
    sclk_q <= 1'b1;
  end
  else begin
    sclk_q <= sclk;
  end 
end

assign sclk_en = sclk_q == 1'b1 && sclk ==1'b0; 
assign spi_en = en && (cpt < 6);

spi spi0 (
.clk(clk),
.rst(rst),
.sclk(sclk),
.sclk_q(sclk_q),
.en(spi_en),
.byte_idata(data),

.mosi(mosi),

.state(spi_state)

);

endmodule

