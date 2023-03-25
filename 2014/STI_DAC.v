reg [2:0] counter_p;
//counter_p
always @(posedge clk)
begin
    if(reset)
    begin
        counter_p <= 7;
    end
    else if(counter_p == 0)
    begin
        counter_p = 7;
    end
    else
    begin
        counter_p = counter_p - 1;
    end
end
