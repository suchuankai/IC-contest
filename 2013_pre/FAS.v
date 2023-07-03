
module  FAS (data_valid, data, clk, rst, fir_d, fir_valid, fft_valid, done, freq,
 fft_d1, fft_d2, fft_d3, fft_d4, fft_d5, fft_d6, fft_d7, fft_d8,
 fft_d9, fft_d10, fft_d11, fft_d12, fft_d13, fft_d14, fft_d15, fft_d0);

`include "./dat/FIR_coefficient.dat"
input clk, rst;
input data_valid;
input [15:0] data; 

output reg fir_valid, fft_valid;
output [15:0] fir_d;
output [31:0] fft_d1, fft_d2, fft_d3, fft_d4, fft_d5, fft_d6, fft_d7, fft_d8;
output [31:0] fft_d9, fft_d10, fft_d11, fft_d12, fft_d13, fft_d14, fft_d15, fft_d0;
output reg   done;
output [3:0] freq;




reg [2:0] cr_state, nt_state;
reg [11:0] counter;
reg  signed [15:0] data_tmp [31:0];
integer i;


parameter   READ_FIRST_DATA = 1'b0,
            READ_FIRST_Y    = 1'b1;
                


// 8_8   4_16

// [40:24] _ [23:0]
//     31  :  16
 


// -----------------------------------FIR caculate--------------------------------------------

wire signed [35:0] fir_tmp  [31:0];    //16(8_8)bit * 20bit
wire signed [38:0] sum_1 [3:0];        //max 39 bit
wire signed [39:0] sum_2 [1:0];        //max 40 bit
wire signed [40:0] sum_3 ;

assign fir_tmp[0]  =  data_tmp[0]  * FIR_C00;  assign fir_tmp[1]  =  data_tmp[1]  * FIR_C01;
assign fir_tmp[2]  =  data_tmp[2]  * FIR_C02;  assign fir_tmp[3]  =  data_tmp[3]  * FIR_C03;
assign fir_tmp[4]  =  data_tmp[4]  * FIR_C04;  assign fir_tmp[5]  =  data_tmp[5]  * FIR_C05;
assign fir_tmp[6]  =  data_tmp[6]  * FIR_C06;  assign fir_tmp[7]  =  data_tmp[7]  * FIR_C07;
assign fir_tmp[8]  =  data_tmp[8]  * FIR_C08;  assign fir_tmp[9]  =  data_tmp[9]  * FIR_C09;
assign fir_tmp[10] =  data_tmp[10] * FIR_C10;  assign fir_tmp[11] =  data_tmp[11] * FIR_C11;
assign fir_tmp[12] =  data_tmp[12] * FIR_C12;  assign fir_tmp[13] =  data_tmp[13] * FIR_C13;
assign fir_tmp[14] =  data_tmp[14] * FIR_C14;  assign fir_tmp[15] =  data_tmp[15] * FIR_C15;
assign fir_tmp[16] =  data_tmp[16] * FIR_C16;  assign fir_tmp[17] =  data_tmp[17] * FIR_C17;
assign fir_tmp[18] =  data_tmp[18] * FIR_C18;  assign fir_tmp[19] =  data_tmp[19] * FIR_C19;
assign fir_tmp[20] =  data_tmp[20] * FIR_C20;  assign fir_tmp[21] =  data_tmp[21] * FIR_C21; 
assign fir_tmp[22] =  data_tmp[22] * FIR_C22;  assign fir_tmp[23] =  data_tmp[23] * FIR_C23; 
assign fir_tmp[24] =  data_tmp[24] * FIR_C24;  assign fir_tmp[25] =  data_tmp[25] * FIR_C25; 
assign fir_tmp[26] =  data_tmp[26] * FIR_C26;  assign fir_tmp[27] =  data_tmp[27] * FIR_C27; 
assign fir_tmp[28] =  data_tmp[28] * FIR_C28;  assign fir_tmp[29] =  data_tmp[29] * FIR_C29; 
assign fir_tmp[30] =  data_tmp[30] * FIR_C30;  assign fir_tmp[31] =  data_tmp[31] * FIR_C31;

assign sum_1[0] = fir_tmp[0]  + fir_tmp[1]  + fir_tmp[2]  + fir_tmp[3]  + fir_tmp[4]  + fir_tmp[5]  + fir_tmp[6]  + fir_tmp[7]  ;
assign sum_1[1] = fir_tmp[8]  + fir_tmp[9]  + fir_tmp[10] + fir_tmp[11] + fir_tmp[12] + fir_tmp[13] + fir_tmp[14] + fir_tmp[15] ;
assign sum_1[2] = fir_tmp[16] + fir_tmp[17] + fir_tmp[18] + fir_tmp[19] + fir_tmp[20] + fir_tmp[21] + fir_tmp[22] + fir_tmp[23] ;
assign sum_1[3] = fir_tmp[24] + fir_tmp[25] + fir_tmp[26] + fir_tmp[27] + fir_tmp[28] + fir_tmp[29] + fir_tmp[30] + fir_tmp[31] ;

assign sum_2[0] = sum_1[0] + sum_1[1] ;
assign sum_2[1] = sum_1[2] + sum_1[3] ;

assign sum_3    = sum_2[0] + sum_2[1];  // fir final sum
assign fir_d    = { sum_3[31:24],sum_3[23:16] } + sum_3[40] ;     // ask!

reg signed [31:0] fir_y  [15:0];    //16(8_8)bit * 20bit

// -------------------------------------------------------------------------------------------

// image part
parameter signed [31:0] W0_IMAGE = 32'h00000000 ;     
parameter signed [31:0] W1_IMAGE = 32'hFFFF9E09 ;     
parameter signed [31:0] W2_IMAGE = 32'hFFFF4AFC ;     
parameter signed [31:0] W3_IMAGE = 32'hFFFF137D ;     
parameter signed [31:0] W4_IMAGE = 32'hFFFF0000 ;     
parameter signed [31:0] W5_IMAGE = 32'hFFFF137D ;     
parameter signed [31:0] W6_IMAGE = 32'hFFFF4AFC ;     
parameter signed [31:0] W7_IMAGE = 32'hFFFF9E09 ;     

// real part
parameter signed [31:0] W0_REAL  = 32'h00010000 ;    
parameter signed [31:0] W1_REAL  = 32'h0000EC83 ;   
parameter signed [31:0] W2_REAL  = 32'h0000B504 ;    
parameter signed [31:0] W3_REAL  = 32'h000061F7 ;    
parameter signed [31:0] W4_REAL  = 32'h00000000 ;   
parameter signed [31:0] W5_REAL  = 32'hFFFF9E09 ;    
parameter signed [31:0] W6_REAL  = 32'hFFFF4AFC ;     
parameter signed [31:0] W7_REAL  = 32'hFFFF137D ;     

// ------------------------------------------- FFT stage1 -----------------------------------------------

wire signed [32:0] stage1_real   [15:0];    //16(8_8)bit * 20bit
wire signed [32:0] stage1_image  [15:0];    //16(8_8)bit * 20bit

// No image part     Don't leave decimal part  1bit signed  8bit 整數  8 bit 小數 為了保持16bit整數16bit小數，所以左移8
assign stage1_real[0] = {(fir_y[0] + fir_y[8]),8'b0}   ; assign stage1_real[1] = {(fir_y[1] + fir_y[9]),8'b0}  ;
assign stage1_real[2] = {(fir_y[2] + fir_y[10]),8'b0}  ; assign stage1_real[3] = {(fir_y[3] + fir_y[11]),8'b0} ;
assign stage1_real[4] = {(fir_y[4] + fir_y[12]),8'b0}  ; assign stage1_real[5] = {(fir_y[5] + fir_y[13]),8'b0} ;
assign stage1_real[6] = {(fir_y[6] + fir_y[14]),8'b0}  ; assign stage1_real[7] = {(fir_y[7] + fir_y[15]),8'b0} ;

assign stage1_image[0] = 0 ; assign stage1_image[1] = 0;
assign stage1_image[2] = 0 ; assign stage1_image[3] = 0;
assign stage1_image[4] = 0 ; assign stage1_image[5] = 0;
assign stage1_image[6] = 0 ; assign stage1_image[7] = 0;
//---------

// real   8_8 * 16*_16    =   24_24   右移8bit得到 16_16
assign stage1_real[8]  = ((fir_y[0] - fir_y[8]) *W0_REAL)>>>8 ; assign stage1_real[9]  = ((fir_y[1] - fir_y[9]) *W1_REAL)>>>8;
assign stage1_real[10] = ((fir_y[2] - fir_y[10])*W2_REAL)>>>8 ; assign stage1_real[11] = ((fir_y[3] - fir_y[11])*W3_REAL)>>>8;
assign stage1_real[12] = ((fir_y[4] - fir_y[12])*W4_REAL)>>>8 ; assign stage1_real[13] = ((fir_y[5] - fir_y[13])*W5_REAL)>>>8;
assign stage1_real[14] = ((fir_y[6] - fir_y[14])*W6_REAL)>>>8 ; assign stage1_real[15] = ((fir_y[7] - fir_y[15])*W7_REAL)>>>8;

// image 
assign stage1_image[8]  = ((fir_y[0] - fir_y[8]) *W0_IMAGE)>>>8 ; assign stage1_image[9]  = ((fir_y[1] - fir_y[9]) *W1_IMAGE)>>>8;
assign stage1_image[10] = ((fir_y[2] - fir_y[10])*W2_IMAGE)>>>8 ; assign stage1_image[11] = ((fir_y[3] - fir_y[11])*W3_IMAGE)>>>8;
assign stage1_image[12] = ((fir_y[4] - fir_y[12])*W4_IMAGE)>>>8 ; assign stage1_image[13] = ((fir_y[5] - fir_y[13])*W5_IMAGE)>>>8;
assign stage1_image[14] = ((fir_y[6] - fir_y[14])*W6_IMAGE)>>>8 ; assign stage1_image[15] = ((fir_y[7] - fir_y[15])*W7_IMAGE)>>>8;

// ------------------------------------------------------------------------------------------------------


// ------------------------------------------- FFT stage2 -----------------------------------------------

wire signed [34:0] stage2_real   [15:0];    //16(8_8)bit * 20bit
wire signed [34:0] stage2_image  [15:0];    //16(8_8)bit * 20bit

// No image part 
assign stage2_real[0] = stage1_real[0] + stage1_real[4]  ; assign stage2_real[1] = stage1_real[1] + stage1_real[5];
assign stage2_real[2] = stage1_real[2] + stage1_real[6]  ; assign stage2_real[3] = stage1_real[3] + stage1_real[7];

assign stage2_image[0] = 0 ; assign stage2_image[1] = 0;
assign stage2_image[2] = 0 ; assign stage2_image[3] = 0;
//---------------

// real  16_16 * 16_16
assign stage2_real[4] = ((stage1_real[0] - stage1_real[4])*W0_REAL) >>> 16  ; assign stage2_real[5] = ((stage1_real[1] - stage1_real[5])*W2_REAL) >>> 16;
assign stage2_real[6] = ((stage1_real[2] - stage1_real[6])*W4_REAL) >>> 16  ; assign stage2_real[7] = ((stage1_real[3] - stage1_real[7])*W6_REAL) >>> 16;

// image 
assign stage2_image[4] = ((stage1_real[0] - stage1_real[4])*W0_IMAGE) >>> 16  ; assign stage2_image[5] = ((stage1_real[1] - stage1_real[5])*W2_IMAGE) >>> 16;
assign stage2_image[6] = ((stage1_real[2] - stage1_real[6])*W4_IMAGE) >>> 16  ; assign stage2_image[7] = ((stage1_real[3] - stage1_real[7])*W6_IMAGE) >>> 16;

//---------------

// real
assign stage2_real[8] =  (stage1_real[8]  + stage1_real[12]); 
assign stage2_real[9] =  (stage1_real[9]  + stage1_real[13]);
assign stage2_real[10] = (stage1_real[10] + stage1_real[14]); 
assign stage2_real[11] = (stage1_real[11] + stage1_real[15]);

assign stage2_real[12] = ((stage1_real[8]  - stage1_real[12])*W0_REAL  + (stage1_image[12]  - stage1_image[8])*W0_IMAGE) >>> 16; 
assign stage2_real[13] = ((stage1_real[9]  - stage1_real[13])*W2_REAL  + (stage1_image[13]  - stage1_image[9])*W2_IMAGE) >>> 16;
assign stage2_real[14] = ((stage1_real[10] - stage1_real[14])*W4_REAL  + (stage1_image[14] - stage1_image[10])*W4_IMAGE) >>> 16; 
assign stage2_real[15] = ((stage1_real[11] - stage1_real[15])*W6_REAL  + (stage1_image[15] - stage1_image[11])*W6_IMAGE) >>> 16;

// image
assign stage2_image[8] =  (stage1_image[8]  + stage1_image[12]); 
assign stage2_image[9] =  (stage1_image[9]  + stage1_image[13]);
assign stage2_image[10] = (stage1_image[10] + stage1_image[14]); 
assign stage2_image[11] = (stage1_image[11] + stage1_image[15]);

assign stage2_image[12] = ((stage1_real[8]  - stage1_real[12])*W0_IMAGE  + (stage1_image[8]  - stage1_image[12])*W0_REAL) >>> 16; 
assign stage2_image[13] = ((stage1_real[9]  - stage1_real[13])*W2_IMAGE  + (stage1_image[9]  - stage1_image[13])*W2_REAL) >>> 16;
assign stage2_image[14] = ((stage1_real[10] - stage1_real[14])*W4_IMAGE  + (stage1_image[10] - stage1_image[14])*W4_REAL) >>> 16; 
assign stage2_image[15] = ((stage1_real[11] - stage1_real[15])*W6_IMAGE  + (stage1_image[11] - stage1_image[15])*W6_REAL) >>> 16;

// ------------------------------------------------------------------------------------------------------




// ------------------------------------------- FFT stage3 -----------------------------------------------

wire signed [36:0] stage3_real   [15:0];    //16(8_8)bit * 20bit
wire signed [36:0] stage3_image  [15:0];    //16(8_8)bit * 20bit

// No image part 
assign stage3_real[0]  = stage2_real[0]  + stage2_real[2]  ; 
assign stage3_real[1]  = stage2_real[1]  + stage2_real[3]  ;
assign stage3_real[2]  = ((stage2_real[0] - stage2_real[2])*W0_REAL  +  (stage2_image[2] - stage2_image[0])*W0_IMAGE) >>> 16; 
assign stage3_real[3]  = ((stage2_real[1] - stage2_real[3])*W4_REAL  +  (stage2_image[3] - stage2_image[1])*W4_IMAGE) >>> 16; 
assign stage3_image[0] = stage2_image[0] + stage2_image[2]  ; 
assign stage3_image[1] = stage2_image[1] + stage2_image[3]  ;
assign stage3_image[2] = ((stage2_real[0] - stage2_real[2])*W0_IMAGE +  (stage2_image[0] - stage2_image[2])*W0_REAL) >>> 16; 
assign stage3_image[3] = ((stage2_real[1] - stage2_real[3])*W4_IMAGE +  (stage2_image[1] - stage2_image[3])*W4_REAL) >>> 16; 


assign stage3_real[4]  = stage2_real[4]  + stage2_real[6]  ; 
assign stage3_real[5]  = stage2_real[5]  + stage2_real[7]  ;
assign stage3_real[6]  = ((stage2_real[4] - stage2_real[6])*W0_REAL  +  (stage2_image[6] - stage2_image[4])*W0_IMAGE) >>> 16; 
assign stage3_real[7]  = ((stage2_real[5] - stage2_real[7])*W4_REAL  +  (stage2_image[7] - stage2_image[5])*W4_IMAGE) >>> 16; 
assign stage3_image[4] = stage2_image[4] + stage2_image[6]  ; 
assign stage3_image[5] = stage2_image[5] + stage2_image[7]  ;
assign stage3_image[6] = ((stage2_real[4] - stage2_real[6])*W0_IMAGE +  (stage2_image[4] - stage2_image[6])*W0_REAL) >>> 16; 
assign stage3_image[7] = ((stage2_real[5] - stage2_real[7])*W4_IMAGE +  (stage2_image[5] - stage2_image[7])*W4_REAL) >>> 16; 


assign stage3_real[8]   = stage2_real[8]  + stage2_real[10]  ; 
assign stage3_real[9]   = stage2_real[9]  + stage2_real[11]  ;
assign stage3_real[10]  = ((stage2_real[8] - stage2_real[10])*W0_REAL  +  (stage2_image[10] - stage2_image[8])*W0_IMAGE) >>> 16; 
assign stage3_real[11]  = ((stage2_real[9] - stage2_real[11])*W4_REAL  +  (stage2_image[11] - stage2_image[9])*W4_IMAGE) >>> 16; 
assign stage3_image[8]  = stage2_image[8] + stage2_image[10]  ; 
assign stage3_image[9]  = stage2_image[9] + stage2_image[11]  ;
assign stage3_image[10] = ((stage2_real[8] - stage2_real[10])*W0_IMAGE +  (stage2_image[8] - stage2_image[10])*W0_REAL) >>> 16; 
assign stage3_image[11] = ((stage2_real[9] - stage2_real[11])*W4_IMAGE +  (stage2_image[9] - stage2_image[11])*W4_REAL) >>> 16; 


assign stage3_real[12]  = stage2_real[12]  + stage2_real[14]  ; 
assign stage3_real[13]  = stage2_real[13]  + stage2_real[15]  ;
assign stage3_real[14]  = ((stage2_real[12] - stage2_real[14])*W0_REAL  +  (stage2_image[14] - stage2_image[12])*W0_IMAGE) >>> 16; 
assign stage3_real[15]  = ((stage2_real[13] - stage2_real[15])*W4_REAL  +  (stage2_image[15] - stage2_image[13])*W4_IMAGE) >>> 16; 
assign stage3_image[12] = stage2_image[12] + stage2_image[14]  ; 
assign stage3_image[13] = stage2_image[13] + stage2_image[15]  ;
assign stage3_image[14] = ((stage2_real[12] - stage2_real[14])*W0_IMAGE +  (stage2_image[12] - stage2_image[14])*W0_REAL) >>> 16; 
assign stage3_image[15] = ((stage2_real[13] - stage2_real[15])*W4_IMAGE +  (stage2_image[13] - stage2_image[15])*W4_REAL) >>> 16; 

// ------------------------------------------------------------------------------------------------------


// ------------------------------------------- FFT stage4 -----------------------------------------------

wire signed [39:0] stage4_real   [15:0];    //16(8_8)bit * 20bit
wire signed [39:0] stage4_image  [15:0];    //16(8_8)bit * 20bit

// No image part 
assign stage4_real[0]  = stage3_real[0]  + stage3_real[1]   ; 
assign stage4_real[1]  = ((stage3_real[0] - stage3_real[1])*W0_REAL  +  (stage3_image[1] - stage3_image[0])*W0_IMAGE) >>> 16; 
assign stage4_image[0] = stage3_image[0] + stage3_image[1]  ; 
assign stage4_image[1] = ((stage3_real[0] - stage3_real[1])*W0_IMAGE +  (stage3_image[0] - stage3_image[1])*W0_REAL) >>> 16; 

assign stage4_real[2]  = stage3_real[2] + stage3_real[3]   ; 
assign stage4_real[3]  = ((stage3_real[2] - stage3_real[3])*W0_REAL  +  (stage3_image[3] - stage3_image[2])*W0_IMAGE) >>> 16; 
assign stage4_image[2] = stage3_image[2] + stage3_image[3]  ; 
assign stage4_image[3] = ((stage3_real[2] - stage3_real[3])*W0_IMAGE +  (stage3_image[2] - stage3_image[3])*W0_REAL) >>> 16; 

assign stage4_real[4]  = stage3_real[4] + stage3_real[5]   ; 
assign stage4_real[5]  = ((stage3_real[4] - stage3_real[5])*W0_REAL  +  (stage3_image[5] - stage3_image[4])*W0_IMAGE) >>> 16; 
assign stage4_image[4] = stage3_image[4] + stage3_image[5]  ; 
assign stage4_image[5] = ((stage3_real[4] - stage3_real[5])*W0_IMAGE +  (stage3_image[4] - stage3_image[5])*W0_REAL) >>> 16; 

assign stage4_real[6]  = stage3_real[6] + stage3_real[7]    ; 
assign stage4_real[7]  = ((stage3_real[6] - stage3_real[7])*W0_REAL  +  (stage3_image[7] - stage3_image[6])*W0_IMAGE) >>> 16; 
assign stage4_image[6] = stage3_image[6] + stage3_image[7]  ; 
assign stage4_image[7] = ((stage3_real[6] - stage3_real[7])*W0_IMAGE +  (stage3_image[6] - stage3_image[7])*W0_REAL) >>> 16; 

assign stage4_real[8]  = stage3_real[8] + stage3_real[9]    ; 
assign stage4_real[9]  = ((stage3_real[8] - stage3_real[9])*W0_REAL  +  (stage3_image[9] - stage3_image[8])*W0_IMAGE) >>> 16; 
assign stage4_image[8] = stage3_image[8] + stage3_image[9]  ; 
assign stage4_image[9] = ((stage3_real[8] - stage3_real[9])*W0_IMAGE +  (stage3_image[8] - stage3_image[9])*W0_REAL) >>> 16; 

assign stage4_real[10]  = stage3_real[10] + stage3_real[11]    ; 
assign stage4_real[11]  = ((stage3_real[10] - stage3_real[11])*W0_REAL  +  (stage3_image[11] - stage3_image[10])*W0_IMAGE) >>> 16; 
assign stage4_image[10] = stage3_image[10] + stage3_image[11]  ; 
assign stage4_image[11] = ((stage3_real[10] - stage3_real[11])*W0_IMAGE +  (stage3_image[10] - stage3_image[11])*W0_REAL) >>> 16; 

assign stage4_real[12]  = stage3_real[12] + stage3_real[13]    ; 
assign stage4_real[13]  = ((stage3_real[12] - stage3_real[13])*W0_REAL  +  (stage3_image[13] - stage3_image[12])*W0_IMAGE) >>> 16; 
assign stage4_image[12] = stage3_image[12] + stage3_image[13]  ; 
assign stage4_image[13] = ((stage3_real[12] - stage3_real[13])*W0_IMAGE +  (stage3_image[12] - stage3_image[13])*W0_REAL) >>> 16; 

assign stage4_real[14]  = stage3_real[14] + stage3_real[15]    ; 
assign stage4_real[15]  = ((stage3_real[14] - stage3_real[15])*W0_REAL  +  (stage3_image[15] - stage3_image[14])*W0_IMAGE) >>> 16; 
assign stage4_image[14] = stage3_image[14] + stage3_image[15]  ; 
assign stage4_image[15] = ((stage3_real[14] - stage3_real[15])*W0_IMAGE +  (stage3_image[14] - stage3_image[15])*W0_REAL) >>> 16; 

// ------------------------------------------------------------------------------------------------------

// fft output
assign fft_d0  = { stage4_real[0] [23:8], stage4_image[0] [23:8] } ; 
assign fft_d1  = { stage4_real[8] [23:8], stage4_image[8] [23:8] } ;
assign fft_d2  = { stage4_real[4] [23:8], stage4_image[4] [23:8] } ;
assign fft_d3  = { stage4_real[12][23:8], stage4_image[12][23:8] } ;
assign fft_d4  = { stage4_real[2] [23:8], stage4_image[2] [23:8] } ; 
assign fft_d5  = { stage4_real[10][23:8], stage4_image[10][23:8] } ;
assign fft_d6  = { stage4_real[6] [23:8], stage4_image[6] [23:8] } ; 
assign fft_d7  = { stage4_real[14][23:8], stage4_image[14][23:8] } ; 
assign fft_d8  = { stage4_real[1] [23:8], stage4_image[1] [23:8] } ;
assign fft_d9  = { stage4_real[9] [23:8], stage4_image[9] [23:8] } ; 
assign fft_d10 = { stage4_real[5] [23:8], stage4_image[5] [23:8] } ; 
assign fft_d11 = { stage4_real[13][23:8], stage4_image[13][23:8] } ;
assign fft_d12 = { stage4_real[3] [23:8], stage4_image[3] [23:8] } ; 
assign fft_d13 = { stage4_real[11][23:8], stage4_image[11][23:8] } ; 
assign fft_d14 = { stage4_real[7] [23:8], stage4_image[7] [23:8] } ;
assign fft_d15 = { stage4_real[15][23:8], stage4_image[15][23:8] } ; 

// fft_freq
wire [31:0] fft_freq   [15:0];    //16(8_8)bit * 20bit
assign fft_freq[0]  =  $signed (fft_d0[31:16])* $signed (fft_d0[31:16])  + $signed (fft_d0[15:0])* $signed (fft_d0[15:0]);
assign fft_freq[1]  =  $signed (fft_d1[31:16])* $signed (fft_d1[31:16])  + $signed (fft_d1[15:0])* $signed (fft_d1[15:0]);
assign fft_freq[2]  =  $signed (fft_d2[31:16])* $signed (fft_d2[31:16])  + $signed (fft_d2[15:0])* $signed (fft_d2[15:0]);
assign fft_freq[3]  =  $signed (fft_d3[31:16])* $signed (fft_d3[31:16])  + $signed (fft_d3[15:0])* $signed (fft_d3[15:0]);
assign fft_freq[4]  =  $signed (fft_d4[31:16])* $signed (fft_d4[31:16])  + $signed (fft_d4[15:0])* $signed (fft_d4[15:0]);
assign fft_freq[5]  =  $signed (fft_d5[31:16])* $signed (fft_d5[31:16])  + $signed (fft_d5[15:0])* $signed (fft_d5[15:0]);
assign fft_freq[6]  =  $signed (fft_d6[31:16])* $signed (fft_d6[31:16])  + $signed (fft_d6[15:0])* $signed (fft_d6[15:0]);
assign fft_freq[7]  =  $signed (fft_d7[31:16])* $signed (fft_d7[31:16])  + $signed (fft_d7[15:0])* $signed (fft_d7[15:0]);
assign fft_freq[8]  =  $signed (fft_d8[31:16])* $signed (fft_d8[31:16])  + $signed (fft_d8[15:0])* $signed (fft_d8[15:0]);
assign fft_freq[9]  =  $signed (fft_d9[31:16])* $signed (fft_d9[31:16])  + $signed (fft_d9[15:0])* $signed (fft_d9[15:0]);
assign fft_freq[10] =  $signed (fft_d10[31:16])* $signed (fft_d10[31:16]) + $signed (fft_d10[15:0])* $signed (fft_d10[15:0]);
assign fft_freq[11] =  $signed (fft_d11[31:16])* $signed (fft_d11[31:16]) + $signed (fft_d11[15:0])* $signed (fft_d11[15:0]);
assign fft_freq[12] =  $signed (fft_d12[31:16])* $signed (fft_d12[31:16]) + $signed (fft_d12[15:0])* $signed (fft_d12[15:0]);
assign fft_freq[13] =  $signed (fft_d13[31:16])* $signed (fft_d13[31:16]) + $signed (fft_d13[15:0])* $signed (fft_d13[15:0]);
assign fft_freq[14] =  $signed (fft_d14[31:16])* $signed (fft_d14[31:16]) + $signed (fft_d14[15:0])* $signed (fft_d14[15:0]);
assign fft_freq[15] =  $signed (fft_d15[31:16])* $signed (fft_d15[31:16]) + $signed (fft_d15[15:0])* $signed (fft_d15[15:0]);

wire [3:0] index0, index1, index2, index3, index4, index5, index6, index7;   

assign index0 = (fft_freq[0]>fft_freq[1]  )? 0  : 1;
assign index1 = (fft_freq[2]>fft_freq[3]  )? 2  : 3;
assign index2 = (fft_freq[4]>fft_freq[5]  )? 4  : 5;
assign index3 = (fft_freq[6]>fft_freq[7]  )? 6  : 7;
assign index4 = (fft_freq[8]>fft_freq[9]  )? 8  : 9;
assign index5 = (fft_freq[10]>fft_freq[11])? 10 : 11;
assign index6 = (fft_freq[12]>fft_freq[13])? 12 : 13;
assign index7 = (fft_freq[14]>fft_freq[15])? 14 : 15;


wire [3:0] index8, index9, index10, index11; 

assign index8 =  (fft_freq[index0]>fft_freq[index1] )? index0  : index1;
assign index9 =  (fft_freq[index2]>fft_freq[index3] )? index2  : index3;
assign index10 = (fft_freq[index4]>fft_freq[index5] )? index4  : index5;
assign index11 = (fft_freq[index6]>fft_freq[index7] )? index6  : index7;


wire [3:0] index12, index13; 

assign index12 =  (fft_freq[index8]>fft_freq[index9]   )? index8   : index9;
assign index13 =  (fft_freq[index10]>fft_freq[index11] )? index10  : index11;
assign freq = (fft_freq[index12]>fft_freq[index13]  )? index12 :  index13; 


always @(posedge clk or posedge rst) begin
    if (rst) begin
        cr_state  <= READ_FIRST_DATA;
        counter   <= 5'd31;
        fir_valid <= 0;
        fft_valid <= 0;
        done      <= 0;
    end
    else begin
        cr_state <= nt_state;
        case(cr_state)

            READ_FIRST_DATA:begin  // The first data should put it in data_tmp[31]! 
                if(data_valid) begin
                    data_tmp[counter] <= data; 
                    counter <= (counter==11'd0)? 11'd0 : counter - 11'd1; 
                end
            end

            READ_FIRST_Y:begin
                fir_valid <= 1;
                data_tmp[0] <= data;
                counter <= counter + 1;
                for(i=0 ; i<=30 ; i=i+1)begin
                    data_tmp[i+1] <= data_tmp[i];
                end
                if(fir_valid && counter<=16)begin
                    fir_y[counter-1] <= { {16{fir_d[15]}}, fir_d } ; 
                end
                else if(fir_valid)begin
                    fir_y[15] <= { {16{fir_d[15]}}, fir_d};
                    for(i=0 ; i<=14 ; i=i+1)begin
                        fir_y[i] <= fir_y[i+1];
                    end
                end
                fft_valid <= (counter[3:0]==4'd0 && counter!=0)? 1 : 0;
                done <= (counter[3:0]==4'd1 && counter!=1)? 1 : 0;



                // 計算freq 
            end

        endcase
    end
end


always@(*)begin

    case(cr_state)

        READ_FIRST_DATA:begin
            nt_state = (counter==0)? READ_FIRST_Y : READ_FIRST_DATA;
        end

        READ_FIRST_Y:begin
            nt_state = READ_FIRST_Y;
        end

    endcase
    
end



endmodule


