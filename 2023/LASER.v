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

reg [3:0]current_state;
reg [3:0]next_state;
reg [2:0] interval;
parameter  INIT = 0;
parameter READ = 1;
parameter CAL_CIRCLE2_LOCATION = 2;
parameter CAL_COVER_RATE = 3;
parameter CAL_UP = 4;
parameter CAL_DOWN = 5;
parameter CAL_LEFT = 6;
parameter CAL_RIGHT = 7;
parameter OPTIMIZE = 8;
parameter OUTPUT = 9;
reg change;
reg circle;
reg [5:0] tmp_max_cover;
reg [5:0] max_cover;
reg [5:0] counter;
reg [3:0] bufferX [39:0];
reg [3:0] bufferY [39:0];
wire [10:0] add_1;
wire [10:0] add_2;
reg [10:0] temp_1;
reg [10:0] temp_2;
reg [10:0] temp_3;
reg [10:0] temp_4;
reg [3:0] dir1, dir2;
assign add_1 = (temp_1 + temp_2);
assign add_2 = (temp_3 + temp_4);
integer i;

reg [3:0] tmpx1, tmpx2, tmpy1, tmpy2;
wire [8:0] mul1, mul2;
assign mul1 =(tmpx1 - bufferX[counter])*(tmpx1 - bufferX[counter]) + (tmpy1 - bufferY[counter])*(tmpy1 - bufferY[counter]);
assign mul2 =(tmpx2 - bufferX[counter])*(tmpx2 - bufferX[counter]) + (tmpy2 - bufferY[counter])*(tmpy2 - bufferY[counter]);
always @(posedge CLK or posedge RST) begin
    if(RST)
        current_state <= INIT;
    else 
        current_state <= next_state;
end

always @(*) begin
case (current_state)
    INIT:
        next_state =(RST)?INIT:READ;
    READ:
        next_state =  (counter == 6'd39)?CAL_CIRCLE2_LOCATION:READ;
    CAL_CIRCLE2_LOCATION:
        next_state = CAL_COVER_RATE;
    CAL_COVER_RATE:
        next_state = (counter == 6'd40)?CAL_DOWN:CAL_COVER_RATE;
    CAL_DOWN:
        next_state =(counter == 6'd40)?CAL_UP:CAL_DOWN;
    CAL_UP:
        next_state =(counter == 6'd40)?CAL_RIGHT:CAL_UP;
    
    CAL_RIGHT:
        next_state =(counter == 6'd40)?CAL_LEFT:CAL_RIGHT;
    CAL_LEFT:
        next_state =(counter == 6'd40)?OPTIMIZE:CAL_LEFT;
        
    OPTIMIZE:
        next_state =(dir1 == 0 && dir2 == 0 && change ==0 && interval == 3'd7)?OUTPUT:CAL_DOWN;
    OUTPUT:
        next_state = READ;
    default: 
        next_state = INIT;
endcase
end
// buffer
always @(posedge CLK)
begin
    if(RST)
    begin
        for(i=0;i<40;i=i+1)
        begin
            bufferX[i] <= 4'b0;
            bufferY[i] <= 4'b0;
        end
        temp_1 <= 0;
        temp_2 <= 0;
        temp_3 <= 0;
        temp_4 <= 0;
    end
    else if(next_state == READ || current_state == READ)
    begin
        if(counter == 0)
        begin
            bufferX[counter] <= X;
            bufferY[counter] <= Y;
            temp_1 <= X;
            temp_3 <= Y;
        end
        else if(counter == 1)
        begin
            bufferX[counter] <= X;
            bufferY[counter] <= Y;
            temp_2 <= X;
            temp_4 <= Y;
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
// tmp_max_cover
always @(posedge CLK) begin
if(RST)
    tmp_max_cover <= 6'd0;
else if(current_state == CAL_COVER_RATE)
begin
    if(counter >0)
    begin
        if(mul1 <=16)
            tmp_max_cover <= tmp_max_cover + 1;
    end
end
else if(current_state == CAL_UP || current_state == CAL_DOWN || current_state == CAL_LEFT ||current_state == CAL_RIGHT)
begin
    if(counter >0)
    begin
        if(mul1 <=16 || mul2 <= 16)
            tmp_max_cover <= tmp_max_cover + 1;
    end
    else
        tmp_max_cover <= 0;
end
else if(current_state == OUTPUT)
    tmp_max_cover <= 0;
end
// max_cover
always @(posedge CLK) begin
if(RST)
    max_cover <= 6'd0;
else if(current_state == CAL_COVER_RATE || current_state == CAL_UP || current_state == CAL_DOWN || current_state == CAL_LEFT || current_state == CAL_RIGHT)
begin
    if(counter == 6'd40)
    begin
        if(tmp_max_cover >max_cover)
            max_cover <= tmp_max_cover;
    end
end
else if(current_state == OUTPUT)
    max_cover <= 0;
end
// dir
always @(posedge CLK)
begin
if(RST)
begin
    dir1 <= 0;
    dir2 <= 0;
    change <= 0;
end
else if(current_state == OPTIMIZE && next_state == CAL_DOWN)
begin
    if(!circle && dir2!=0)
        change <= 1;
    else if(circle && dir1!=0)
        change <= 1;
    else
        change <=0;
    dir1 <= 0;
    dir2 <= 0;
end
else if(counter == 6'd40 && tmp_max_cover >max_cover)
begin
    if(circle)
    begin
        change <= 1;
        case(current_state)
            CAL_UP:
                dir2 <= 1;
            CAL_DOWN:
                dir2 <= 2;
            CAL_LEFT:
                dir2 <= 3;
            CAL_RIGHT:
                dir2 <= 4;
        endcase
    end
    else
    begin
        change <= 1;
        case(current_state)
            CAL_UP:
                dir1 <= 1;
            CAL_DOWN:
                dir1 <= 2;
            CAL_LEFT:
                dir1 <= 3;
            CAL_RIGHT:
                dir1 <= 4;
        endcase
    end
end
else if(current_state == OUTPUT)
begin
    dir1 <= 0;
    dir2 <= 0;
end

end

// circle
always @(posedge CLK) begin
if(RST)
    circle <= 0;
else if(current_state == CAL_LEFT)
begin
    if(counter == 6'd40)
        if((!circle && dir2==0) || (circle && dir1 == 0))
            circle <= ~circle;
end
else if(current_state == OUTPUT)
    circle <= 0;
end
// tmpx. tmpy
always @(posedge CLK) begin
if(RST)
begin
    tmpx1 <= 0;
    tmpx2 <= 0;
    tmpy1 <= 0;
    tmpy2 <= 0;
end
else if(next_state == CAL_COVER_RATE)
begin
    tmpx1 <= C1X;
    tmpy1 <= C1Y;
end
else if(current_state == CAL_UP)
begin
    if(circle)//circel 1
    begin
        tmpx1 <= C1X-interval;
        tmpy1 <= C1Y;
        tmpx2 <= C2X;
        tmpy2 <= C2Y;
    end
    else // circle 2
    begin
        tmpx1 <= C1X;
        tmpy1 <= C1Y;
        tmpx2 <= C2X-interval;
        tmpy2 <= C2Y;
    end
end
else if(current_state == CAL_DOWN)
begin
    if(circle)//circel 1
    begin
        tmpx1 <= C1X+interval;
        tmpy1 <= C1Y;
        tmpx2 <= C2X;
        tmpy2 <= C2Y;
    end
    else // circle 2
    begin
        tmpx1 <= C1X;
        tmpy1 <= C1Y;
        tmpx2 <= C2X+interval;
        tmpy2 <= C2Y;
    end
end
else if(current_state == CAL_RIGHT)
begin
    if(circle)//circel 1
    begin
        tmpx1 <= C1X;
        tmpy1 <= C1Y-interval;
        tmpx2 <= C2X;
        tmpy2 <= C2Y;
    end
    else // circle 2
    begin
        tmpx1 <= C1X;
        tmpy1 <= C1Y;
        tmpx2 <= C2X;
        tmpy2 <= C2Y+interval;
    end
end
else if(current_state == CAL_LEFT)
begin
    if(circle)//circle 2
    begin
        tmpx1 <= C1X;
        tmpy1 <= C1Y+interval;
        tmpx2 <= C2X;
        tmpy2 <= C2Y;
    end
    else // circle 2
    begin
        tmpx1 <= C1X;
        tmpy1 <= C1Y;
        tmpx2 <= C2X;
        tmpy2 <= C2Y-interval;
    end
end

end


// counter
always @(posedge CLK) begin
if(RST)
    counter <= 0;
else if(current_state == OUTPUT)
    counter <= 0;
else if(next_state == READ)
    counter <= counter + 1;
else if(current_state == CAL_CIRCLE2_LOCATION)
    counter <= 0;
else if(current_state == CAL_COVER_RATE)
begin
    if(counter == 40)
        counter <= 0;
    else
        counter <= counter + 1;
end
else if(current_state == CAL_UP || current_state == CAL_DOWN || current_state == CAL_LEFT|| current_state == CAL_RIGHT )
begin
    if(counter ==6'd40)
        counter <= 0;
    else 
        counter <= counter +1;
end
else 
    counter <= 0;
end

// OUTPUT
always @(posedge CLK) begin
if(RST)
begin
    C1X <= 0;
    C1Y <= 0;
    C2X <= 0;
    C2Y <= 0;
    DONE <= 0;
end
else if(current_state == CAL_CIRCLE2_LOCATION)
begin
    C1X <= add_1/40;
    C1Y <= add_2/40;
    C2X <= add_1/40;
    C2Y <= add_2/40;
end
else if(current_state == CAL_UP || current_state == CAL_DOWN || current_state == CAL_LEFT || current_state == CAL_RIGHT)
begin
    if(counter == 6'd40)
    begin
        if(tmp_max_cover > max_cover)
        begin
            C1X <= tmpx1;
            C1Y <= tmpy1;
            C2X <= tmpx2;
            C2Y <= tmpy2;
        end
    end
end

if(next_state == OUTPUT)
begin
    DONE <= 1;
end
else 
    DONE <= 0;
end
// interval
always @(posedge CLK) begin
if(RST)
    interval <=1;
else if(change)
    interval <= 1;
else if(current_state == OPTIMIZE && change == 0 && dir1 == 0 && dir2 ==0)
    interval <= interval +1;
else if(current_state == READ)
    interval <= 1;

end
endmodule

