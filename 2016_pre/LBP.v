`timescale 1ns/10ps
module LBP ( clk, reset, gray_addr, gray_req, gray_ready, gray_data, lbp_addr, lbp_valid, lbp_data, finish);
input   	clk;
input   	reset;

// ask data 
output  reg       	gray_req;
output  reg [13:0] 	gray_addr;
input   	    gray_ready;
input   [7:0] 	gray_data;

// write data
output  reg [13:0] 	lbp_addr;
output  reg 	    lbp_valid;
output  reg [7:0] 	lbp_data;
output  reg  	    finish;

reg [7:0] buffer [8:0];
reg [1:0] nowState, nextState;

wire [13:0] minus = gray_addr - 255;
wire [13:0] plus  = gray_addr + 128;
wire valid = (lbp_addr[6:0]== 7'b111_1111 || lbp_addr[6:0]== 7'b000_0000);
wire final = (lbp_addr==14'd16254);

parameter 	S_ACCEPT_DATA1 = 2'd0,
			S_ACCEPT_DATA2 = 2'd1,
			S_ACCEPT_DATA3 = 2'd2,
			S_WRITE_DATA   = 2'd3;


always @(posedge clk or posedge reset) begin
	if (reset) begin
		nowState  <= S_ACCEPT_DATA1;
		gray_addr <= 14'd0;
		lbp_addr  <= 14'd126;
		finish <= 1'b0;
	end
	else begin
		nowState <= nextState;
		gray_req <= 1'b1;
		case(nowState)
			S_ACCEPT_DATA1:begin
				lbp_valid <= 1'b0;
				gray_addr <= plus;
				buffer[2] <= gray_data;     // get 2
			end
			S_ACCEPT_DATA2:begin
				gray_addr <= plus;
				buffer[5] <= gray_data;     // get 130
			end
			S_ACCEPT_DATA3:begin
				gray_addr <= minus;
				buffer[8] <= gray_data;     // get 258
				lbp_addr <= lbp_addr + 1;
			end
			S_WRITE_DATA:begin
				// shift
				lbp_valid <= (valid)? 1'b0 : 1'b1;
				lbp_data[0] <= (buffer[0]>=buffer[4])? 1 : 0;
				lbp_data[1] <= (buffer[1]>=buffer[4])? 1 : 0;
				lbp_data[2] <= (buffer[2]>=buffer[4])? 1 : 0;
				lbp_data[3] <= (buffer[3]>=buffer[4])? 1 : 0;
				lbp_data[4] <= (buffer[5]>=buffer[4])? 1 : 0;
				lbp_data[5] <= (buffer[6]>=buffer[4])? 1 : 0;
				lbp_data[6] <= (buffer[7]>=buffer[4])? 1 : 0;
				lbp_data[7] <= (buffer[8]>=buffer[4])? 1 : 0;

				buffer[0] <= buffer[1];
				buffer[3] <= buffer[4];
				buffer[6] <= buffer[7];
				buffer[1] <= buffer[2];
				buffer[4] <= buffer[5];
				buffer[7] <= buffer[8];
				
				if(final) finish <= 1;
			end
		endcase
	end
end

always@(*)begin
	case(nowState)
			S_ACCEPT_DATA1:begin
				nextState = S_ACCEPT_DATA2;
			end
			S_ACCEPT_DATA2:begin
				nextState = S_ACCEPT_DATA3;
			end
			S_ACCEPT_DATA3:begin
				nextState = S_WRITE_DATA;
			end
			S_WRITE_DATA:begin
				nextState = S_ACCEPT_DATA1;
			end
	endcase
end

endmodule