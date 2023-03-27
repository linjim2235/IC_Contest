module STI_DAC(clk ,reset, load, pi_data, pi_length, pi_fill, pi_msb, pi_low, pi_end,
               so_data, so_valid,
               pixel_finish, pixel_dataout, pixel_addr,
               pixel_wr);

input		clk, reset;
input		load, pi_msb, pi_low, pi_end;
input	[15:0]	pi_data;
input	[1:0]	pi_length;
input		pi_fill;
output	reg 	so_data, so_valid;

output reg  pixel_finish, pixel_wr;
output reg [7:0] pixel_addr;
output reg [7:0] pixel_dataout;
reg [31:0] buffer;
reg [2:0] current_state;
reg [2:0] next_state;
reg [4:0] ptr;
reg [2:0]counter_p;
reg [4:0] counter;
parameter INIT = 0;
parameter INPUT_DATA = 1;
parameter DEAL_WITH_DATA = 2;
parameter OUTPUT = 3;
parameter ADD_ZERO = 4;
parameter DOWN_ZERO = 5;
parameter FINISH = 6;

//==============================================================================
always @(posedge clk)
begin
    if(reset)
        current_state <= INIT;
    else
        current_state <= next_state;
end

always @(*)
begin
    case (current_state)
        INIT:
            if(pi_end)
                next_state = ADD_ZERO;
            else
                next_state =  (load)? INPUT_DATA : INIT;
        INPUT_DATA:
            next_state = DEAL_WITH_DATA;
        DEAL_WITH_DATA:
            next_state = OUTPUT;
        OUTPUT:
        begin
            next_state = (counter == 0)?INIT:OUTPUT;
        end
        ADD_ZERO:
            next_state = (pixel_addr == 8'd255)?FINISH:DOWN_ZERO;
        DOWN_ZERO:
            next_state = ADD_ZERO;
        FINISH:
            next_state = FINISH;
        default:
            next_state = INIT;
    endcase
end

// buffer
always @(posedge clk)
begin
    if(reset)
        buffer <= 32'b0;
    else if(current_state == INPUT_DATA)
    begin
        case (pi_length)
            2'b00:
            begin
                if(pi_low)
                begin
                    buffer[31:24] <= pi_data[15:8];
                    buffer[23:0] <= 24'd0;
                end
                else
                begin
                    buffer[31:24] <= pi_data[7:0];
                    buffer[23:0] <= 24'd0;
                end
            end
            2'b10:
            begin
                if(pi_fill)
                begin
                    buffer[31:16] <= pi_data;
                    buffer[15:0] <= 16'd0;
                end
                else
                begin
                    buffer[31:24] <= 8'd0;
                    buffer[23:8] <= pi_data;
                    buffer[7:0] <= 8'd0;
                end
            end
            2'b11:
            begin
                if(pi_fill)
                begin
                    buffer[31:16] <= pi_data;
                    buffer[15:0] <= 16'd0;
                end
                else
                begin
                    buffer[31:16] <= 16'd0;
                    buffer[15:0] <= pi_data;
                end
            end
            default:
            begin
                buffer[31:16] <= pi_data;
                buffer[15:0] <= 16'd0;
            end
        endcase
    end
end

// counter
always @(posedge clk)
begin
    if(reset)
        counter <= 0;
    else if(current_state == INPUT_DATA)
    begin
        case(pi_length)
            2'b00:
            begin
                counter <= 7;
            end
            2'b01:
            begin
                counter <= 15;
            end
            2'b10:
            begin
                counter <= 23;
            end
            2'b11:
            begin
                counter <= 31;
            end
        endcase
    end
    else if(current_state == OUTPUT)
        counter <= counter -1;
end

// ptr
always @(posedge clk)
begin
    if(reset)
        ptr <= 0;
    else if(current_state == INPUT_DATA)
    begin
        if(pi_msb)
            ptr <= 5'd31;
        else
        begin
            case(pi_length)
                2'b00:
                    ptr <= 24;
                2'b01:
                    ptr <= 16;
                2'b10:
                    ptr <= 8;
                2'b11:
                    ptr <= 0;
                default:
                    ptr <= 0;
            endcase
        end
    end
    else if(next_state == OUTPUT)
        ptr <= (pi_msb) ? (ptr -1): (ptr +1);
end
// output_so
always @(posedge clk)
begin
    if(reset)
    begin
        so_data <= 0;
        so_valid <= 0;
    end
    else if(next_state == OUTPUT)
    begin
        so_valid <= 1;
        so_data <= buffer[ptr];
    end
    else
    begin
        so_valid <= 0;
        so_data <= 0;
    end
end

//counter_p
always @(posedge clk)
begin
    if(reset)
        counter_p <= 7;
    else if( next_state == OUTPUT && counter_p == 0)
    begin
        counter_p <= 7;
    end
    else if (next_state == OUTPUT)
    begin
        counter_p <= counter_p - 1;
    end
end

// output_pixel
always @(posedge clk)
begin
    if(reset)
    begin
        pixel_addr <= 8'd0;
        pixel_finish <= 0;
        pixel_wr <= 0;
        pixel_dataout <= 0;
    end
    else if(current_state == OUTPUT || next_state == OUTPUT)
    begin
        if(counter_p == 0)
            pixel_wr <= 1;
        else
            pixel_wr <= 0;
        if(pixel_wr == 1)
            pixel_addr <= pixel_addr +1;
        pixel_dataout[counter_p] <= buffer[ptr];
    end
    else if(next_state == ADD_ZERO)
    begin
        pixel_wr <= 1;
        pixel_dataout <= 0;
    end
    else if(next_state == DOWN_ZERO)
    begin
        pixel_wr <= 0;
        pixel_addr <= pixel_addr +1;
    end
    else if(current_state == FINISH)
        pixel_finish <= 1;
    else
    begin
        pixel_wr <= 0;
    end

end


endmodule
