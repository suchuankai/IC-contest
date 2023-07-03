module STI_DAC(clk ,reset, load, pi_data, pi_length, pi_fill, pi_msb, pi_low, pi_end,
	       so_data, so_valid,
	       oem_finish, oem_dataout, oem_addr,
	       odd1_wr, odd2_wr, odd3_wr, odd4_wr, even1_wr, even2_wr, even3_wr, even4_wr);

input			clk, reset;
input			load, pi_msb, pi_low, pi_end; 
input	[15:0]	pi_data;
input	[1:0]	pi_length;
input			pi_fill;
output	reg		so_data, so_valid;

output  reg oem_finish, odd1_wr, odd2_wr, odd3_wr, odd4_wr, even1_wr, even2_wr, even3_wr, even4_wr;
output  reg [4:0] oem_addr;
output  reg [7:0] oem_dataout;

reg [15:0] buffer;
reg [7:0] oem_dataout_buf;

reg [5:0] counter;
reg [1:0] select;
reg even;
reg last;

reg nowState, nextState;

parameter RECEIVE_DATA = 1'b0,
		  SEND_DATA    = 1'b1;



wire [4:0] max_length = {pi_length, 3'b111};
wire [4:0] padding = ((pi_msb ^ pi_fill) & pi_length[1]) << (pi_length+1)  ; // if pi_fill = 0 need padding from head
wire start = (counter>padding);


always@(*)begin
	case(pi_length)
		2'b00:begin
			if(pi_msb)begin
				so_data = (pi_low)? buffer[15] : buffer[7];
			end
			else begin
				so_data = (pi_low)? buffer[8] : buffer[0];
			end
		end
		2'b01, 2'b10, 2'b11:begin
			if(!start)begin
				so_data = 0;
			end
			else begin
				so_data = (pi_msb)? buffer[15] : buffer[0];
			end
		end
	endcase
	if (last) oem_dataout = 0;
	else oem_dataout = {oem_dataout_buf[6:0], so_data};

	if(counter[2:0] == 3'b000 && counter!=0)begin
		odd1_wr  = (select==0 && even==oem_addr[2])? 1 : 0;
		even1_wr = (select==0 && even!=oem_addr[2])? 1 : 0;
		odd2_wr  = (select==1 && even==oem_addr[2])? 1 : 0;
		even2_wr = (select==1 && even!=oem_addr[2])? 1 : 0;
		odd3_wr  = (select==2 && even==oem_addr[2])? 1 : 0;
		even3_wr = (select==2 && even!=oem_addr[2])? 1 : 0;
		odd4_wr  = (select==3 && even==oem_addr[2])? 1 : 0;
		even4_wr = (select==3 && even!=oem_addr[2])? 1 : 0;
	end
	else begin
		odd1_wr = 0;
		odd2_wr = 0;
		odd3_wr = 0;
		odd4_wr = 0;
		even1_wr = 0;
		even2_wr = 0;
		even3_wr = 0;
		even4_wr = 0;
	end
	
end


always @(posedge clk or posedge reset) begin
	if (reset) begin
		even <= 0;
		last <= 0;
		select <= 0;
		oem_addr <= 0;
		oem_dataout_buf <= 0;
		nowState <= RECEIVE_DATA;
	end
	else begin
		nowState <= nextState;
		case(nowState)
			RECEIVE_DATA:begin
				buffer[15:0] <= pi_data;
				counter <= 0;
				so_valid <= 0;
				if(pi_end) last <= 1;
				oem_finish <= 0;
			end
			SEND_DATA:begin
				if(start)begin
					if (pi_msb) buffer <= {buffer[14:0], 1'b0};
					else buffer <= {1'b0, buffer[15:1]};
				end
				if(counter[2:0] == 3'b000 && counter!=0)begin
					even <= even + 1;
					if(even) begin
						oem_addr <= oem_addr + 1;
						if(oem_addr==31) begin
							if(select==3) begin
								oem_finish <= 1;
							end
							else select <= select + 1;
						end
					end
				end
				counter <= counter + 1;
				oem_dataout_buf <= oem_dataout;
				so_valid <= (counter>max_length)? 0 : 1;
			end
		endcase
	end
end


always@(*)begin
	case(nowState)
		RECEIVE_DATA:begin
			nextState = (load || pi_end)? SEND_DATA : RECEIVE_DATA;
		end
		SEND_DATA:begin
			nextState = (counter==max_length+1)? RECEIVE_DATA : SEND_DATA;
		end
	endcase
end

endmodule