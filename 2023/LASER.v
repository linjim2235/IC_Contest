
always @(posedge CLK)
begin
    if(RST)
    begin
        dir1 <= 0;
        dir2 <= 0;
    end
    else if(counter == 6'd40 && tmp_max_cover > max_cover)
    begin
        if(circle)
        begin
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
    else if(counter == 6'd40 && tmp_max_cover < max_cover &&current_state == CAL_RIGHT)
    begin
        if(circle)
            dir2 <= 0;
        else
            dir1 <= 0;
    end

end
