module SDDivider(
input clk,
input rst,
input en,
input [7:0] value,
output reg sclk
);

reg [7:0] cpt;

always @(posedge clk) begin
  if (rst == 1'b1) begin
    sclk <= 1'b1;
    cpt <=0;
  end
  else begin 
    if (en == 1'b1) begin
      if (cpt == value ) begin
        sclk <= ~sclk;
        cpt <= 0;
      end
      else begin
        cpt <= cpt + 1;
      end
    end
  end
end



endmodule

