module DT(
	input 			clk, 
	input			reset,
	output	reg		done ,

	// Read from ROM
	output	reg		sti_rd ,
	output	reg 	[9:0]	sti_addr,  // 0 ~ 1023
	input			[15:0]	sti_di,

	// Write / READ RAM 
	output	reg		res_wr ,
	output	reg		res_rd ,
	output	reg 	[13:0]	res_addr,
	output	reg 	[7:0]	res_do,
	input			[7:0]	res_di
	);



reg [1:0] nowState, nextState;
reg [2:0] step;
reg [15:0] sti_di_buf;

assign checkBit  = sti_di_buf[15];
assign checkBitB = sti_di_buf[0] ;

parameter CHECK_ZERO   = 2'd0,
		  FIND_ZERO    = 2'd1,
		  CHECK_ZERO_B = 2'd2,
		  FIND_ZERO_B  = 2'd3;

always @(posedge clk or negedge reset) begin
	if (!reset) begin
		done <= 0;
		sti_rd <= 1;
		sti_addr <= 10'd8;
		nowState <= CHECK_ZERO;
	end
	else begin
		nowState <= nextState;
		case(nowState)
			CHECK_ZERO:begin
				res_wr <= 0;
				sti_di_buf <= sti_di;
				sti_addr <= sti_addr + 1;
				res_rd <= 1;   // ask first data
				sti_rd <= 1;
				res_addr <= ((sti_addr) << 4) -1;
				step <= 3'd0;
			end
			FIND_ZERO:begin
				if(checkBit==0)begin   // Background
					sti_di_buf <= {sti_di_buf[14:0], 1'b0};
					res_addr <= res_addr + 1;
				end
				else begin
					case(step)
						3'd0:begin   // get first data, ask second data
							res_addr <= res_addr - 128;
							res_do <= res_di+1;
						end
						3'd1:begin   // get second data, ask third data
							res_addr <= res_addr + 1;
						end
						3'd2:begin   // get third data, ask forth data
							res_addr <= res_addr + 1;
						end
						3'd3:begin   // get forth data, save
							res_addr <= res_addr + 127;
							res_wr <= 1;
						end
						3'd4:begin   
							res_wr <= 0;
							sti_di_buf <= {sti_di_buf[14:0], 1'b0};
						end
					endcase
				    if (( (res_di+1) < res_do ) && step>0 )
						res_do <= res_di+1;
					step <= (step==4)? 0: step +1;
				end
			end
			CHECK_ZERO_B:begin
				res_wr <= 0;
				sti_di_buf <= sti_di;
				sti_addr <= sti_addr - 1;
				res_rd <= 1;   // ask first data
				res_addr <= ((sti_addr) << 4) + 15;
				if(sti_addr==8) done <= 1;
			end
			FIND_ZERO_B:begin
				if(checkBitB ==0 || (res_di==1 && step==0) ) begin   // Background or special case
					sti_di_buf <= {1'b0, sti_di_buf[15:1]};
					res_addr <= res_addr - 1;
				end
				else begin  
					case(step)
						3'd0:begin   // get first data, ask second data
							res_addr <= res_addr + 1;
							res_do <= res_di;
						end
						3'd1:begin   // get second data, ask third data
							res_addr <= res_addr + 128;
						end
						3'd2:begin   // get third data, ask forth data
							res_addr <= res_addr - 1;
						end
						3'd3:begin   // get forth data, ask fifth data
							res_addr <= res_addr - 1;
						end
						3'd4:begin   // get fifth data, save
							res_addr <= res_addr - 127;
							res_wr <= 1;
						end
						3'd5:begin   // reset
							res_wr <= 0;
							res_addr <= res_addr - 1;
							sti_di_buf <= {1'b0, sti_di_buf[15:1]};
						end
					endcase
				    if( (res_di+1) < res_do )
						res_do <= res_di+1;
					step <= (step==5)? 0: step +1;
				end
			end
		endcase		
	end
end



always@(*)begin
	case(nowState) 
		CHECK_ZERO:begin
			if(sti_addr == 1016) nextState = CHECK_ZERO_B;
			else nextState = (sti_di == 16'd0)? CHECK_ZERO : FIND_ZERO ;
		end
		FIND_ZERO:begin
			nextState = (sti_di_buf==16'd0)? CHECK_ZERO : FIND_ZERO;
		end
		CHECK_ZERO_B:begin
			nextState = (sti_di == 16'd0)? CHECK_ZERO_B : FIND_ZERO_B ;
		end
		FIND_ZERO_B:begin
			nextState = (sti_di_buf==16'd0)? CHECK_ZERO_B : FIND_ZERO_B;
		end
	endcase
end

endmodule