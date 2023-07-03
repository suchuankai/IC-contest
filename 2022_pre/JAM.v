module JAM (
input CLK,
input RST,
output reg [2:0] W,
output reg [2:0] J,
input [6:0] Cost,
output reg [3:0] MatchCount,
output reg [9:0] MinCost,
output reg Valid );

reg cr_state,nt_state;
reg [2:0] number[7:0] , nt_number [7:0];      //目前要資料這組的數字
reg [2:0] index,step,min_index;
reg [2:0] replacement_index,replacement_back_index;

reg [9:0] sum;
reg [3:0] min_num;   //注意!
reg flag,flag2;
parameter  ask_sort   = 1'd0,
		   check_flip = 1'd1;
 


always@(posedge CLK or posedge RST) begin
	if (RST) begin
		W          <= 3'd0  ;
		J          <= 3'd0  ;
		MatchCount <= 4'd0  ;
		MinCost    <= 10'd0 ;
		Valid      <= 0     ;

		number[0]  <= 3'd7  ;
		number[1]  <= 3'd6  ;
		number[2]  <= 3'd5  ;
		number[3]  <= 3'd4  ;
		number[4]  <= 3'd3  ;
		number[5]  <= 3'd2  ;
		number[6]  <= 3'd1  ;
		number[7]  <= 3'd0  ;

		nt_number[0]  <= 3'd7  ;
		nt_number[1]  <= 3'd6  ;
		nt_number[2]  <= 3'd5  ;
		nt_number[3]  <= 3'd4  ;
		nt_number[4]  <= 3'd3  ;
		nt_number[5]  <= 3'd2  ;
		nt_number[6]  <= 3'd1  ;
		nt_number[7]  <= 3'd0  ;

		index <= 3'd0  ;
		step  <= 0;
		replacement_index <= 3'd0;
		MinCost <= 800;
		min_num <= 7;
		sum   <= 10'd0 ;
		flag  <= 0;
		flag2 <= 0;

		cr_state   <= ask_sort;
	end
	else begin

		cr_state <= nt_state;
		
		case(cr_state)

			ask_sort:begin

				//ask data (need 9 cycle) 
				if(W==0)begin
					flag <= 1;
				end
				else begin
					W <= W-1;
					index <= index +1;
				end

				J <= number[index];
				
				if( W<7)
					sum <= sum + Cost;


				//sort (worst case need 8 cycle)
				case(step)

					/*  first step: find the replace number  */
					0:begin  // (one cycle)
						if(nt_number[0]>nt_number[1])begin
							replacement_index <= 1;
							replacement_back_index <= 0;
						end
						else if(nt_number[1]>nt_number[2])begin
							replacement_index <= 2;
							replacement_back_index <= 1;
						end
						else if(nt_number[2]>nt_number[3])begin
							replacement_index <= 3;
							replacement_back_index <= 2;
						end
						else if(nt_number[3]>nt_number[4])begin
							replacement_index <= 4;
							replacement_back_index <= 3;
						end
						else if(nt_number[4]>nt_number[5])begin
							replacement_index <= 5;
							replacement_back_index <= 4;
						end
						else if(nt_number[5]>nt_number[6])begin
							replacement_index <= 6;
							replacement_back_index <= 5;
						end
						else begin
							replacement_index <= 7;
							replacement_back_index <= 6;
						end
						step <= step + 1;
					end

					/*  Second step: find the second replace number  */
					1:begin  //min_num need to reset   (worst case need six cycle)
						if( (nt_number[replacement_back_index]>nt_number[replacement_index]) && (nt_number[replacement_back_index] <= min_num) ) begin     
							min_num   <= nt_number[replacement_back_index];
							min_index <= replacement_back_index;
						end			
						if(replacement_back_index==0)begin
							step <= step + 1;
						end
						else begin
							replacement_back_index <= replacement_back_index -1;
						end
					end

					/*  Third step: Change the number  */ 
					2:begin  // (one cycle)
						nt_number[replacement_index] <= nt_number[min_index] ;
						nt_number[min_index] <= nt_number[replacement_index] ;
						min_num <= 7; //Rest min_num
						step <= step + 1;
					end

					/*  forth  step: Change the number  */ 
					3:begin // change others  (one cycle)
						case(replacement_index>>1)

							3'd1:begin   //(replacement_num_index= 2 or 3)
								nt_number[0] <= nt_number[replacement_index-1];
								nt_number[replacement_index-1] <= nt_number[0];
							end
							3'd2:begin   //(replacement_num_index= 4 or 5)
								nt_number[0] <= nt_number[replacement_index-1];
								nt_number[replacement_index-1] <= nt_number[0];
								nt_number[1] <= nt_number[replacement_index-2];
								nt_number[replacement_index-2] <= nt_number[1];
							end
							3'd3:begin   //(replacement_num_index= 6 or 7)
								nt_number[0] <= nt_number[replacement_index-1];
								nt_number[replacement_index-1] <= nt_number[0];
								nt_number[1] <= nt_number[replacement_index-2];
								nt_number[replacement_index-2] <= nt_number[1];
								nt_number[2] <= nt_number[replacement_index-3];
								nt_number[replacement_index-3] <= nt_number[2];
							end
					
						endcase
						step <= step +1;
					end

					4:begin
						flag2 <= 1;
					end
					
				endcase
			end

			check_flip:begin
				if(sum==MinCost) begin
		    		MatchCount <= MatchCount+1;
		    	end
		    	else if(sum<MinCost)begin
		    		MatchCount <= 1;
		    		MinCost <= sum;
		    	end
		    	sum   <= 0;
		    	step  <= 0;
		    	flag  <= 0;
		    	flag2 <= 0;
		    	index <= 1;
		    	W     <= 7;


		    	number[0]  <= nt_number[0] ;
				number[1]  <= nt_number[1] ;
				number[2]  <= nt_number[2] ;
				number[3]  <= nt_number[3] ;
				number[4]  <= nt_number[4] ;
				number[5]  <= nt_number[5] ;
				number[6]  <= nt_number[6] ;
				number[7]  <= nt_number[7] ;

				J <= nt_number[0];
				if(number[7]==7 && number[6]==6 && number[5]==5 && number[4]==4 && number[3]==3 && number[2]==2 && number[1]==1 ) Valid <= 1;
			end


		endcase

	end
end

always@(*)begin

	case(cr_state)
		ask_sort:begin
			nt_state = (flag && flag2)? check_flip : ask_sort;
		end
		check_flip:begin
			nt_state = ask_sort;
		end
	endcase

end


endmodule


