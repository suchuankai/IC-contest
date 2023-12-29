module huffman(clk, reset, gray_data, gray_valid, CNT_valid, CNT1, CNT2, CNT3, CNT4, CNT5, CNT6,
    code_valid, HC1, HC2, HC3, HC4, HC5, HC6, M1, M2, M3, M4, M5, M6);

input             clk;
input             reset;
input             gray_valid;
input       [7:0] gray_data;
output reg        CNT_valid;
output   [7:0] CNT1, CNT2, CNT3, CNT4, CNT5, CNT6;
output reg        code_valid;
output  [7:0] HC1, HC2, HC3, HC4, HC5, HC6;
output  [7:0] M1, M2, M3, M4, M5, M6;




integer i, j;
reg [1:0] nt_state,cr_state;
reg [7:0] CNT_array [6:1];
reg [7:0] HC_array  [6:1];
reg [7:0] M_array   [6:1];
reg [7:0] counter ; 

reg [7:0] min1, min2;
reg [2:0] min1_index, min2_index;
reg [3:0] group1_index, group2_index;
reg [3:0] CNT_group [6:1];
reg [3:0] group_count;


assign CNT1 = CNT_array[1];
assign CNT2 = CNT_array[2];
assign CNT3 = CNT_array[3];
assign CNT4 = CNT_array[4];
assign CNT5 = CNT_array[5];
assign CNT6 = CNT_array[6];



assign M1 = 8'b1111_1111 >> (8-M_array[1]);
assign M2 = 8'b1111_1111 >> (8-M_array[2]);
assign M3 = 8'b1111_1111 >> (8-M_array[3]);
assign M4 = 8'b1111_1111 >> (8-M_array[4]);
assign M5 = 8'b1111_1111 >> (8-M_array[5]);
assign M6 = 8'b1111_1111 >> (8-M_array[6]);

assign HC1 = HC_array[1] >> (8-M_array[1]);
assign HC2 = HC_array[2] >> (8-M_array[2]);
assign HC3 = HC_array[3] >> (8-M_array[3]);
assign HC4 = HC_array[4] >> (8-M_array[4]);
assign HC5 = HC_array[5] >> (8-M_array[5]);
assign HC6 = HC_array[6] >> (8-M_array[6]);

parameter [2:0] ACCEPT     = 2'd0,
                FIND_MIN1  = 2'd1,
                COMPARE    = 2'd2,
                FINAL      = 2'd3;

always@(posedge clk or posedge reset) begin
    if (reset) begin
        min1_index <= 0;
        min2_index <= 0;
        group1_index <= 0;
        group2_index <= 0;
        for(i = 1; i <= 6 ; i = i+1) begin
            HC_array[i] <= 8'd0;
            M_array [i] <= 8'd0;
            CNT_group[i] <= i;
            CNT_array[i] <= 8'd0;
        end
        CNT_valid <= 0;
        code_valid <= 0;
        counter <= 0;
        min1    <= 255;
        min2    <= 255;
        group_count <= 7;
        cr_state <= ACCEPT;
    end
    else begin
        cr_state <= nt_state;

        case(cr_state)
    
            ACCEPT:begin
                counter <= (counter==2'd2)? 2'd2 : counter + 1;  //用來delay 2個cycle
		if(gray_valid)
                	CNT_array[gray_data] <= CNT_array[gray_data] + 8'd1;
                // case(gray_data)
                //     1:begin
                //         CNT_array[1] <= CNT_array[1] + 1;
                //     end
                //     2:begin
                //         CNT_array[2] <= CNT_array[2] + 1;
                //     end
                //     3:begin
                //         CNT_array[3] <= CNT_array[3] + 1;
                //     end
                //     4:begin
                //         CNT_array[4] <= CNT_array[4] + 1;
                //     end
                //     5:begin
                //         CNT_array[5] <= CNT_array[5] + 1;
                //     end
                //     6:begin
                //         CNT_array[6] <= CNT_array[6] + 1;
                //     end
                // endcase
                if((!gray_valid && counter==2)) begin
                    CNT_valid    <= 1    ;
                    counter      <= 1    ;
                end
            end

            FIND_MIN1:begin   //bubble sort
                CNT_valid    <= 0    ;
                if(CNT_array[counter] < min1 || (CNT_array[counter] == min1) && (CNT_group[counter] == (group_count-1)) )begin
                    min1 <= CNT_array[counter];
                    min1_index <= counter;
                    group1_index <= CNT_group[counter];

                    min2 <= min1;
                    min2_index <= min1_index;
                    group2_index <= group1_index;
                end
                if(CNT_array[counter] <= min2 && CNT_array[counter] >= min1 )begin
                    min2 <= CNT_array[counter];
                    min2_index <= counter;
                    group2_index <= CNT_group[counter];
                end
                
                counter <= (counter==6)? 1 : counter+1;
            end


            COMPARE:begin  //大於的填0 小於的填1
                for(i = 1; i <= 6 ; i = i+1) begin
                    if(CNT_group[i] == group1_index) begin
                        M_array[i] <= M_array[i] + 1;
                        HC_array[i] <= { 1'b1 , HC_array[i][7:1] };
                        CNT_group[i] <= group_count;
                    end
		        if(CNT_group[i] == group2_index) begin
                        M_array[i] <= M_array[i] + 1;
                        HC_array[i] <= { 1'b0 , HC_array[i][7:1] };
                        CNT_group[i] <= group_count;
                    end
                end
                
                CNT_array[min2_index] <= CNT_array[min1_index] + CNT_array[min2_index];
                CNT_array[min1_index] <= 8'd255; 
                group_count <= group_count + 1;
                min1 <= 255;
                min2 <= 255;
            end

            FINAL:begin
                code_valid <= 1;
            end

        endcase

    end
end




always@(*)begin

    case(cr_state)

        ACCEPT:begin
            nt_state = (!gray_valid && counter==2)? FIND_MIN1 : ACCEPT ;
        end

        FIND_MIN1:begin
            nt_state = (counter==6)? COMPARE : FIND_MIN1;
        end

        COMPARE:begin
            nt_state = (CNT_array[min1_index] + CNT_array[min2_index] == 100)? FINAL : FIND_MIN1;
        end

        FINAL:begin
            nt_state = FINAL;
        end

    endcase

end


endmodule

