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

reg current_state;
reg next_state;
parameter  INIT = 0;
parameter READ = 1;
parameter CAL_CYCLE2_LOCATION = 2;
parameter CAL_COVER_RATE = 3;
parameter CAL_UP = 4;
parameter CAL_DOWN = 4;
parameter CAL_LEFT = 4;
parameter CAL_RIGHT = 4;


wire [4:0] add_1;
wire [4:0] add_2;
reg [3:0] temp_1;
reg [3:0] temp_2;
reg [3:0] temp_3;
reg [3:0] temp_4;
assign add_1 = (temp_1 + temp_2) >> 1;
assign add_2 = (temp_3 + temp_4) >> 1;
reg [5:0] counter;
integer i;

always @(posedge CLK)
begin
    if(RST)
    begin
        for(i=0;i<40;i=i+1)
        begin
            bufferX[i] <= 4'b0;
            bufferY[i] <= 4'b0;
        end
        counter <= 0;
        temp_1 <= 0;
        temp_2 <= 0;
        temp_3 <= 0;
        temp_4 <= 0;
    end
    else if(next_state == READ)
    begin
        if(counter == 0)
        begin
            bufferX[counter] <= X;
            bufferY[counter] <= Y;
            temp_1 <= X;
            temp_3 <= Y;
        end
        else
        begin
            bufferX[counter] <= X;
            bufferY[counter] <= Y;
            temp_1 <= add_1;
            temp_3 <= add_2;
            temp_2 <= X;
            temp_4 <= Y;
        end
    end
end

endmodule


