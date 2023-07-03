`timescale 1ns/10ps

module  CONV(
	input		clk,
	input		reset,
	output	reg	busy,	
	input		ready,	
			
	output  reg	[11:0]	iaddr,
	input		[19:0]	idata,	    // 4 bit integer + 16 bit decimal
	
	output	reg 		cwr,		// write signal
	output  reg	[11:0]	caddr_wr,
	output  reg	[19:0] 	cdata_wr,
	
	output	reg 		crd,        // read signal
	output  reg	[11:0] 	caddr_rd,
	input		[19:0] 	cdata_rd,
	
	output reg	[2:0] 	csel
	);


reg [2:0]  cr_state, nt_state;
reg [3:0]  cnt;
reg maxpool_se; 
reg signed [35:0] cdata_wr_buf;

wire signed [19:0] kernal1 [8:0];
wire signed [19:0] kernal2 [8:0];

assign kernal1[0] = 20'h0A89E ; assign kernal1[3] = 20'h092D5 ; assign kernal1[6] = 20'h06D43 ; 
assign kernal1[1] = 20'h01004 ; assign kernal1[4] = 20'hF8F71 ; assign kernal1[7] = 20'hF6E54 ; 
assign kernal1[2] = 20'hFA6D7 ; assign kernal1[5] = 20'hFC834 ; assign kernal1[8] = 20'hFAC19 ; 

assign kernal2[0] = 20'hFDB55 ; assign kernal2[3] = 20'h02992 ; assign kernal2[6] = 20'hFC994 ; 
assign kernal2[1] = 20'h050FD ; assign kernal2[4] = 20'h02F20 ; assign kernal2[7] = 20'h0202D ; 
assign kernal2[2] = 20'h03BD7 ; assign kernal2[5] = 20'hFD369 ; assign kernal2[8] = 20'h05E68 ; 


parameter signed [19:0] bias0 = 20'h01310;
parameter signed [19:0] bias1 = 20'hF7295;

// Padding check
wire padding;
assign padding = ( ( caddr_wr[11:6] ==6'b00_0000 && (cnt==4'd0 || cnt==4'd3 || cnt==4'd6) ) ||        // Top padding
				   ( caddr_wr[5:0]  ==6'b00_0000 && (cnt==4'd0 || cnt==4'd1 || cnt==4'd2) ) ||        // Left padding
				   ( caddr_wr[11:6] ==6'b11_1111 && (cnt==4'd2 || cnt==4'd5 || cnt==4'd8) ) ||        // Down padding
				   ( caddr_wr[5:0]  ==6'b11_1111 && (cnt==4'd6 || cnt==4'd7 || cnt==4'd8) ) );        // Right padding

// MUL
reg  signed [19:0] mulin1, mulin2;    // mulin1 is kernal, mulin2 is idata
wire signed [35:0] mul_result;
assign mul_result = (mulin1) * (mulin2);

wire [11:0] addr_plus  = iaddr + 64;
wire [11:0] addr_minus = iaddr - 127;
wire roundBit = cdata_wr_buf[15];

wire [11:0] caddr_plus  = caddr_rd + 64; 
wire [11:0] caddr_minus = caddr_rd - 63; 

parameter [3:0] IDLE          = 3'd0,
				CONV          = 3'd1,
				ROUNDING      = 3'd2,
				WRITE_CONV    = 3'd3,
				MAXPOOL       = 3'd4,
				WRITE_MAXPOOL = 3'd5,
				WRITE_FLATTEN = 3'd6,
				RESET         = 3'd7;
				
always @(posedge clk or posedge reset) begin
	if (reset) begin
		cwr <= 0;
		busy <= 0;
		csel <= 1;
		maxpool_se <= 0;
		caddr_wr <= 12'd0;
		caddr_rd <= 12'd0;
		cr_state <= IDLE;
	end
	else begin
		crd <= 1;
		cr_state <= nt_state;

		case(cr_state)
			IDLE:begin
				cnt <= 4'd4;
				busy <= 1'b1;
				iaddr <= 12'd0;
				mulin1 <= 0;
				mulin2 <= 0;
				cdata_wr_buf <= bias0<<16;
			end
			CONV:begin
				cwr <= 0;
				case(cnt)
					4'd0: iaddr <= addr_plus;
					4'd1: iaddr <= addr_plus;
					4'd2: iaddr <= addr_minus;
					4'd3: iaddr <= addr_plus;
					4'd4: iaddr <= addr_plus;
					4'd5: iaddr <= addr_minus;
					4'd6: iaddr <= addr_plus;
					4'd7: iaddr <= addr_plus;
					4'd8: iaddr <= addr_minus;
				endcase

				if(cnt<9) mulin1 <= (csel==3'd1)? kernal1[cnt] : kernal2[cnt];
				mulin2 <= (padding)? 12'd0 : idata;
				
				cnt <= (cnt==4'd9)? 4'd0 : cnt + 1;

				if(cnt==0) begin
					cdata_wr_buf <= (csel==1)? bias0<<16 : bias1<<16;
				end
				else begin
					cdata_wr_buf <= cdata_wr_buf + mul_result;
				end
			end
			ROUNDING:begin   // round and WRITE_CONV result
				cwr <= 1;
				iaddr <= iaddr -2;
				cdata_wr <= (cdata_wr_buf[35]==1)? 0 : cdata_wr_buf[35:16] + roundBit;
			end
			WRITE_CONV:begin
				cwr <= 0;
				caddr_wr <= caddr_wr + 1;
				if(caddr_wr==12'd4095) begin
					if(csel==1) csel <= 2;
					else csel <= 1;
				end	
			end
			MAXPOOL:begin  //
				case(cnt)
					4'd0: caddr_rd <= caddr_plus;
					4'd1: caddr_rd <= caddr_minus;
					4'd2: caddr_rd <= caddr_plus;
					4'd3: caddr_rd <= caddr_minus;
				endcase
				cnt <= cnt + 1;
				cdata_wr <= (cdata_wr>cdata_rd)? cdata_wr : cdata_rd;
				if (caddr_wr==1024 && maxpool_se) busy <= 0;
				if(caddr_wr==1024) begin
					maxpool_se <= 1;
					csel <= 2;
					caddr_wr <= 0;
				end 
			end
			WRITE_MAXPOOL:begin
				cwr <= 1;
				cnt <= 4'd0;
				csel <= (maxpool_se)? 4 : 3;
				if(caddr_rd[5:0]==6'b00_0000) caddr_rd <= caddr_plus;
			end
			WRITE_FLATTEN:begin
				csel <= 5;
				caddr_wr <= (maxpool_se)? (caddr_wr<<1)+1 : caddr_wr<<1;
			end
			RESET:begin
				cwr <= 0;
				csel <= (maxpool_se)? 2 : 1;
				cdata_wr <= 0;
				caddr_wr <= (maxpool_se)? ((caddr_wr-1)>>1) + 1 :(caddr_wr>>1) + 1;
			end
		endcase
	end
end

always@(*)begin
	case(cr_state)
		IDLE:begin
			nt_state = (!ready)? CONV : IDLE;
		end
		CONV:begin
			nt_state = (cnt==4'd9)? ROUNDING : CONV;
		end
		ROUNDING:begin
			nt_state = WRITE_CONV;
		end
		WRITE_CONV:begin
			nt_state = (caddr_wr==4095 && csel==2)? MAXPOOL : CONV;
		end
		MAXPOOL:begin
			nt_state = (cnt==3)? WRITE_MAXPOOL : MAXPOOL;
		end
		WRITE_MAXPOOL:begin
			nt_state = WRITE_FLATTEN;
		end
		WRITE_FLATTEN:begin
			nt_state = RESET;
		end
		RESET:begin
			nt_state = MAXPOOL;
		end
	endcase
end

endmodule