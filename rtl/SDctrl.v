module SDctrl(
input clk,
input rst,

output sclk,
output mosi,
input miso, 
output cs,

output [6:0] cmd,
input [31:0] address,
input en,

output valid_status,
output [6:0] resp_status,

output rdy,

output [7:0] data_out,
output data_out_valid

);

reg sd_en_q; 
wire en_clk;
wire [7:0] div_clk;
wire en_boot;


/* clock divider */
SDDivider spi_clk0(
.clk(clk),
.rst(rst),
.en(en_clk),
.value(div_clk),
.sclk(sclk)
);


spi_cmd spi_cmd0(
.clk(clk),
.rst(rst),

.cmd(cmd),
.idata(address),
.en(sd_en_q),

.sclk(sclk),
.mosi(mosi),
.miso(miso), 

.resp_status(resp_status),
.valid_status(valid_status),

.rdy(rdy),

.data_out(data_out),
.data_out_valid(data_out_valid)

);


SDBoot SDBoot0(
.clk(clk),
.rst(rst),

.cmd(cmd),
.SDctrl_start(en_boot),
.en_clk(en_clk),
.div_clk(div_clk),
.cs(cs),
.sclk(sclk),
.SDctrl_valid_status(valid_status),
.SDctrl_status(resp_status),
.SDctrl_available(rdy), 

.status()
);




// resync of enable and cs
always @(posedge clk) begin
 if (rst == 1'b1) begin
   sd_en_q <= 1'b0;
 end
 else if (sclk == 1'b0) begin
   sd_en_q <= en || en_boot;
 end
end



endmodule
