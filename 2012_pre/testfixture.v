`timescale 1ns/1ns

`define CYCLE 10
`define SDFFILE  "NFC_syn.sdf"
`include "./flash_a.v"
`include "./flash_b.v"

`define EXPECT "./p2_mem_goal.dat"
`ifdef p1
  `define EXPECT "./p1_mem_goal.dat"
`endif

`ifdef p2
  `define EXPECT "./p2_mem_goal.dat"
`endif


module test;

  reg  clk, rst;
  wire done;
  wire [7:0] f_io_a;
  wire f_cle_a, f_ale_a, f_ren_a, f_wen_a, f_rb_a;
  wire [7:0] f_io_b;
  wire f_cle_b, f_ale_b, f_ren_b, f_wen_b, f_rb_b;
  integer  out_mem [0:262143]; 
  
  reg [18:0] k;
  reg [8:0] x;
  integer n, i, err, y;

  parameter duty = `CYCLE / 2;

  NFC top(.clk(clk), 
          .rst(rst), 
          .done(done),
          .F_IO_A(f_io_a), 
          .F_CLE_A(f_cle_a), 
          .F_ALE_A(f_ale_a), 
          .F_REN_A(f_ren_a), 
          .F_WEN_A(f_wen_a), 
          .F_RB_A(f_rb_a),
          .F_IO_B(f_io_b), 
          .F_CLE_B(f_cle_b), 
          .F_ALE_B(f_ale_b), 
          .F_REN_B(f_ren_b), 
          .F_WEN_B(f_wen_b), 
          .F_RB_B(f_rb_b));

  flash_a fa(.IO7(f_io_a[7]), 
           .IO6(f_io_a[6]), 
           .IO5(f_io_a[5]), 
           .IO4(f_io_a[4]), 
           .IO3(f_io_a[3]), 
           .IO2(f_io_a[2]), 
           .IO1(f_io_a[1]), 
           .IO0(f_io_a[0]), 
           .CLE(f_cle_a), 
           .ALE(f_ale_a), 
           .CENeg(1'b0), 
           .RENeg(f_ren_a), 
           .WENeg(f_wen_a), 
           .R(f_rb_a) );
		   
  flash_b fb(.IO7(f_io_b[7]), 
           .IO6(f_io_b[6]), 
           .IO5(f_io_b[5]), 
           .IO4(f_io_b[4]), 
           .IO3(f_io_b[3]), 
           .IO2(f_io_b[2]), 
           .IO1(f_io_b[1]), 
           .IO0(f_io_b[0]), 
           .CLE(f_cle_b), 
           .ALE(f_ale_b), 
           .CENeg(1'b0), 
           .RENeg(f_ren_b), 
           .WENeg(f_wen_b), 
           .R(f_rb_b) );

		   
  initial begin
    `ifdef FSDB
      $fsdbDumpfile("NFC.fsdb");
      $fsdbDumpvars;
      //$fsdbDumpMDA;
    `endif

    `ifdef SDF
      $sdf_annotate(`SDFFILE, top);
    `endif

    $readmemh (`EXPECT, out_mem);
  end

  initial begin
    clk = 1'b0;
    rst = 1'b0;
    n = 0;
    err = 0;
    #3
      rst = 1'b1;
    #15
      rst = 1'b0;
  end

  always #duty clk = ~clk;

always @(posedge done) 
begin
   for(k=0;k<262144;k=k+1)
         if( fb.Mem[k] !== out_mem[k]) 
		begin
			x=k/512;
         	$display("ERROR at page %d  address %h   :   output %h != expect %h",x , k, fb.Mem[k], out_mem[k]);
         	err = err + 1 ;
		end 
         else
			begin
			y=k%512;
			x=k/512;
			if( y == 0)
				begin
					//$display("page %d data have been generated successfully!", x);
					err=err; 
				end
			else
					err=err;
			end
        begin
	if (err == 0)  begin
	            $display("All data have been generated successfully!\n");
	            $display("-------------------PASS-------------------\n");
		    $finish;
	         end
	         else begin
	            $display("There are %d errors!\n", err);
	            $display("---------------------------------------------\n");
		    $finish;
         	      end
	
	end
end

endmodule
