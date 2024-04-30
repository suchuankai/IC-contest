module Bicubic (
	input CLK,
	input RST,
	input [6:0] V0,
	input [6:0] H0,
	input [4:0] SW,
	input [4:0] SH,
	input [5:0] TW,
	input [5:0] TH,
	output reg DONE
				);


// ROM
wire [7:0] ROM_out;
wire ROM_en = 1'b0;
reg [13:0] ROM_addr;


// SRAM
wire [7:0] SRAM_out;   // SRAM output
reg SRAM_en;              
reg [13:0] SRAM_addr;  
reg [7:0] SRAM_in;


// State
reg [2:0] crState, ntState;
parameter INIT     = 3'd0,
          READ_16  = 3'd1,
          CACULATE = 3'd2,
          UPDATE   = 3'd3,
          FINISH   = 3'd4;


// Boundary
wire [9:0] maxRight  = (SW-1)*(TW-1);
wire [9:0] maxBottom = (SH-1)*(TH-1);


// Address & Buffer
reg [13:0] ntStartAddr;
wire [13:0] StartAddr = (H0-1) + (V0-1)*100;
reg [9:0] Px, Py, Qx, Qy;
reg [10:0] rightBound, bottomBound; 
wire shiftRight = ((Qx+(SW-1)) >= rightBound);
wire shiftDown  = ((Qy+(SH-1)) >= bottomBound);
wire atMaxRight = (Qx == maxRight);

reg [6:0] xChild, xMom; 
wire [15:0] x;
assign x = {xChild, 16'd0} / xMom;   // Result is 16 bit decimal


// Bicubic
reg [8:0] buffer [0:15];   // Add 1 bit for sign bit
reg [7:0] hor_buf[0:3];
reg  signed [8:0] p_minus1, p_zero, p_add1, p_add2;
wire signed [11:0] a = -p_minus1   + p_zero*3 - p_add1*3 + p_add2;  // bit 0 is decimal
wire signed [11:0] b =  p_minus1*2 - p_zero*5 + p_add1*4 - p_add2;  // bit 0 is decimal
wire signed [9:0]  c = -p_minus1   + p_add1;                        // bit 0 is decimal
wire signed [8:0]  d =  p_zero;                                     // no decimal

wire signed [61:0] a_x3 = $signed(a)*$signed({1'b0,x})*$signed({1'b0,x})*$signed({1'b0,x});  // 0~48 is decimal
wire signed [44:0] b_x2 = $signed(b)*$signed({1'b0,x})*$signed({1'b0,x});                    // 0~32 is decimal
wire signed [27:0] c_x  = $signed(c)*$signed({1'b0,x});                                      // 0~16 is decimal
wire signed [66:0] p_x  = $signed(a_x3) + $signed({b_x2,16'd0}) + $signed({c_x,32'd0}) + $signed({d,49'd0});  

// Others
integer i;
reg [4:0] cnt;
reg [7:0] round;
reg skip;


ImgROM u_ImgROM (.Q(ROM_out), .CLK(CLK), .CEN(ROM_en), .A(ROM_addr));
ResultSRAM u_ResultSRAM (.Q(SRAM_out), .CLK(CLK), .CEN(SRAM_en), .WEN(1'b0), .A(SRAM_addr), .D(SRAM_in));


// Select Bicubic four input and x
always@(*) begin
	case(cnt)
		0: begin
			p_minus1 = buffer[0];
			p_zero   = buffer[4];
			p_add1   = buffer[8];
			p_add2   = buffer[12];
			xChild   = Qx - (rightBound-(TW-1)); 
			xMom     = TW-1;
		end
		1: begin
			p_minus1 = buffer[1];
			p_zero   = buffer[5];
			p_add1   = buffer[9];
			p_add2   = buffer[13];
			xChild   = Qx - (rightBound-(TW-1)); 
			xMom     = TW-1;
		end
		2: begin
			p_minus1 = buffer[2];
			p_zero   = buffer[6];
			p_add1   = buffer[10];
			p_add2   = buffer[14];
			xChild   = Qx - (rightBound-(TW-1)); 
			xMom     = TW-1;
		end
		3: begin
			p_minus1 = buffer[3];
			p_zero   = buffer[7];
			p_add1   = buffer[11];
			p_add2   = buffer[15];
			xChild   = Qx - (rightBound-(TW-1)); 
			xMom     = TW-1;
		end
		default: begin
			p_minus1 = hor_buf[0];
			p_zero   = hor_buf[1];
			p_add1   = hor_buf[2];
			p_add2   = hor_buf[3];
			xChild   = Qy - (bottomBound-TH+1);
			xMom     = TH-1;
		end
	endcase
end


// Rounding
always@(*) begin
	if(p_x < 0)
		round = 8'd0;
	else if(p_x[58:49] == 8'd255) 
		round = 8'd255;
	else
		round = p_x[56:49] + p_x[48];
end


always@(posedge CLK) begin
	if(RST) begin
		ROM_addr <= 14'd0;
		ntStartAddr <= 14'd0;
	end
	else begin
		case(crState)
			INIT: begin
				ROM_addr <= StartAddr;
				ntStartAddr <= StartAddr;
			end
			READ_16: begin
				buffer[cnt-1] <= {1'b0,ROM_out};
				if(cnt < 5'd16)
					ROM_addr <= (cnt[1:0]==2'b11)? ROM_addr-299 : ROM_addr+100;
			end
			CACULATE:begin
				hor_buf[cnt] <= round;
			end
			UPDATE: begin
				SRAM_in <= round;
				if(atMaxRight) begin
					if(shiftDown) begin
						ROM_addr <= ntStartAddr + 100;
						ntStartAddr <= ntStartAddr + 100;
					end
					else ROM_addr <= ntStartAddr;
				end
				else if(shiftRight) begin  // Buffer shift
					for(i = 0; i<=11; i=i+1) begin
						buffer[i] <= buffer[i+4];
					end
					ROM_addr <= ROM_addr+100;
				end
			end
		endcase
	end
end


// Count 
always@(posedge CLK) begin
	if(RST) begin
		cnt <= 5'd0;
	end
	else begin
		case(crState)
			INIT: begin
				cnt <= 5'd0;
			end
			READ_16: begin
				if(cnt==5'd16) begin
					cnt <= (skip)? 5'd1 : 5'd0;
				end
				else cnt <= cnt + 1;
			end
			CACULATE: begin
				cnt <= cnt + 1;
			end
			UPDATE: begin
				if(atMaxRight) 
					cnt <= 5'd0;
				else if(shiftRight)
					cnt <= 5'd13;
				else 
					cnt <= 5'd0;
			end
		endcase
	end
end


// Address Control
always@(posedge CLK) begin
	case(crState)
		INIT: begin
			Px <= 10'd0;
			Py <= 10'd0;
			Qx <= 10'd0;
			Qy <= 10'd0;
			SRAM_addr <= 14'b11_1111_1111_1111;
			rightBound  <= TW - 1;
			bottomBound <= TH - 1;
			SRAM_en <= 1'b1;
		end
		UPDATE: begin
			if(atMaxRight) begin   // Arrive right bound
				if(shiftDown) begin
					Py <= Py + (TH-1);
					bottomBound <= bottomBound + (TH-1);
				end
				Px <= 10'd0;
				Qx <= 10'd0;
				Qy <= Qy + (SH-1);
				rightBound  <= TW - 1;
			end
			else if(shiftRight) begin
				Px <= Px + (TW-1);
				Qx <= Qx + (SW-1);
				rightBound <= rightBound + (TW-1);
			end
			else Qx <= Qx + (SW-1);
			SRAM_addr <= SRAM_addr + 1;
			SRAM_en <= 1'b0;
		end
	endcase
end


always@(posedge CLK) begin
	if(RST) begin
		crState <= INIT;
	end
	else begin
		crState <= ntState;
	end
end


// Finish signal
always@(posedge CLK) begin
	if(RST) begin
		DONE <= 1'b0;
	end
	else begin
		DONE <= (crState == FINISH)? 1'b1 : 1'b0;
	end
end


// Finish signal
always@(posedge CLK) begin
	if(RST) begin
		skip <= 1'b0;
	end
	else begin
		skip <= (Py == Qy)? 1'b1 : 1'b0;
	end
end


// Next state logic
always@(*) begin
	case(crState)
		INIT: begin
			ntState = READ_16;   // ROM needs two cycles to get value.
		end
		READ_16:begin
			if(cnt==5'd16) begin
				if(skip) ntState = UPDATE;
				else ntState = CACULATE;
			end
			else ntState = READ_16;
		end
		CACULATE:begin
			ntState = (cnt==5'd3)? UPDATE : CACULATE;
		end
		UPDATE: begin
			if(SRAM_addr==((TW*TH)-1)) begin
				ntState = FINISH;
			end
			else ntState = (atMaxRight || shiftRight)? READ_16 : CACULATE;
		end
		FINISH: begin
			ntState = (DONE==1)? INIT : FINISH;
		end
		default: begin
			ntState = 'hx;
		end
	endcase
end

endmodule


