`timescale 1ns/10ps
`define CYCLE_TIME      15.0 
`define SDFFILE    "./Bicubic_syn.sdf"
`define MAX_CYCLE_PER_PATTERN  50000
`define PLOT_IMG
`define USECOLOR 
//`define P1


module testfixture();
integer fd;
string line;

integer patnum;

reg CLK = 0;
reg RST = 1;
reg [6:0] V0;
reg [6:0] H0;
reg [4:0] SW;
reg [4:0] SH;
reg [5:0] TW;
reg [5:0] TH;
wire  DONE;

Bicubic u_Bicubic(
.CLK(CLK),
.RST(RST),
.V0(V0),
.H0(H0),
.SW(SW),
.SH(SH),
.TW(TW),
.TH(TH),
.DONE(DONE));

`ifdef SDF
    initial $sdf_annotate(`SDFFILE, u_Bicubic);
`endif

always begin #(`CYCLE_TIME/2) CLK = ~CLK; end

//initial begin
//    $fsdbDumpfile("Bicubic.fsdb");
//    $fsdbDumpvars();
//    $fsdbDumpMDA;
//end

initial begin
    $dumpvars();
    $dumpfile("Bicubic.vcd");
end

`ifdef P1
    string PAT [1] = {"pattern1"};
    parameter pat_number = 1;
`elsif P2
    string PAT [1] = {"pattern2"};
    parameter pat_number = 1;
`elsif P3
    string PAT [1] = {"pattern3"};
    parameter pat_number = 1;
`else
    string PAT [3] = {"pattern1","pattern2","pattern3"};
    parameter pat_number = 3;
`endif

parameter ST_RESET=0, ST_PATTERN=1, ST_RUN=2, ST_RETURN=3;

reg [1:0] state;
reg unsigned [1:0] rst_count;
int pat_n;
reg [30:0] cycle_pat=0;


initial begin
    state <= ST_RESET;
    rst_count <= 0;
    pat_n <=0;
    $timeformat(-9,2," ns",20);
end

string pat_name[pat_number];
integer pH0[pat_number];
integer pV0[pat_number];
integer pSW[pat_number];
integer pSH[pat_number];
integer pTW[pat_number];
integer pTH[pat_number];
integer golden1[pat_number][1000];
integer golden2[pat_number][1000];


integer i;
integer j;
integer charcount;
integer freturn;

initial begin
    for(i=0;i<pat_number;i=i+1) begin
        //$display ("Pattern%1d %s",i+1,PAT[i]);
        fd = $fopen(PAT[i],"r");
        if (fd == 0) begin
            $display ("Failed open %s",PAT[i]);
            $finish;
        end
        else begin
            charcount = $fgets (line, fd);
            while(charcount > 0) begin: READ_PATTERN
                while((line == "\n") || (line.substr(1, 2) == "//")) charcount = $fgets (line, fd);
                if(charcount == 0 ) disable READ_PATTERN ;
                if( line.substr(0, 11) == "pattern_name") begin
                    freturn= $sscanf(line, "pattern_name %s",pat_name[i]);
                    //$display("PATTERN%1d, pattern_name= %s",i+1,pat_name[i]);
                    j=0;
                end
                else if ( line.substr(0, 4) == "H0 V0") begin
                    freturn = $sscanf(line,"H0 V0 %d %d",pH0[i],pV0[i]);
                end
                else if ( line.substr(0, 4) == "SW SH") begin
                    freturn = $sscanf(line,"SW SH %d %d",pSW[i],pSH[i]);
                end
                else if ( line.substr(0, 4) == "TW TH") begin
                    freturn = $sscanf(line,"TW TH %d %d",pTW[i],pTH[i]);
                end
                else begin
                    if (j < pTW[i]*pTH[i]) begin
                        freturn = $sscanf(line,"%d",golden1[i][j]);
                    end
                    else begin
                        freturn = $sscanf(line,"%d",golden2[i][j-pTW[i]*pTH[i]]);
                    end
                    j=j+1;
                end
                charcount = $fgets (line, fd);
            end
        end
        $fclose(fd);
    end
end


integer wait_done;
integer error_pixels;
integer total_error_pixels;
//initial RST =0;
assign H0 = pH0[pat_n];
assign V0 = pV0[pat_n];
assign SW = pSW[pat_n];
assign SH = pSH[pat_n];
assign TW = pTW[pat_n];
assign TH = pTH[pat_n];

reg [7:0] pv;
integer idx;
always @(posedge CLK ) begin
    case(state)
        ST_RESET: begin
            if (rst_count == 2) begin
                #1 RST <= 1'b0;
                rst_count <=0;
                state <=ST_PATTERN;
                total_error_pixels =0;
//$display("RESET");
            end 
            else begin
                #1 RST <= 1'b1;
                rst_count <= rst_count+1;
                wait_done<=0;
            end
        end
        ST_PATTERN: begin
//$display("ST_PATTERN");
            if(DONE == 0) begin 
                    state <= ST_RUN;
                    cycle_pat <= 0;
                    $display("== PATTERN %s",pat_name[pat_n]);
            end
            else begin
                if(DONE === 1'bx) begin
                    $display("\n%10t , ERROR, DONE is in unknown state. Simlation terminated\n",$time);
                    $finish;
                end
                else begin
                    #1;
                    $display("%10t , please pull down signal DONE",$time);
                    wait_done <= wait_done+1;
                    if(wait_done >10) begin
                        $display("\n%t , ERROR, please pull down signal DONE. Simlation terminated\n",$time);
                        $finish;
                    end
                end
            end
        end
        ST_RUN: begin
//$display("RUN");
            if(DONE == 0) begin 
                cycle_pat<=cycle_pat+1;
                if (cycle_pat > `MAX_CYCLE_PER_PATTERN) begin
                    $display("== PATTERN %s",pat_name[pat_n]);
                    $display("-- Max cycle pre pattern reached.");
                    $display("-- You can modify MAX_CYCLE_PER_PATTERN in tb.v if needed.");
                    $display("-- Please raise DONE signal after completion");
                    $display("-- Simulation terminated");
                    $finish;
                end
            end
            else begin
                //$display("== PATTERN %s",PAT[pat_n]);
                score(error_pixels);
                total_error_pixels = total_error_pixels + error_pixels;
                if (pat_n < pat_number-1) begin
                    pat_n<=pat_n+1;
                    state <= ST_PATTERN;
                end
                else begin
                 $display ("");
                 $display ("********************************");
                 $display ("**   Finish Simulation    ");
                 $display ("**   Error pixels:     %4d ",total_error_pixels);
                 $display ("**   Simulation time:  %0t  ",$time);
                 $display ("********************************");
                 $finish;
                end
            end
        end
        default: begin
        end
    endcase
end


initial begin
    $display("*******************************");
    $display("** Simulation Start          **");
    $display("*******************************");
end

task score;
    output integer error_pixels;
    //$display("== PATTERN %s",pat_name[pat_n]);
    error_pixels=0;
    `ifdef PLOT_IMG
    $display("---- orgin (%3d , %3d), size %3d x %3d",H0,V0,SW,SH);
    `ifdef USECOLOR
    $write("  ");
    for (i=0;i<SW;i=i+1) begin
            $write("%c[1;34m %2d%c[0m",27,i,27);
    end
    $write("\n");
    `endif
    for(j=0;j<SH;j=j+1) begin
        `ifdef USECOLOR
            $write("%c[1;34m%2d%c[0m",27,j,27);
        `endif
        for (i=0;i<SW;i=i+1) begin
            idx=(j+V0)*100+i+H0;
            pv=u_Bicubic.u_ImgROM.mem[idx];
            $write(" %2x",pv);
        end
        $write("\n");
    end
    $display("---- resize %3d x %3d",TW,TH);
    `ifdef USECOLOR
    $write("  ");
    for (i=0;i<TW;i=i+1) begin
            $write("%c[1;34m %2d%c[0m",27,i,27);
    end
    $write("\n");
    `endif
    for(j=0;j<TH;j=j+1) begin
        `ifdef USECOLOR
            $write("%c[1;34m%2d%c[0m",27,j,27);
        `endif
        for (i=0;i<TW;i=i+1) begin
            idx=j*TW+i;
            pv=u_Bicubic.u_ResultSRAM.mem[idx];
            if ((pv === golden1[pat_n][idx]) || (pv === golden2[pat_n][idx])) begin
                $write(" %2x",pv);
                //$write(" %2x",golden1[pat_n][idx]);
            end
            else begin
                `ifdef USECOLOR
                $write("%c[1;31m %2x%c[0m",27,pv,27);
                `else
                $write(">%2x",pv);
                `endif
                error_pixels=error_pixels+1;
            end
        end
        $write("\n");
    end
    $display("---- error count %d",error_pixels);

    `endif
endtask

endmodule

