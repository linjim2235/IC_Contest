module STI_DAC(clk ,reset, load, pi_data, pi_length, pi_fill, pi_msb, pi_low, pi_end,
               so_data, so_valid,
               pixel_finish, pixel_dataout, pixel_addr,
               pixel_wr);

input		clk, reset;
input		load, pi_msb, pi_low, pi_end;
input	[15:0]	pi_data;
input	[1:0]	pi_length;
input		pi_fill;
output reg	so_data, so_valid;

output reg pixel_finish, pixel_wr;
output reg [7:0] pixel_addr;
output reg [7:0] pixel_dataout;

//==============================================================================
reg [31:0] buffer;
reg [2:0] current_state;
reg [2:0] next_state;
parameter INIT = 0;
parameter INPUT_DATA = 1;
parameter DEAL_WITH_DATA = 2;
parameter OUTPUT_SO = 3;
parameter OUTPUT_PIXEL = 4;
parameter FINISH = 5;
reg [4:0] ptr;
reg [4:0] counter;

always@(posedge clk or posedge rst)
begin
    if(rst)
    begin
        so_data <= 0;
        so_valid <= 0;
        pixel_finish <= 0;
        pixel_wr <= 0;
        pixel_addr <= 0;
        pixel_dataout <= 0;

        count <= 0;
        temp <= 0;
        CurrentState <= GetData;

    end
    else
    begin
        CurrentState <= NextState;
        case(CurrentState)
            GetData:
            begin
                if(load)
                begin

                end
            end
            SendData:
            begin

            end
            DEAL_WITH_DATA:
            begin
                case(pi_length)
                    00:
                    begin
                        counter <= 8;
                        if(pi_low)
                        begin
                            buffer[31:24]= buffer[15:8];
                        end
                        else
                        begin
                            buffer[31:24]= buffer[7:0];
                        end
                        if(pi_msb)
                            ptr <= 31;
                        else
                            ptr <= 24;
                    end
                    01:
                    begin
                        counter <= 16;
                        if(pi_msb)
                            ptr <= 31;
                        else
                            ptr <= 16;
                    end
                    10:
                    begin
                        counter <= 24;
                        if(pi_msb)
                            ptr <= 31;
                        else
                            ptr <= 8;
                    end
                    11:
                    begin
                        counter <= 32;
                        if(pi_msb)
                            ptr <= 31;
                        else
                            ptr <= 0;
                    end
                endcase
            end
        endcase
    end

end


// State machine (Combinational circuit)
always@(*)
begin
    case(CurrentState)
        GetData:
        begin
            if(count == 3)
                NextState = SendData;
            else
                NextState = GetData;
        end
        SendData:
        begin
            if(count == 31)
            case(bitsAddr)
                8:
                    NextState = ok;
                default:
                    NextState = GetData;
            endcase
            else
                NextState = SendData;
        end
        ok:
        begin
            NextState = ok;
        end
        default:
        begin
            NextState = CurrentState;
        end
    endcase
end





endmodule
