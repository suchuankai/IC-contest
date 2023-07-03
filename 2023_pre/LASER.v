module LASER (
input CLK,
input RST,
input [3:0] X,
input [3:0] Y,
output reg [3:0] C1X,
output reg [3:0] C1Y,
output reg [3:0] C2X,
output reg [3:0] C2Y,
output reg DONE);


reg [3:0] curr_state, next_state;
reg [5:0] counter;

reg [3:0] posistion_x [39:0];
reg [3:0] posistion_y [39:0];

reg [3:0] circle_x, circle_y;
reg [3:0] iter_x, iter_y;
 
reg [5:0] in_circle;
reg [5:0] max_in1, max_in2;

reg [3:0] old_x, old_y;
reg [3:0] temp_x, temp_y;
 

parameter ACCEPT_DATA  = 4'd0,
		  CIRCLE_1     = 4'd1,
		  MAX_CIRCLE1  = 4'd2,
		  CIRCLE_2     = 4'd3,  
		  MAX_CIRCLE2  = 4'd4,
		  DEFINE_BOND1 = 4'd5,
		  ITERATE_C1   = 4'd6,
		  MAX_C1       = 4'd7,
		  DEFINE_BOND2 = 4'd8,
		  ITERATE_C2   = 4'd9,
		  MAX_C2       = 4'd10,
		  FINISH       = 4'd11,
		  STALL        = 4'd12;

reg [3:0] r1, r2, r3, r4, r5, r6, r7, r8;
reg In1, InC, In2, InC2;


always@(*)begin
	if(posistion_x[counter]>circle_x) r1 = posistion_x[counter]-circle_x;
	else  r1 = circle_x - posistion_x[counter];
	if(posistion_y[counter]>circle_y) r2 = posistion_y[counter]-circle_y;
	else  r2 = circle_y - posistion_y[counter];

	if(posistion_x[counter]>temp_x) r3 = posistion_x[counter]-temp_x;
	else  r3 = temp_x - posistion_x[counter];
	if(posistion_y[counter]>temp_y) r4 = posistion_y[counter]-temp_y;
	else  r4 = temp_y - posistion_y[counter];

	if(posistion_x[counter+1]>circle_x) r5 = posistion_x[counter+1]-circle_x;
	else  r5 = circle_x - posistion_x[counter+1];
	if(posistion_y[counter+1]>circle_y) r6 = posistion_y[counter+1]-circle_y;
	else  r6 = circle_y - posistion_y[counter+1];

	if(posistion_x[counter+1]>temp_x) r7 = posistion_x[counter+1]-temp_x;
	else  r7 = temp_x - posistion_x[counter+1];
	if(posistion_y[counter+1]>temp_y) r8 = posistion_y[counter+1]-temp_y;
	else  r8 = temp_y - posistion_y[counter+1];

	In1 =  (r1*r1 + r2*r2) <= 16;
	InC =  (r3*r3 + r4*r4) <= 16;
	In2 =  (r5*r5 + r6*r6) <= 16;
	InC2 = (r7*r7 + r8*r8) <= 16;
end

always @(posedge CLK or posedge RST) begin
	if (RST) begin
		curr_state <= ACCEPT_DATA;
		DONE <= 0;

		circle_x <= 0;
		circle_y <= 0;
		counter <= 0;
		max_in1 <= 0;
		max_in2 <= 0;
		in_circle <= 0;

		C2X <= 0;
		C2Y <= 0;
		C1X <= 0;
		C1Y <= 0;
		old_x <= 0;
		old_y <= 0;
		temp_x <= 0;
		temp_y <= 0;
	end
	else begin
		curr_state <= next_state;
		case(curr_state)
			ACCEPT_DATA:begin
				posistion_x[counter] <= X;
				posistion_y[counter] <= Y;
				counter <= (counter==39)? 0 : counter +1;
				DONE <= 0;
			end
			CIRCLE_1:begin
				in_circle <= in_circle + In1;
				counter <= (counter==39)? 0 : counter +3;
			end
			MAX_CIRCLE1:begin
				if(in_circle >= max_in1)begin
					max_in1 <= in_circle  ;
					C1X <= circle_x ;
					C1Y <= circle_y ;
					temp_x <= circle_x ;
					temp_y <= circle_y ;
				end
				if(circle_x==15) begin
					circle_x <= 0;
					if(circle_y==15) circle_y <= 0;
					else circle_y <= circle_y + 3;
				end
				else circle_x <= circle_x + 3;
				in_circle <= 0;
			end
			CIRCLE_2:begin 
				in_circle <= in_circle + (In1 && !InC);
				counter <= (counter==39)? 0 : counter +3;
			end
			MAX_CIRCLE2:begin
				if(in_circle >= max_in2)begin
					max_in2 <= in_circle  ;
					C2X <= circle_x ;
					C2Y <= circle_y ;
				end
				if(circle_x==15) begin
					circle_x <= 0;
					circle_y <= circle_y + 3;
				end
				else circle_x <= circle_x + 3;
				in_circle <= 0;
			end
			DEFINE_BOND1:begin
				circle_x <= C1X - 1;
				circle_y <= C1Y - 3;
				iter_x <= C1X + 2;
				iter_y <= C1Y + 2;
				max_in1 <= 0;
				old_x <= C1X;
				old_y <= C1Y; 
				temp_x <= C2X ;
				temp_y <= C2Y ;
			end
			ITERATE_C1:begin
				in_circle <= in_circle + (In1 && !InC) + (In2 && !InC2);
				counter <= (counter==38)? 0 : counter +2;
			end
			MAX_C1:begin
				if(in_circle >= max_in1)begin
					max_in1 <= in_circle  ;
					C1X <= circle_x ;
					C1Y <= circle_y ;
				end
				if(circle_x==iter_x) begin
					circle_x <= iter_x - 4;
					circle_y <= circle_y + 1;
				end
				else circle_x <= circle_x + 1;
				in_circle <= 0;
			end
			DEFINE_BOND2:begin
				circle_x <= C2X - 1;
				circle_y <= C2Y - 3;
				iter_x <= C2X + 2;
				iter_y <= C2Y + 2;
				max_in2 <= 0;
				old_x <= C2X;
				old_y <= C2Y; 
				temp_x <= C1X ;
				temp_y <= C1Y ;
			end
			ITERATE_C2:begin
				in_circle <= in_circle + (In1 && !InC) + (In2 && !InC2);
				counter <= (counter==38)? 0 : counter +2;
			end
			MAX_C2:begin
				if(in_circle >= max_in2)begin
					max_in2 <= in_circle  ;
					C2X <= circle_x ;
					C2Y <= circle_y ;
				end
				if(circle_x==iter_x) begin
					circle_x <= iter_x - 4;
					circle_y <= circle_y + 1;
				end
				else circle_x <= circle_x + 1;
				in_circle <= 0;
			end
			FINISH:begin
				DONE <= 1;
				circle_x <= 0;
				circle_y <= 0;
				counter <= 0;
				max_in1 <= 0;
				max_in2 <= 0;
				in_circle <= 0;
			end
			STALL:begin
				DONE <= 0;
			end
		endcase
	end
end




always@(*)begin
	case(curr_state)
			ACCEPT_DATA:begin
				next_state = (counter==39)? CIRCLE_1 : ACCEPT_DATA;
			end
			CIRCLE_1:begin
				next_state = (counter==39)? MAX_CIRCLE1 : CIRCLE_1;
			end
			MAX_CIRCLE1:begin
				next_state = (circle_x==15 && circle_y==15)? CIRCLE_2 : CIRCLE_1;
			end
			CIRCLE_2:begin
				next_state = (counter==39)? MAX_CIRCLE2 : CIRCLE_2;
			end
			MAX_CIRCLE2:begin
				next_state = (circle_x==15 && circle_y==15)? DEFINE_BOND1 : CIRCLE_2;
			end
			DEFINE_BOND1:begin
				if(old_x == C2X && old_y ==C2Y) next_state = FINISH;
				else next_state = ITERATE_C1;
			end
			ITERATE_C1:begin
				next_state = (counter==38)? MAX_C1 : ITERATE_C1;
			end
			MAX_C1:begin
				next_state = (circle_x==iter_x && circle_y==iter_y)? DEFINE_BOND2 : ITERATE_C1;
			end
			DEFINE_BOND2:begin
				if(old_x == C1X && old_y ==C1Y) next_state = FINISH;
				else next_state = ITERATE_C2;
			end
			ITERATE_C2:begin
				next_state = (counter==38)? MAX_C2 : ITERATE_C2;
			end
			MAX_C2:begin
				next_state = (circle_x==iter_x && circle_y==iter_y)? DEFINE_BOND1 : ITERATE_C2;
			end
			FINISH:begin
				next_state = STALL;
			end
			STALL:begin
				next_state = ACCEPT_DATA;
			end
			default : next_state = 'hx;
	endcase
end


endmodule 


