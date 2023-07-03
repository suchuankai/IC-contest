module SME(clk,reset,chardata,isstring,ispattern,valid,match,match_index);
input clk;
input reset;
input [7:0] chardata;
input isstring;
input ispattern;

output reg       match      ;
output reg [4:0] match_index;
output reg 		 valid      ;

reg       cr_state, nt_state  ;
reg [6:0] str_buffer [31:0]   ;
reg [5:0] str_len             ;
reg [5:0] str_counter		  ;
reg [6:0] pat_buffer [7:0]    ;
reg [3:0] pat_len             ;
reg [3:0] pat_counter         ;

reg flag, str_flag    ;    // First match and first string check.
reg match_back        ;    // Use to control whether str_counter plus, if dot not match, don't plus. 
reg [3:0] star_index  ;    // Store postion if star appear , if no star in pattern it will be zero.

parameter   READ_STRING_PATTERN  = 1'd0 ,			
			STRING_MATCH         = 1'd1 ; 

always @(posedge clk or posedge reset) begin

	if (reset) begin
		match       <= 1'b0 ;
		match_index <= 5'd0 ;
		valid       <= 1'b0 ;
		str_len     <= 6'd0 ;
		str_counter <= 6'd0 ;
		pat_len     <= 4'd0 ;
		pat_counter <= 4'd0 ;
		flag        <= 1'b1 ;
		match_back  <= 1'b0 ;
		star_index  <= 4'd0 ;
		str_flag    <= 1'b1 ;
		cr_state    <= READ_STRING_PATTERN ;
	end

	else begin

		cr_state <= nt_state;

		case(cr_state)

			READ_STRING_PATTERN:begin
				valid  <= 1'b0 ;
				flag   <= 1'b0 ;
				if(isstring) begin     					          // Read String
					str_len <= str_len + 6'd1;
					if(!str_flag) begin
						str_buffer[0] <= chardata;
						str_len <= 6'd1;
						str_flag <= 1'b1;
					end
					else str_buffer[str_len] <= chardata;
				end

				if(ispattern) begin    					          // Read Pattern
					pat_buffer[pat_len] <= chardata;
					pat_len <= pat_len + 4'd1;
					if(chardata==8'd94 || chardata==8'd36)begin   // If charactor is $ or ^ , use a space to replace it. 
						pat_buffer[pat_len] <= 8'd32 ;	
						pat_counter <= 4'd1 ;  // If now is first position, don't add space to it. 
					end
					else begin
						pat_buffer[pat_len] <= chardata;
					end
				end
			end

			STRING_MATCH:begin

				if(ispattern) begin    					          // Read Pattern
					pat_buffer[pat_len] <= chardata;
					pat_len <= pat_len + 4'd1;
					if(chardata==8'd94 || chardata==8'd36)begin   // If charactor is $ or ^ , use a space to replace it. 
						pat_buffer[pat_len] <= 8'd32 ;	
					end
					else begin
						pat_buffer[pat_len] <= chardata;
					end
				end

				case(pat_buffer[pat_counter])

					8'd42:begin  // *
						pat_counter <= (str_buffer[str_counter] == pat_buffer[pat_counter+1])?  pat_counter + 4'd1 : pat_counter ;
						str_counter <= !(str_buffer[str_counter] == pat_buffer[pat_counter+1])? str_counter + 6'd1 : str_counter ;
						star_index <= pat_counter;
						if(!flag) begin  					// First match
							match_index <= str_counter;
							flag        <= 1'b1;
						end	
					end

					8'd46:begin  // .
						if( (pat_buffer[pat_counter]==8'd46) && pat_counter==0) match_back <= 1;
						str_counter <= str_counter + 6'd1 ;
						pat_counter <= pat_counter + 4'd1 ;
						if(!flag) begin  					// First match
							match_index <= str_counter;
							flag        <= 1'b1;
						end	
					end

					default:begin
						if(str_buffer[str_counter] == pat_buffer[pat_counter])begin
							str_counter <= str_counter + 6'd1 ;
							pat_counter <= pat_counter + 4'd1 ;
							if(!flag && str_buffer[str_counter]!=8'd32) begin  					// First match
								match_index <= str_counter;
								flag        <= 1'b1;
							end	
						end
						else begin
							pat_counter <= star_index;
							if(!star_index) flag        <= 1'b0;
							if(!match_back) str_counter <= str_counter + 6'd1;
						end	
					end

				endcase			

				// Termination condition
				// special case is "$" in pattern last character, because use space replace it, it needs to special treatment.
				if((pat_counter==pat_len) || (str_counter==str_len) || ( (pat_counter==pat_len-1) && (str_counter==str_len) ) )begin
					match 		<= ( pat_counter==pat_len || ( (pat_counter==pat_len-1) && (str_counter==str_len) ) )? 1'b1 : 1'b0;
					pat_counter <= 4'd0 ;
					pat_len     <= 4'd0 ;
					str_counter <= 6'd0 ;
					str_flag    <= 1'b0 ;
					flag        <= 1'b1 ;
					match_back  <= 1'b0 ;
					star_index  <= 4'd0 ;
					valid       <= 1'b1 ;
				end
			end

		endcase
		
	end
end


always@(*)begin   //Next state logic
	
	case(cr_state)

		READ_STRING_PATTERN:begin
			nt_state = (pat_len==4'd1)? STRING_MATCH : READ_STRING_PATTERN;
		end

		STRING_MATCH:begin
			nt_state = ( (pat_counter==pat_len) || (str_counter==str_len) || ( (pat_counter==pat_len-1)&& (str_counter==str_len) ) )? READ_STRING_PATTERN : STRING_MATCH;
		end

	endcase

end

endmodule