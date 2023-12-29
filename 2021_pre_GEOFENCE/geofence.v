module geofence ( clk,reset,X,Y,R,valid,is_inside);
input clk;
input reset;
input [9:0] X;
input [9:0] Y;
input [10:0] R;
output reg valid;
output reg is_inside;

reg [9:0] x_buffer [5:0];
reg [9:0] y_buffer [5:0];
reg [10:0] r_buffer [5:0];
reg [2:0]  now_index, target_index;

reg [2:0] cr_state, nt_state;



reg [20:0] triangle_area ;
reg [20:0] polygon_area  ;


reg [3:0] step;

integer i ;

/* caculate outer product */

reg [22:0] outer_product;
reg  [ 9:0] c_edge;
wire [10:0] s, s_a, s_b, s_c;


assign s   = (r_buffer[target_index] + r_buffer[target_index-1] + c_edge) >> 1;
assign s_a = s - r_buffer[target_index-1]  ;
assign s_b = s - r_buffer[target_index]    ;
assign s_c = s - c_edge                    ;

reg [10:0] A_vector_x, A_vector_y ;


/* sqrt */
reg  [19:0] sqrt_in_reg;
wire [9:0]  sqrt_out;
DW_sqrt_inst  D1( sqrt_in_reg, sqrt_out);   

/* multiplier */
reg  [10:0] multi_in1;
reg  [10:0] multi_in2;
wire [21:0] multi_out;
assign multi_out = $signed(multi_in1) * $signed(multi_in2);




parameter [2:0] ACCEPT_COORDINATE = 3'd0,
				CAL_OUT_CROSS     = 3'd1,
				SORT_SIX_POINT    = 3'd2,
				CALCULATE_AREA    = 3'd3,
				OUTPUT            = 3'd4,
				DELAY             = 3'd5;



always@(*)begin
	case(cr_state)
		
		CALCULATE_AREA:begin
			if(x_buffer[target_index]>x_buffer[target_index-1])
				A_vector_x = (x_buffer[target_index]) - (x_buffer[target_index-1]) ;
			else 
				A_vector_x = (x_buffer[target_index-1]) - (x_buffer[target_index]) ;

			if(y_buffer[target_index]>y_buffer[target_index-1])
				A_vector_y = (y_buffer[target_index]) - (y_buffer[target_index-1]) ;
			else 
				A_vector_y = (y_buffer[target_index-1]) - (y_buffer[target_index]) ;
		end
		default:begin
			A_vector_x = 11'dx;
			A_vector_y = 11'dx;
		end
	endcase
end




always@(posedge clk or posedge reset) begin
	if (reset) begin
		valid           <= 1'b0 ;
		step            <= 4'd0 ;
		now_index       <= 3'd0 ;
		target_index    <= 3'd4 ;
		triangle_area   <= 22'd0;
		polygon_area    <= 21'd0;
		outer_product   <= 22'd0;
		cr_state        <= ACCEPT_COORDINATE ;
	end
	else begin

		cr_state <= nt_state;

		case(cr_state)

			ACCEPT_COORDINATE:begin   /* use (x_buffer[0], y_buffer[0]) as reference point */
				x_buffer[now_index] <= X;
				y_buffer[now_index] <= Y;
				r_buffer[now_index] <= R;
				now_index <= (now_index==3'd5)? 3'd0 : now_index + 1;  /* next state will start from point 1 */
			end

			CAL_OUT_CROSS:begin
				case(step)
					4'd0:begin
						multi_in1 <= (x_buffer[now_index]) - (x_buffer[0]);
						multi_in2 <= (y_buffer[now_index+1]) - (y_buffer[0]);
					end
					4'd1:begin
						multi_in1 <= (x_buffer[now_index+1]) - (x_buffer[0]);
						multi_in2 <= (y_buffer[now_index]) - (y_buffer[0]);
						outer_product <= multi_out;
					end
					4'd2:begin
 						outer_product <= outer_product - multi_out ;
					end 
				endcase
				step <= (step == 4'd2)? 4'd0 : step +1;
			end

			SORT_SIX_POINT:begin
				if(outer_product[21]==1)begin                       /* outer product result less than zero */
					x_buffer[now_index+1] <= x_buffer[now_index];
					x_buffer[now_index] <= x_buffer[now_index+1];
					y_buffer[now_index+1] <= y_buffer[now_index];
					y_buffer[now_index] <= y_buffer[now_index+1];
					r_buffer[now_index+1] <= r_buffer[now_index];
					r_buffer[now_index] <= r_buffer[now_index+1];
				end
				if(now_index==target_index)begin
					target_index <= (target_index==1)? 1 : target_index -1 ;
					now_index <= 1 ;
				end
				else begin
					now_index <= now_index + 1;
				end
			end

			CALCULATE_AREA:begin  /* caculate five triangle area */
				case(step)
					4'd0:begin
						multi_in1 <= A_vector_x;
						multi_in2 <= A_vector_x;
					end
					4'd1:begin
						multi_in1 <= A_vector_y;
						multi_in2 <= A_vector_y;
						sqrt_in_reg <= multi_out;
					end
					4'd2:begin
						multi_in1 <= x_buffer[target_index-1];
						multi_in2 <= y_buffer[target_index];
						sqrt_in_reg <= sqrt_in_reg + multi_out;
					end
					4'd3:begin
						multi_in1 <= x_buffer[target_index];
						multi_in2 <= y_buffer[target_index-1];
						outer_product <= multi_out;
						c_edge <= sqrt_out;
					end
					4'd4:begin
						outer_product <= (outer_product - multi_out)>>>1;
						multi_in1 <= s;
						multi_in2 <= s_a;
					end
					4'd5:begin
						multi_in1 <= s_b;
						multi_in2 <= s_c;
						sqrt_in_reg <= multi_out;
					end
					4'd6:begin
						sqrt_in_reg <= multi_out;
						multi_in1 <= sqrt_out;					
					end
					4'd7:begin
						multi_in2 <= sqrt_out;
					end
					4'd8:begin
						if(target_index==3'd5)begin
							target_index <= 3'd1;
							x_buffer[0] <= x_buffer[5];
							y_buffer[0] <= y_buffer[5];
							r_buffer[0] <= r_buffer[5];
							x_buffer[1] <= x_buffer[0];
							y_buffer[1] <= y_buffer[0];
							r_buffer[1] <= r_buffer[0];
							now_index <= 1'b0;
						end
						else begin
							target_index <= target_index + 3'd1;
						end
						triangle_area <= triangle_area + multi_out;
						polygon_area  <= ( $signed(polygon_area) + ($signed(outer_product)) );
					end
				endcase
				step <= (step==4'd8)? 4'd0 : step + 1;
			end

			OUTPUT:begin
				valid <= 1'b1;
				is_inside <= (triangle_area > polygon_area)? 1'b0 : 1'b1 ;
				triangle_area <= 21'd0 ;
				polygon_area  <= 21'd0 ;
				target_index  <= 3'd4  ;
			end

			DELAY:begin
				valid <= 1'b0;
				step  <= 4'd0;
			end

		endcase
		
	end
end

always@(*)begin

	case(cr_state)

		
		ACCEPT_COORDINATE:begin
			nt_state = (now_index==3'd5)? SORT_SIX_POINT : ACCEPT_COORDINATE;
		end

		CAL_OUT_CROSS:begin
			nt_state = (step==4'd2)? SORT_SIX_POINT : CAL_OUT_CROSS;
		end

		SORT_SIX_POINT:begin
			nt_state = (now_index==3'd1 && target_index==3'd1)? CALCULATE_AREA : CAL_OUT_CROSS;
		end

		CALCULATE_AREA:begin
			nt_state = (target_index==3'd1 && now_index==3'd0 && step==4'd8)?  OUTPUT : CALCULATE_AREA;
		end

		OUTPUT:begin
			nt_state = DELAY;
		end

		DELAY:begin
			nt_state = ACCEPT_COORDINATE;
		end

		default:begin
			nt_state = ACCEPT_COORDINATE;
		end

	endcase
	
end


endmodule

module DW_sqrt_inst (radicand, square_root);
    parameter radicand_width = 20;
    parameter tc_mode        = 0;
  
    input  [ 19 : 0]       radicand;
    output [  9 : 0]       square_root;
    // Please add +incdir+$SYNOPSYS/dw/sim_ver+ to your verilog simulator 
    // command line (for simulation). 
  
    // instance of DW_sqrt
    DW_sqrt #(radicand_width, tc_mode) 
    U1 (.a(radicand), .root(square_root));
endmodule





