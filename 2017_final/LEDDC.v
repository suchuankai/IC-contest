`timescale 1ns/10ps
module LEDDC( DCK, DAI, DEN, GCK, Vsync, mode, rst, OUT);
input           DCK;
input           DAI;
input           DEN;
input           GCK;
input           Vsync;
input           mode;
input           rst;
output reg [15:0]   OUT;

reg  [8:0] read_addr, write_addr;
reg  [15:0] DB_buf;
wire [15:0] QA_buf;
reg CENB_temp;

// Data memory
sram_512x16 sram_512x16 (
	/* Port A : Read */
   	.AA(read_addr),
   	.QA(QA_buf),
   	.CLKA(GCK),
   	.CENA(1'b0),

   	/* Port B : Write */
   	.AB(write_addr),
   	.DB(DB_buf),
   	.CLKB(DCK),  
   	.CENB(CENB_temp)
);

reg [4:0] read_cnt;
reg D_state, D_nt_state;

/* Read from host and save to SRAM */
always@(posedge DCK or posedge rst) begin
	if(rst) begin
		read_cnt <= 5'd0;
		write_addr <= 9'b1_1111_1111;
		D_state <= 0;
		DB_buf <= 16'd0;
		CENB_temp <= 0;
	end
	else begin
		D_state <= D_nt_state;
		case(D_state)
			0:begin
				CENB_temp <= 1;
				if(DEN) begin
					read_cnt <= read_cnt + 1;
					if(!read_cnt[3])
						DB_buf <= {DAI, DB_buf[15:1]};
				end
			end
			1:begin
				read_cnt <= (read_cnt==5'd1)? 5'd0 : read_cnt + 1;
				if(read_cnt==5'd1) begin
					CENB_temp <= 0;
					write_addr <= write_addr + 1;   // Write to SRAM
				end
			end
		endcase
	end
end

always@(*)begin
	case(D_state)
		0:	D_nt_state = (read_cnt==5'd31)? 1 : 0;
		1:	D_nt_state = (read_cnt==5'd1)?  0 : 1;
	endcase
end

reg round;
reg [15:0] out_cnt;
reg [7:0] G_out_cnt [15:0];
reg [1:0] G_state, G_nt_state;
integer i;

/* Read from SRAM and output pwd */
always@(posedge GCK or posedge rst) begin
	if(rst) begin
		read_addr <= 9'd0;
		out_cnt <= 16'd0;
		G_state <= 0;
		round <= 1;
		for( i = 0; i <= 15; i = i + 1) begin
			G_out_cnt[i] <= 8'd0;
		end
	end
	else begin
		G_state <= G_nt_state;
		if(Vsync)begin
			case(G_state)
				0:begin
					if((read_addr[7:0]==8'b1111_1111) && mode) round <= ~round;
				end
				1:begin      // Accept sixteen buffer data from SRAM
					if(!round && read_addr[7:0]==8'b1111_1111) read_addr <= read_addr & 9'b1_0000_0000;
					else if(write_addr==255) read_addr <= 0;
					else read_addr <= read_addr + 1;
				end
				2:begin
					G_out_cnt[15] <= QA_buf[15:8];
					G_out_cnt[14] <= QA_buf[7:0];
					for( i = 0; i <= 13; i = i + 1) begin
						G_out_cnt[i] <= G_out_cnt[i+2];
					end
					if(out_cnt==8) 
						out_cnt <= 0;
					else begin
						out_cnt <= out_cnt + 1;
						read_addr <= (out_cnt==7)? read_addr : read_addr + 1;
					end
				end
				3:begin
					for( i = 0; i <= 15; i = i + 1) begin
						OUT[i] <= (out_cnt >= (({G_out_cnt[i], G_out_cnt[i]} >> mode) + ((G_out_cnt[i][0]) & round & mode)))? 0 : 1;
					end
					out_cnt <= out_cnt + 1;
				end
			endcase
		end
		else begin
			out_cnt <= 0;
		end
	end
end


always@(*)begin
	case(G_state)
		0:	G_nt_state = (Vsync)? 1 : 0;
		1:	G_nt_state = (Vsync)? 2 : 1;
		2:	G_nt_state = (out_cnt==8)? 3 : 2;
		3:	G_nt_state = (Vsync)? 3 : 0;
	endcase
end

endmodule