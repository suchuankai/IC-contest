`timescale 1ns/10ps
module IOTDF( clk, rst, in_en, iot_in, fn_sel, busy, valid, iot_out);
input          clk;
input          rst;
input          in_en;
input  [7:0]   iot_in;
input  [2:0]   fn_sel;
output reg     busy;
output reg     valid;
output reg [127:0] iot_out;

reg [2:0] crState, ntState;
reg [127:0] temp;
reg [2:0] avg_overflow; 
reg [5:0] counter;
reg [3:0] times;
reg firstOut, newOut;

parameter SELECT    = 3'd0,
          MAX_MIN   = 3'd1,
          AVG       = 3'd2,
          EXT_EXC   = 3'd3,
          PMAX_PMIN = 3'd4,
          OUTPUT    = 3'd5;

parameter ExtractLow  = 128'h6FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF,
		  ExtractHigh = 128'hAFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF,
		  ExcludeLow  = 128'h7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF,
		  ExcludeHigh = 128'hBFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;

wire extract = ((temp>ExtractLow && temp<ExtractHigh) && fn_sel==4);
wire exclude = ((temp<ExcludeLow || temp>ExcludeHigh) && fn_sel==5);

always@(posedge clk or posedge rst)begin
	if(rst) begin
		busy <= 1;
		valid <= 0;
		firstOut <= 1;
		iot_out <= 128'd0;
		crState <= SELECT;
	end
	else begin
		crState <= ntState;
		busy <= (counter>=14)? 1 : 0;
		case(crState)
			SELECT:begin
				busy <= 0;
				valid <= 0;
				times <= 0;
				newOut <= 0;
				counter <= 6'd0;
				avg_overflow <= 3'd0;
				if(fn_sel!=6 && fn_sel!=7) iot_out <= 0;
			end
			MAX_MIN:begin
				temp <= {temp[119:0], iot_in};
				if(counter==16)begin
					if(times==0) iot_out <= temp;
					else if(fn_sel==1)begin  
						 if(temp>iot_out) iot_out <= temp;   // MAX
					end
					else if(temp<=iot_out) iot_out <= temp;  // MIN
					temp <= 0;
					counter <= 6'd0;
					times <= times + 1;
				end
				else if(in_en)counter <= counter + 1;
			end
			AVG:begin
				temp <= {temp[119:0], iot_in};
				if(counter==16)begin
					if(times==7) iot_out <= ({avg_overflow, iot_out} + temp) >> 3;
					else {avg_overflow, iot_out} <= {avg_overflow, iot_out} + temp;
					temp <= 0;
					counter <= 6'd0;
					times <= times + 1;
				end
				else if(in_en)counter <= counter + 1;
			end
			EXT_EXC:begin
				temp <= {temp[119:0], iot_in};
				if(counter==16)begin
					temp <= 0;
					counter <= 6'd0;
					times <= times + 1;
					if(extract ||  exclude) iot_out <= temp;
				end
				else if(in_en)counter <= counter + 1;
			end
			PMAX_PMIN:begin
				temp <= {temp[119:0], iot_in};
				if(counter==16)begin
					if(fn_sel==6)begin
						if(temp>iot_out) begin
							iot_out <= temp;
							newOut <= 1;
						end
					end
					else begin
						if(temp<iot_out || iot_out==0) begin
							iot_out <= temp;
							newOut <= 1;
						end
					end
					temp <= 0;
					counter <= 6'd0;
					if(times==7) begin
						firstOut <= 0;
						times <= 0;
					end
					else times <= times + 1;
				end
				else if(in_en)counter <= counter + 1;
			end
			OUTPUT:begin
				valid <= 1;
			end
		endcase
	end
end

always@(*)begin
	case(crState)
		SELECT:begin
			case(fn_sel)
				3'd1, 3'd2: ntState = MAX_MIN;
				3'd3: ntState = AVG;
				3'd4, 3'd5: ntState = EXT_EXC;
				3'd6, 3'd7: ntState = PMAX_PMIN;
				default : ntState = SELECT;
			endcase
		end
		MAX_MIN:begin
			ntState = (counter==16 && times==7)? OUTPUT : MAX_MIN;
		end
		AVG:begin
			ntState = (counter==16 && times==7)? OUTPUT : AVG;
		end
		EXT_EXC:begin
			ntState = (counter==16 && (extract || exclude))? OUTPUT : EXT_EXC;
		end
		PMAX_PMIN:begin
			ntState = ((counter==16 && times==7) && (newOut||firstOut))? OUTPUT : PMAX_PMIN;
		end
		OUTPUT:begin
			ntState = SELECT;
		end
		default : ntState = 'hx;
	endcase
end

endmodule
