module LASER (
           input CLK,
           input RST,
           input [3:0] X,
           input [3:0] Y,
           output reg [3:0] C1X,
           output reg [3:0] C1Y,
           output reg [3:0] C2X,
           output reg [3:0] C2Y,
           output reg DONE);

reg [3:0] bufferX [39:0];
reg [3:0] bufferY [39:0];


always @(posedge CLK)
begin
    if(RST)
    begin
        bufferX[0] <= 4'b0;
        bufferY[0] <= 4'b0;
    end
    else
    begin

    end

end

endmodule


