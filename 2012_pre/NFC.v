`timescale 1ns/100ps

`define PAGE_SIZE 512

module NFC(clk, rst, done, F_IO_A, F_CLE_A, F_ALE_A, F_REN_A, F_WEN_A, F_RB_A, F_IO_B, F_CLE_B, F_ALE_B, F_REN_B, F_WEN_B, F_RB_B);

input clk;
input rst;
output reg done;

inout [7:0] F_IO_A;   // always read
output reg F_CLE_A;   // High -> F_IO_A is concerned as instruction
output reg F_ALE_A;   // High -> F_IO_A is concerned as address
output reg F_REN_A;   // High -> continuous read
output reg F_WEN_A;   // High -> write enable
input  F_RB_A;        // Low  -> busy 、 High -> free

inout [7:0] F_IO_B;   // always write
output reg F_CLE_B;   // High -> F_IO_B is concerned as instruction
output reg F_ALE_B;   // High -> F_IO_B is concerned as address
output reg F_REN_B;   // High -> continuous read
output reg F_WEN_B;   // High -> write enable
input  F_RB_B;        // Low  -> busy 、 High -> free

reg [2:0] cr_state, nt_state;
reg [9:0] addr_cnt;
reg [9:0] page_cnt;
reg [7:0] A_out, B_out;
reg A_en, B_en;

assign F_IO_A = (A_en)? A_out : 8'bzzzz_zzzz;
assign F_IO_B = (B_en)? B_out : 8'bzzzz_zzzz;

localparam  COMM    = 3'd0,
            BUFFER  = 3'd1,
            ADDR    = 3'd2,
            WAIT    = 3'd3,
            READ    = 3'd4,
            WRITE   = 3'd5,
            STOP    = 3'd6,
            PAGEADD = 3'd7;

            
always@(posedge clk or posedge rst) begin
    if(rst) begin
        cr_state <= COMM;
    end
    else begin
        cr_state <= nt_state;
    end
end

always@(posedge clk or posedge rst) begin
    if(rst) begin
        F_CLE_A <= 0;
        F_ALE_A <= 0;
        F_REN_A <= 1;
        A_en <= 0;
        A_out <= 8'd0;
        addr_cnt <= 10'd0;
        done <= 0;
    end
    else begin
        case(cr_state)
            COMM:begin
                A_en <= 1;
                F_CLE_A <= 1;
                F_ALE_A <= 0;
                F_WEN_A <= 0;
                A_out <= 0;
            end
            BUFFER:begin
                F_WEN_A <= 1;
            end
            ADDR:begin
                F_CLE_A <= 0;
                F_ALE_A <= 1;
                F_WEN_A <= ~F_WEN_A;
                if(addr_cnt==0)
                    A_out <= 0;
                else if(addr_cnt==1) // row address
                    A_out <= page_cnt[7:0];
                else if(addr_cnt==2)
                    A_out <= {7'd0, page_cnt[8]};
                if(!F_WEN_A) 
                    addr_cnt <= addr_cnt + 1;
            end
            WAIT:begin
                addr_cnt <= 6'd0;
                F_WEN_A <= 1;
            end
            READ:begin
                A_en <= 0;
                F_ALE_A <= 0;
                F_REN_A <= ~F_REN_A;
                if(F_REN_A) begin
                    addr_cnt <= addr_cnt + 1;
                end
                else if (addr_cnt==513) begin
                    addr_cnt <= 10'd0;
                end
            end
            PAGEADD:begin
                if(page_cnt==`PAGE_SIZE && F_RB_B) done <= 1;
            end
        endcase
    end
end

always@(posedge clk or posedge rst) begin
    if(rst) begin
        F_CLE_B <= 0;
        F_ALE_B <= 0;
        F_WEN_B <= 1;
        B_en <= 0;
        B_out <= 8'd0;
        page_cnt <= 10'd0;
    end
    else begin
        case(cr_state)
            COMM:begin
                B_en <= 1;
                F_CLE_B <= 1;
                F_ALE_B <= 0;
                F_REN_B <= 1;
                B_out <= 8'd128;
                F_WEN_B <= 0;
            end
            BUFFER:begin
                F_WEN_B <= 1;
            end
            ADDR:begin
                F_CLE_B <= 0;
                F_ALE_B <= 1;
                F_WEN_B <= ~F_WEN_B;
                if(addr_cnt==0)begin   // column address
                    B_out <= 0;
                end
                else if(addr_cnt==1)begin // row address
                    B_out <= page_cnt[7:0];
                end
                else B_out <= {7'd0, page_cnt[8]};
            end
            WAIT:begin
                F_WEN_B <= 1;
            end
            READ:begin
                F_ALE_B <= 0;
                if (addr_cnt==513) begin
                    B_out <= 16;
                    F_CLE_B <= 1;
                end
                else if(!F_REN_A) begin
                    B_out <= F_IO_A;
                end
                if(!A_en)
                    F_WEN_B <= ~F_WEN_B;
            end
            WRITE:begin
                F_WEN_B <= ~F_WEN_B;
            end
            STOP:begin
                F_CLE_B <= 0;
                page_cnt <= page_cnt + 1;
            end
            PAGEADD:begin
                
            end
        endcase
    end
end

always@(*)begin
    case(cr_state)
        COMM:begin
            nt_state = BUFFER;     
        end
        BUFFER:begin
            nt_state = ADDR;
        end
        ADDR:begin
            nt_state = (addr_cnt==2)? WAIT : ADDR;
        end
        WAIT:begin
            nt_state = (F_RB_A)? READ : WAIT;        
        end
        READ:begin
            nt_state = (addr_cnt==513)? WRITE : READ;
        end
        WRITE:begin
            nt_state = STOP;
        end
        STOP:begin
            nt_state = PAGEADD;
        end
        PAGEADD: nt_state = (F_RB_B)? COMM : PAGEADD;
    endcase
end

endmodule
