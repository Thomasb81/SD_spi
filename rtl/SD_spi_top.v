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
reg note_on;
reg note_off;


wire [10:0] driver_data_cpt;


reg [10:0] tick_48k;
reg fifo_rd_en;
wire [15:0] fifo_out;
wire [15:0] pcm;
wire dac_out;

wire [2:0] SDdriver_state;


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

    note_on <= 1'b0;
    note_off <= 1'b0;

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
        7'd5: note_on <= data_rx[0];
        7'd6: note_off <= data_rx[0];
        endcase
      end
    end
    endcase
  end
end

assign data_tx = 
               8'h55;

assign valid_data_tx = (rx_state == `RX_RD) ? 1'b1 : 1'b0;

assign {led4,led3,led2,led1} = {SDdriver_state,note_on};

assign audio_l = dac_out;
assign audio_r = dac_out;



SDFeed SD_ss0(
.clk96m(clk96m),
.rst(rst),

.sclk(sck),
.mosi(di),
.miso(do),
.cs(cs),

.id(8'h00),
.note_on(note_on),
.note_off(note_off),
.completed(),

.rd_en(fifo_rd_en),
.data_out(fifo_out),
.fifo_full(fifo_full),
.fifo_empty(fifo_empty),
.fifo_halffull(fifo_half),
.SDdriver_state(SDdriver_state)
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

assign pcm = fifo_out;

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
