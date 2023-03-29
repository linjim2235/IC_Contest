// tmp_max_cover
always @(posedge CLK)
begin
    if(RST)
        tmp_max_cover <= 6'd0;
    else if(current_state == CAL_COVER_RATE ||current_state == CAL_UP || current_state == CAL_DOWN || current_state == CAL_LEFT || current_state == CAL_RIGHT)
    begin
        if(counter >1)
        begin
            if(mul1 <=16 || mul2 <= 16)
                tmp_max_cover <= max_cover + 1;
        end
    end
end
// max_cover
always @(posedge CLK)
begin
    if(RST)
        tmp_max_cover <= 6'd0;
    else if(current_state == CAL_UP || current_state == CAL_DOWN || current_state == CAL_LEFT || current_state == CAL_RIGHT)
    begin
        if(counter == 6'd40)
        begin
            if(tmp_max_cover >max_cover)
                max_cover <= tmp_max_cover;
        end
    end
end
