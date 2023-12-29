module SET ( clk , rst, en, central, radius, mode, busy, valid, candidate );

input clk, rst;
input en;
input [23:0] central;
input [11:0] radius;
input [1:0] mode;
output reg busy;
output reg valid;
output reg [7:0] candidate;

reg [2:0] nowState, nextState;
reg [3:0] nowX, nowY;

parameter ACCEPT_DATA   = 3'd0,
		  IN_1          = 3'd1,
		  IN_2          = 3'd2,
		  IN_3          = 3'd3,
		  IN_4          = 3'd4,
		  RESULT        = 3'd5,
		  BUFFER        = 3'd6;

reg  [3:0] Tx, Ty, Tr;
wire [7:0] part1 = (nowX-Tx);
wire [7:0] part2 = (nowY-Ty);
wire [7:0] distance = part1*part1 + part2*part2;
wire [7:0] RaSquare =  Tr * Tr;
 
wire In_en = (RaSquare>=distance);
reg InA, InB;

always@(posedge clk or posedge rst) begin
	if(rst)begin
		busy <= 0;
		nowX <= 1;
		nowY <= 1;
		valid <= 0;
		nowState <= ACCEPT_DATA;
	end
	else begin
		nowState <= nextState;
		case(nowState)
			ACCEPT_DATA:begin
				busy <= 1;
				valid <= 0;
				candidate <= 0;
			end
			IN_1:begin
				Tx <= central[23:20];
				Ty <= central[19:16];
				Tr <= radius [11:8 ];
			end
			IN_2:begin
				Tx <= central[15:12];
				Ty <= central[11:8 ];
				Tr <= radius [7 :4 ];
				InA <= In_en;
			end
			IN_3:begin
				Tx <= central[7 :4 ];
				Ty <= central[3 :0 ];
				Tr <= radius [3 :0 ];
				InB <= In_en;
			end
		    RESULT:begin
		    	if(nowX==8)begin
		    		nowX <= 1;
		    		nowY <= (nowY==8)? 1 : nowY + 1;
		    	end
		    	else begin
		    		nowX <= nowX + 1;
		    	end
		    	case(mode)
		    		2'b00: if(InA) candidate <= candidate + 1;
					2'b01: if(InA&&InB) candidate <= candidate + 1;
					2'b10: if( (InA||InB) && !(InA&&InB)) candidate <= candidate + 1;
					2'b11: if( ( (InA&&InB) || (InA&&In_en) || (InB&&In_en)) && !(InA&&InB&&In_en)) candidate <= candidate + 1;
		    	endcase
		    	if(nowY==8 && nowX==8)begin
		    		valid <= 1;
		    		busy <= 0;
		    	end
		    end
		    BUFFER:begin
		    	InA <= 0;
		    	InB <= 0;
		    end
		endcase
	end
end

always@(*) begin
	case(nowState)
		ACCEPT_DATA:begin
			nextState = IN_1;
		end
		IN_1:begin
			nextState = IN_2;
		end
		IN_2:begin
			nextState = IN_3;
		end
		IN_3:begin
			nextState = RESULT;
		end
	    RESULT:begin
	    	nextState = (nowY==8 && nowX==8)? BUFFER : IN_1;
	    end
	    BUFFER:begin
	    	nextState = ACCEPT_DATA;
	    end
	    default:begin
	    	nextState = 'hx;
	    end
	endcase	
end

endmodule