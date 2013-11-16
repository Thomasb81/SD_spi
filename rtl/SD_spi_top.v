module SD_spi_top(osc_in,usb_rx,usb_tx,audio_r,audio_l,led1,led2,led3,led4,bp1,bp2,bp3,bp4,sck,di,do,cs);

input osc_in;
input bp1;
input bp2;
input bp3;
input bp4;
output usb_rx; // connected to fpga_uart_tx
input usb_tx; // connected to fpga_uart_rx
output audio_r;
output audio_l;
output led1;
output led2;
output led3;
output led4;

output sck;
output di;
input do;
output cs;



wire clk96m;
wire clk32;
wire [7:0] data_rx;
wire [7:0] data_tx;
wire valid_data_rx;
wire valid_data_tx;

reg [1:0] rx_state;

reg [6:0] cmd_rx;


/*SD */
reg [6:0] sd_cmd;
reg [31:0] sd_data;
reg sd_en;
reg sd_en_q;
reg sd_en_clk;
reg [7:0] sd_div_clk;
reg [6:0] sd_status;
reg cs_delay;
wire rdy_w;
wire [6:0] sd_status_w;
wire sd_valid_status_w;

/* reset stuff*/
wire rst;
wire rst_cmd;
reg [3:0] rst_cpt;



`define RX_IDLE 2'b00
`define RX_WR 2'b01
`define RX_RD 2'b10

DCM0 clk_builder0 (
    .CLKIN_IN(osc_in), 
    .CLKFX_OUT(clk96m), 
    .CLK0_OUT(clk32)
    );
	 
uart_ss uart_ss0 (
    .rst(rst),
    .clk96(clk96m), 
    .usb_rx(usb_tx),
    .usb_tx(usb_rx),	 
    .data_out(data_rx),
    .valid_data_out(valid_data_rx),
    .valid_data_in(valid_data_tx),
    .data_in(data_tx)
);


always @(posedge clk96m) begin
  if (rst == 1'b1) begin
    rx_state <= `RX_IDLE;
    cmd_rx <= 7'h00;

    sd_cmd <= 7'h00;
    sd_data <= 32'h00000000;
    sd_en <= 1'b0;
    sd_en_clk <= 1'b0;
    sd_div_clk <= 8'hff;
    cs_delay <= 1'b1;

  end
  else begin
    case(rx_state)
    `RX_IDLE:
    begin
      if (valid_data_rx == 1'b1) begin 
        cmd_rx <= data_rx[6:0];
        if (data_rx[7] == 1'b1)
          rx_state <= `RX_WR;
        else
          rx_state <= `RX_RD;
      end
    end
    `RX_RD:
    begin
      rx_state <= `RX_IDLE;
    end
    `RX_WR:
    begin
      if (valid_data_rx == 1'b1) begin
        rx_state <= `RX_IDLE;
        case(cmd_rx)
        7'd0: cs_delay <= data_rx[0];
        7'd1: sd_en_clk <= data_rx[0];
        7'd2: sd_div_clk <= data_rx;
        7'd3: sd_cmd <= data_rx[6:0];
        7'd4: sd_en <= data_rx[0];
        7'd7: sd_data[7:0] <= data_rx;
        7'd8: sd_data[15:8] <= data_rx;
        7'd9: sd_data[23:16] <= data_rx;
        7'd10: sd_data[31:24] <= data_rx;
        endcase
      end
    end
    endcase
  end
end

assign data_tx = (cmd_rx ==7'd5 )? {7'h00,rdy_w} :
                 (cmd_rx ==7'd6 )? {1'b0,sd_status} :
                 8'h55;
assign valid_data_tx = (rx_state == `RX_RD) ? 1'b1 : 1'b0;

assign {led4,led3,led2,led1} = 4'b0000;

assign audio_l = 1'b1;
assign audio_r = 1'b1;


always @(posedge clk96m) begin
  if (rst == 1'b1)
    sd_status <= 7'hff;
  else if (sd_en ==1'b0)
    sd_status <= 7'hff;
  else if (sd_valid_status_w == 1'b1)
    sd_status <= sd_status_w;
end

SDctrl SDctrl0(
.clk(clk96m),
.rst(rst),

.sclk(sck),
.mosi(di),
.miso(do),
.cs(cs),

.cmd(sd_cmd),
.address(sd_data),
.en(sd_en),
.en_clk(sd_en_clk),
.div_clk(sd_div_clk),
.i_cs(cs_delay),

.valid_status(sd_valid_status_w),
.resp_status(sd_status_w),
.rdy(rdy_w),

.data_out(),
.data_out_valid()

);








// Reset part ! close your eyes or you will be chocked :)
assign rst_cmd = 1'b0;
always @(posedge clk96m) begin
  if (rst_cmd == 1'b1)
    rst_cpt <= 4'b0000;
  if (rst_cpt != 4'b1111)
    rst_cpt <= rst_cpt+1;
end
	 
assign rst = (rst_cpt == 4'b1111) ? 1'b0 : 1'b1;

initial begin
  rst_cpt <= 4'b0000;
end
	 
endmodule
