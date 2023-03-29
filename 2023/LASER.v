wire [8:0] cmp;
reg[3:0] bigger1, bigger2;
reg[3:0] smaller1, smaller2;
assign cmp =( (bigger1 - smaller1)*(bigger1 - smaller1) + (bigger2 - smaller2)*(bigger2 - smaller2)) <= 16;
