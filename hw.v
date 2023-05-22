`timescale 1ns/10ps
module  ATCONV(
            input		clk,
            input		reset,
            output	reg	busy,
            input		ready,

            output reg	[11:0]	iaddr,
            input signed [12:0]	idata,

            output	reg 	cwr,
            output  reg	[11:0]	caddr_wr,
            output reg 	[12:0] 	cdata_wr,

            output	reg 	crd,
            output reg	[11:0] 	caddr_rd,
            input 	[12:0] 	cdata_rd,

            output reg 	csel
        );

//=================================================
//            write your design below
//=================================================


reg [3:0] count;//0~15
reg [12:0] addr;//0~4095 //(can use right 6 bits be index X)(can use left 6 bits be index Y)
reg [1:0] CurrentState, NextState;

reg [9:0] max_pooling_addr;


reg signed [29:0] sum;// 2^13 * 2^13 * 2^4 = 2^30  By the way 2^4 = 9 pixel
wire signed [29:0] a;
reg signed [12:0] pixels;
reg signed [12:0] kernel;
assign a = pixels*kernel;

reg signed [12:0] data_temp_1 [5:0];
reg signed [12:0] data_temp_2 [5:0];
wire signed [29:0] temp1a;
wire signed [29:0] temp2a;
assign temp1a = ((data_temp_1[0]>>4)+(data_temp_1[1]>>3)+(data_temp_1[2]>>2)-(data_temp_1[3])+(data_temp_1[4]>>4)+(data_temp_1[5]>>3))*(-1);
assign temp2a = ((data_temp_2[0]>>4)+(data_temp_2[1]>>3)+(data_temp_2[2]>>2)-(data_temp_2[3])+(data_temp_2[4]>>4)+(data_temp_2[5]>>3))*(-1);

reg signed [12:0] cmpMax;
reg signed [12:0] temp;
wire need_swap;
assign need_swap = temp > cmpMax;

wire [12:0] addr2 = addr + 1;
wire [12:0] addr3 = addr + 64;
wire [12:0] addr4 = addr + 65;

parameter Initialize=0;
parameter Convolutional=1;
parameter Max_pooling=2;
parameter ok=3;
parameter Bias = {13'b1111111111111,13'h1FF4,4'd0};


always@(posedge clk or posedge reset)
begin
    if(reset)
    begin
        busy <= 0;
    end
    else if(ready)
    begin
        busy <= 1;
        iaddr <= 0;
        cwr <= 0;
        crd <= 0;
        caddr_wr <= 0;
        cdata_wr <= 0;
        caddr_rd <= 0;
        CurrentState <= Convolutional;
        count <= 0;
        addr <= 0;
        sum <= 0;
        max_pooling_addr <= 0;
        temp <= 0;
        data_temp_1[0] <= 0;
        data_temp_1[1] <= 0;
        data_temp_1[2] <= 0;
        data_temp_1[3] <= 0;
        data_temp_1[4] <= 0;
        data_temp_1[5] <= 0;
        data_temp_2[0] <= 0;
        data_temp_2[1] <= 0;
        data_temp_2[2] <= 0;
        data_temp_2[3] <= 0;
        data_temp_2[4] <= 0;
        data_temp_2[5] <= 0;
    end
    else
    begin
        CurrentState <= NextState;
        case(CurrentState)
            Initialize:
            begin

            end
            Convolutional:
            begin
                case(count)
                    0:
                    begin
                        count <= count + 1;
                        sum <= 0;
                        if(addr[11:6] == 6'd0 || addr[11:6] == 6'd1 || addr[5:0] == 6'd0 || addr[5:0] == 6'd1)
                        begin
                            if(addr == 0||addr == 1||addr == 64||addr == 65)
                                iaddr <= 0;
                            else if(addr[5:0] == 6'd0)//index X
                                iaddr <= addr - 128;
                            else if(addr[5:0] == 6'd1)//index X
                                iaddr <= addr - 129;
                            else if(addr[11:6] == 6'd0)//index Y
                                iaddr <= addr - 2;
                            else //(addr[11:6] == 6'd1)//index Y
                                iaddr <= addr - 66;
                        end
                        else
                            iaddr <= addr - 130;
                    end
                    1:
                    begin
                        count <= count + 1;
                        pixels <= idata;
                        kernel <= 13'h1FFF;
                        if(addr[11:6] == 6'd0)//index Y = 0
                            iaddr <= addr;
                        else if(addr[11:6] == 6'd1)//index Y = 1
                            iaddr <= addr - 64;
                        else
                            iaddr <= addr - 128;
                    end
                    2:
                    begin
                        count <= count + 1;
                        kernel <= 13'h1FFE;
                        sum <= a;
                        pixels <= idata;
                        if(addr[11:6] == 6'd0 || addr[11:6] == 6'd1 || addr[5:0] == 6'd62 || addr[5:0] == 6'd63)
                        begin
                            if(addr == 62||addr == 63||addr == 126||addr == 127)
                                iaddr <= 63;
                            else if(addr[5:0] == 6'd63)//index X
                                iaddr <= addr - 128;
                            else if(addr[5:0] == 6'd62)//index X
                                iaddr <= addr - 127;
                            else if(addr[11:6] == 6'd0)//index Y
                                iaddr <= addr + 2;
                            else //(addr[11:6] == 6'd1)//index Y
                                iaddr <= addr - 62;
                        end
                        else
                            iaddr <= addr - 126;

                        if(addr[5:0] == 6'd0)
                        begin
                            data_temp_2[0] <= idata;
                        end
                        else if(addr[5:0] == 6'd1)
                        begin
                            data_temp_1[0] <= idata;
                        end
                    end
                    3:
                    begin
                        kernel <= 13'h1FFF;
                        pixels <= idata;

                        if(addr[5:0] == 6'd0)
                        begin
                            data_temp_2[1] <= idata;
                            sum <= sum + a;
                            count <= count + 1;
                            if(addr[5:0] == 6'd0)//index X = 0
                                iaddr <= addr;
                            else if(addr[5:0] == 6'd1)//index X = 1
                                iaddr <= addr - 1;
                            else
                                iaddr <= addr - 2;
                        end
                        else if(addr[5:0] == 6'd1)
                        begin
                            data_temp_1[1] <= idata;
                            sum <= sum + a;
                            count <= count + 1;
                            if(addr[5:0] == 6'd0)//index X = 0
                                iaddr <= addr;
                            else if(addr[5:0] == 6'd1)//index X = 1
                                iaddr <= addr - 1;
                            else
                                iaddr <= addr - 2;
                        end
                        else if(addr[0])
                        begin
                            data_temp_1[0] <= data_temp_1[1];
                            data_temp_1[1] <= idata;
                            sum <= temp1a << 4;
                            count <= count + 3;
                            if(addr[5:0] == 6'd62)//index X = 62
                                iaddr <= addr + 1;
                            else if(addr[5:0] == 6'd63)//index X = 63
                                iaddr <= addr;
                            else
                                iaddr <= addr + 2;
                        end
                        else
                        begin
                            data_temp_2[0] <= data_temp_2[1];
                            data_temp_2[1] <= idata;
                            sum <= temp2a << 4;
                            count <= count + 3;
                            if(addr[5:0] == 6'd62)//index X = 62
                                iaddr <= addr + 1;
                            else if(addr[5:0] == 6'd63)//index X = 63
                                iaddr <= addr;
                            else
                                iaddr <= addr + 2;
                        end
                    end
                    4:
                    begin
                        count <= count + 1;
                        kernel <= 13'h1FFC;
                        sum <= sum + a;
                        pixels <= idata;
                        iaddr <= addr;
                    end
                    5:
                    begin
                        count <= count + 1;
                        kernel <= 13'h0010;
                        sum <= sum + a;
                        pixels <= idata;
                        if(addr[5:0] == 6'd62)//index X = 62
                            iaddr <= addr + 1;
                        else if(addr[5:0] == 6'd63)//index X = 63
                            iaddr <= addr;
                        else
                            iaddr <= addr + 2;

                        if(addr[5:0] == 6'd0)
                        begin
                            data_temp_2[2] <= idata;
                        end
                        else if(addr[5:0] == 6'd1)
                        begin
                            data_temp_1[2] <= idata;
                        end
                    end
                    6:
                    begin
                        kernel <= 13'h1FFC;
                        sum <= sum + a;
                        pixels <= idata;

                        if(addr[5:0] == 6'd0)
                        begin
                            data_temp_2[3] <= idata;
                            count <= count + 1;
                            if(addr[11:6] == 6'd62 || addr[11:6] == 6'd63 || addr[5:0] == 6'd0 || addr[5:0] == 6'd1)
                            begin
                                if(addr == 3968||addr == 3969||addr == 4032||addr == 4033)
                                    iaddr <= 4032;
                                else if(addr[5:0] == 6'd0)//index X
                                    iaddr <= addr + 128;
                                else if(addr[5:0] == 6'd1)//index X
                                    iaddr <= addr + 127;
                                else if(addr[11:6] == 6'd62)//index Y
                                    iaddr <= addr + 62;
                                else //(addr[11:6] == 6'd63)//index Y
                                    iaddr <= addr - 2;
                            end
                            else
                                iaddr <= addr + 126;
                        end
                        else if(addr[5:0] == 6'd1)
                        begin
                            data_temp_1[3] <= idata;
                            count <= count + 1;
                            if(addr[11:6] == 6'd62 || addr[11:6] == 6'd63 || addr[5:0] == 6'd0 || addr[5:0] == 6'd1)
                            begin
                                if(addr == 3968||addr == 3969||addr == 4032||addr == 4033)
                                    iaddr <= 4032;
                                else if(addr[5:0] == 6'd0)//index X
                                    iaddr <= addr + 128;
                                else if(addr[5:0] == 6'd1)//index X
                                    iaddr <= addr + 127;
                                else if(addr[11:6] == 6'd62)//index Y
                                    iaddr <= addr + 62;
                                else //(addr[11:6] == 6'd63)//index Y
                                    iaddr <= addr - 2;
                            end
                            else
                                iaddr <= addr + 126;
                        end
                        else if(addr[0])
                        begin
                            data_temp_1[2] <= data_temp_1[3];
                            data_temp_1[3] <= idata;
                            count <= count + 3;
                            if(addr[11:6] == 6'd62 || addr[11:6] == 6'd63 || addr[5:0] == 6'd62 || addr[5:0] == 6'd63)
                            begin
                                if(addr == 4030||addr == 4031||addr == 4094||addr == 4095)
                                    iaddr <= 4095;
                                else if(addr[5:0] == 6'd62)//index X
                                    iaddr <= addr + 129;
                                else if(addr[5:0] == 6'd63)//index X
                                    iaddr <= addr + 128;
                                else if(addr[11:6] == 6'd62)//index Y
                                    iaddr <= addr + 66;
                                else //(addr[11:6] == 6'd63)//index Y
                                    iaddr <= addr + 2;
                            end
                            else
                                iaddr <= addr + 130;
                        end
                        else
                        begin
                            data_temp_2[2] <= data_temp_2[3];
                            data_temp_2[3] <= idata;
                            count <= count + 3;
                            if(addr[11:6] == 6'd62 || addr[11:6] == 6'd63 || addr[5:0] == 6'd62 || addr[5:0] == 6'd63)
                            begin
                                if(addr == 4030||addr == 4031||addr == 4094||addr == 4095)
                                    iaddr <= 4095;
                                else if(addr[5:0] == 6'd62)//index X
                                    iaddr <= addr + 129;
                                else if(addr[5:0] == 6'd63)//index X
                                    iaddr <= addr + 128;
                                else if(addr[11:6] == 6'd62)//index Y
                                    iaddr <= addr + 66;
                                else //(addr[11:6] == 6'd63)//index Y
                                    iaddr <= addr + 2;
                            end
                            else
                                iaddr <= addr + 130;
                        end
                    end
                    7:
                    begin
                        count <= count + 1;
                        kernel <= 13'h1FFF;
                        sum <= sum + a;
                        pixels <= idata;
                        if(addr[11:6] == 6'd62)//index Y = 62
                            iaddr <= addr + 64;
                        else if(addr[11:6] == 6'd63)//index Y = 63
                            iaddr <= addr;
                        else
                            iaddr <= addr + 128;
                    end
                    8:
                    begin
                        count <= count + 1;
                        kernel <= 13'h1FFE;
                        sum <= sum + a;
                        pixels <= idata;
                        if(addr[11:6] == 6'd62 || addr[11:6] == 6'd63 || addr[5:0] == 6'd62 || addr[5:0] == 6'd63)
                        begin
                            if(addr == 4030||addr == 4031||addr == 4094||addr == 4095)
                                iaddr <= 4095;
                            else if(addr[5:0] == 6'd62)//index X
                                iaddr <= addr + 129;
                            else if(addr[5:0] == 6'd63)//index X
                                iaddr <= addr + 128;
                            else if(addr[11:6] == 6'd62)//index Y
                                iaddr <= addr + 66;
                            else //(addr[11:6] == 6'd63)//index Y
                                iaddr <= addr + 2;
                        end
                        else
                            iaddr <= addr + 130;

                        if(addr[5:0] == 6'd0)
                        begin
                            data_temp_2[4] <= idata;
                        end
                        else if(addr[5:0] == 6'd1)
                        begin
                            data_temp_1[4] <= idata;
                        end
                    end
                    9:
                    begin
                        count <= count + 1;
                        kernel <= 13'h1FFF;
                        sum <= sum + a;
                        pixels <= idata;
                        if(addr[5:0] == 6'd0)
                        begin
                            data_temp_2[5] <= idata;
                        end
                        else if(addr[5:0] == 6'd1)
                        begin
                            data_temp_1[5] <= idata;
                        end
                        else if(addr[0])
                        begin
                            data_temp_1[4] <= data_temp_1[5];
                            data_temp_1[5] <= idata;
                        end
                        else
                        begin
                            data_temp_2[4] <= data_temp_2[5];
                            data_temp_2[5] <= idata;
                        end
                    end
                    10:
                    begin
                        count <= count + 1;
                        sum <= sum + a;
                    end
                    11:
                    begin
                        count <= count + 1;
                        sum <= sum + Bias;
                    end
                    12:
                    begin
                        count <= count + 1;
                        if(sum[29])
                        begin
                            cdata_wr <= 0;
                        end
                        else
                        begin
                            cdata_wr <= sum[16:4];
                        end
                        csel <= 0;
                        cwr <= 1;
                        caddr_wr <= addr;
                    end
                    13:
                    begin
                        cwr <= 0;
                        if(addr == 4095)
                        begin
                            count <= 0;
                            addr <= 0;
                        end
                        else if(addr[5:0] == 6'd63 || addr[5:0] == 6'd0)
                        begin
                            count <= 0;
                            addr <= addr + 1;
                        end
                        else
                        begin
                            count <= 3;
                            addr <= addr + 1;
                            if(addr[11:6] == 6'd0 || addr[11:6] == 6'd1 || addr[5:0] == 6'd61 || addr[5:0] == 6'd62)
                            begin
                                if(addr == 61 ||addr == 62||addr == 125||addr == 126)
                                    iaddr <= 63;
                                else if(addr[5:0] == 6'd61)//index X
                                    iaddr <= addr - 126;
                                else if(addr[5:0] == 6'd62)//index X
                                    iaddr <= addr - 127;
                                else if(addr[11:6] == 6'd0)//index Y
                                    iaddr <= addr + 3;
                                else //(addr[11:6] == 6'd1)//index Y
                                    iaddr <= addr - 61;
                            end
                            else
                                iaddr <= addr - 125;
                        end
                    end
                    default:
                    begin
                        count <= count + 1;
                    end
                endcase
            end
            Max_pooling:
            begin
                count <= count + 1;
                case(count)
                    0:
                    begin
                        crd <= 1;
                        caddr_rd <= addr;
                        csel <= 0;
                    end
                    1:
                    begin
                        cmpMax <= cdata_rd;
                        caddr_rd <= addr2;//addr + 1;
                    end
                    2:
                    begin
                        temp <= cdata_rd;
                        caddr_rd <= addr3; //addr + 64;
                    end
                    3:
                    begin
                        temp <= cdata_rd;
                        if(need_swap)
                            cmpMax <= temp;
                        caddr_rd <= addr4;//addr + 65;
                    end
                    4:
                    begin
                        temp <= cdata_rd;
                        if(need_swap)
                            cmpMax <= temp;
                    end
                    5:
                    begin
                        if(need_swap)
                            cmpMax <= temp;
                    end
                    6:
                    begin
                        if(cmpMax[3:0] > 4'b0)
                            cmpMax <= cmpMax + 13'd16;
                    end
                    7:
                    begin
                        cwr <= 1;
                        caddr_wr <= max_pooling_addr;
                        cdata_wr <={cmpMax[12:4],4'd0};
                        csel <= 1;
                    end
                    8:
                    begin
                        if(addr[5:0] == 6'd62)
                        begin
                            addr <= addr + 66;
                        end
                        else
                        begin
                            addr <= addr + 2;
                        end
                        count <= 0;
                        cwr <= 0;
                        max_pooling_addr <= max_pooling_addr + 1;
                    end
                    default:
                    begin

                    end
                endcase
            end
            ok:
            begin
                busy <= 0;
            end
        endcase

    end
end
// State machine (Combinational circuit)
always@(*)
begin
    case(CurrentState)
        Initialize:
        begin
            NextState = CurrentState;
        end
        Convolutional:
        begin
            if(count == 13 && addr == 4095)
                NextState = Max_pooling;
            else
                NextState = Convolutional;
        end
        Max_pooling:
        begin
            if(addr == 4096)
                NextState = ok;
            else
                NextState = Max_pooling;
        end
        ok:
        begin
            NextState = CurrentState;
        end
    endcase
end
endmodule
