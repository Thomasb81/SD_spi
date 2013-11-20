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
wire [6:0] sd_cmd;
reg sd_en_clk;
reg [6:0] sd_status;
wire rdy_w;
wire [6:0] sd_status_w;
wire sd_valid_status_w;
reg driver_start;

wire [31:0] sd_address;
wire [7:0] data_driver;
wire data_driver_valid;
wire SDctrl_start;

wire [2:0] driver_state;
wire [31:0] driver_nb_data;
wire [10:0] driver_data_cpt;


wire fifo_empty;
wire fifo_full;
wire fifo_halffull;
wire fifo_wr_en;
wire [15:0] fifo_data_in;

reg [10:0] tick_48k;
reg fifo_rd_en;
wire [15:0] fifo_out;
wire [15:0] pcm;
wire dac_out;



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

    sd_en_clk <= 1'b0;
    driver_start <= 1'b0;

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
        7'd1: sd_en_clk <= data_rx[0];
        7'd5: driver_start <= data_rx[0];
        endcase
      end
    end
    endcase
  end
end

assign data_tx = (cmd_rx ==7'd5 )? {7'h00,rdy_w} :
                 (cmd_rx ==7'd6 )? {1'b0,sd_status} :
                 (cmd_rx ==7'd7 )? {5'h00,driver_state}:
                 (cmd_rx ==7'd8 )? sd_address[7:0]:
                 (cmd_rx ==7'd9 )? sd_address[15:8]:
                 (cmd_rx ==7'd10 )? sd_address[23:16]:
                 (cmd_rx ==7'd11 )? sd_address[31:24]:
                 (cmd_rx ==7'd12 )? driver_nb_data[7:0]:
                 (cmd_rx ==7'd13 )? driver_nb_data[15:8]:
                 (cmd_rx ==7'd14 )? driver_nb_data[23:16]:
                 (cmd_rx ==7'd15 )? driver_nb_data[31:24]:
                 (cmd_rx ==7'd16 )? driver_data_cpt[7:0]:
                 (cmd_rx ==7'd17 )? {5'b00000,driver_data_cpt[10:8]}:
                 8'h55;
assign valid_data_tx = (rx_state == `RX_RD) ? 1'b1 : 1'b0;

assign {led4,led3,led2,led1} = {rdy_w,fifo_full,fifo_halffull,fifo_empty};

assign audio_l = dac_out;
assign audio_r = dac_out;


always @(posedge clk96m) begin
  if (rst == 1'b1)
    sd_status <= 7'hff;
  else if (sd_valid_status_w == 1'b1)
    sd_status <= sd_status_w;
  else if ( SDctrl_start==1'b0)
    sd_status <= 7'hff;
end

SDctrl SDctrl0(
.clk(clk96m),
.rst(rst),

.sclk(sck),
.mosi(di),
.miso(do),
.cs(cs),

.cmd(sd_cmd),
.address(sd_address),
.en( SDctrl_start ),

.valid_status(sd_valid_status_w),
.resp_status(sd_status_w),
.rdy(rdy_w),

.data_out(data_driver),
.data_out_valid(data_driver_valid)

);

SDdriver SDdriver0(
.clk(clk96m),
.rst(rst),
.start(driver_start),
.sample_code(8'h00),
.fifo_empty(fifo_empty),
.fifo_full(fifo_full),
.fifo_prog(fifo_halffull),
.fifo_wr(fifo_wr_en),
.fifo_data(fifo_data_in),

.SDctrl_data(data_driver),
.SDctrl_valid(data_driver_valid),
.SDctrl_available(rdy_w),

.SDctrl_address(sd_address),
.SDctrl_start(SDctrl_start),
.state(driver_state),
.nb_data(driver_nb_data),
.data_cpt(driver_data_cpt)

);


fifo_256w fifo0(
.clk(clk96m),
.srst(rst),
.din(fifo_data_in),
.wr_en(fifo_wr_en),
.rd_en(fifo_rd_en),
.dout(fifo_out),
.full(fifo_full),
.empty(fifo_empty),
.prog_full(fifo_halffull)
);




always @(posedge clk96m) begin
  if (rst == 1'b1) begin
    tick_48k <= 0;
    fifo_rd_en <=1'b0;
  end
  else if (tick_48k == 2000)begin
    tick_48k <=0;
    fifo_rd_en <=1'b1;
  end
  else begin
    tick_48k <= tick_48k+1;
    fifo_rd_en <= 1'b0;
  end
end

assign pcm = (fifo_empty== 1'b1) ? 16'h8000 : fifo_out;

dac16 dac0 (
.clk(clk96m), 
.rst(rst), 
.data(pcm), 
.dac_out(dac_out)
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
