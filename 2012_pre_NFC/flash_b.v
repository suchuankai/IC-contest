`timescale 1 ns/1 ns

module flash_b
 (
    IO7,
    IO6,
    IO5,
    IO4,
    IO3,
    IO2,
    IO1,
    IO0,
    CLE,
    ALE,
    CENeg,
    RENeg,
    WENeg,
    R
 );

////////////////////////////////////////////////////////////////////////
// Port / Part Pin Declarations
////////////////////////////////////////////////////////////////////////
    inout  IO7;
    inout  IO6;
    inout  IO5;
    inout  IO4;
    inout  IO3;
    inout  IO2;
    inout  IO1;
    inout  IO0;
    input  CLE;
    input  ALE;
    input  CENeg;
    input  RENeg;
    input  WENeg;
    output R;

// interconnect path delay signals

    wire  IO7_ipd;
    wire  IO6_ipd;
    wire  IO5_ipd;
    wire  IO4_ipd;
    wire  IO3_ipd;
    wire  IO2_ipd;
    wire  IO1_ipd;
    wire  IO0_ipd;

    wire [7 : 0] A;
    assign A = {IO7_ipd,
                IO6_ipd,
                IO5_ipd,
                IO4_ipd,
                IO3_ipd,
                IO2_ipd,
                IO1_ipd,
                IO0_ipd};

    wire [7 : 0 ] DIn;
    assign DIn = {IO7_ipd,
                  IO6_ipd,
                  IO5_ipd,
                  IO4_ipd,
                  IO3_ipd,
                  IO2_ipd,
                  IO1_ipd,
                  IO0_ipd};

    wire [7 : 0 ] DOut;
    assign DOut = {IO7,
                   IO6,
                   IO5,
                   IO4,
                   IO3,
                   IO2,
                   IO1,
                   IO0};

    wire  CLE_ipd;
    wire  ALE_ipd;
    wire  CENeg_ipd;
    wire  RENeg_ipd;
    wire  WENeg_ipd;

//  internal delays

    reg PROG_in;
    reg PROG_out;
    reg BERS_in;
    reg BERS_out;
    reg TR_in;
    reg TR_out;

    reg [7 : 0] DOut_zd;

    wire  IO7_Pass;
    wire  IO6_Pass;
    wire  IO5_Pass;
    wire  IO4_Pass;
    wire  IO3_Pass;
    wire  IO2_Pass;
    wire  IO1_Pass;
    wire  IO0_Pass;

    reg [7 : 0] DOut_Pass;
    assign {IO7_Pass,
            IO6_Pass,
            IO5_Pass,
            IO4_Pass,
            IO3_Pass,
            IO2_Pass,
            IO1_Pass,
            IO0_Pass } = DOut_Pass;

    reg R_zd = 1'b0;

    parameter MaxData        = 8'hFF;
    parameter BlockNum       = 127;
    parameter BlockSize      = 3;
    parameter PageNum        = 12'h1FF;
    parameter PageSize       = 511;

     // powerup
    reg PoweredUp       =1'b0;
    reg reseted         =1'b0;

    // control signals
    reg TRANSFER        =1'b0;//transfer to read buffer active
    reg INTCE           =1'b0;
    reg ERS_ACT         =1'b0;
    reg PRG_ACT         =1'b0;
    reg CPY_ACT         =1'b0;
    reg RSTSTART        =1'b0;
    reg RSTDONE         =1'b0;
    reg NEXT_PAGE       =1'b0;
    reg LAST_PAGE       =1'b0;

    reg write           =1'b0;
    reg read            =1'b0;

    integer Seq_rd_enable  ;
    integer CE_int_enable  ;

     // 8 bit Address
    integer AddrCom          ;
     // Address within page
    integer Address          ;      // 0 - Pagesize
     // Page Number
    integer PageAddr         = -1;  //-1 - PageNum
     // Block Number
    integer BlockAddr        = -1;  //-1 - BlockNum

     //Data
    integer Data             ;      //-1 - MaxData

         // program control signals
    integer WrBuffData[0:PageSize+1+PageSize];
    integer WrBuffStartAddr;
    integer WrBuffEndAddr;
    integer WrBuffBlock;
    integer WrBuffPage;
    reg WrPlane = 0 ;
    integer WrAddr          ;     // -1  - Pagesize +1
    integer WrPage          ;     //  0  - PageNum
    integer WrCnt           =-1;  // -1  - 3

        //erase control signals
    integer ErsQueue   ;
    reg ErsPlane = 0 ;
    integer ErsCnt          = -1;//-1 - 3

        //copy control signals
    reg CpyPlaneD = 0 ;
    reg CpyPlaneS = 0 ;
    integer CpyCntD  = 1;
    integer CpyCntS  = 1;

     // Mem(Page)(Address)
    integer Mem[0:(PageSize+1)*PageNum + PageSize];

    // timing check violation
    reg Viol    = 1'b0;

    // initial
    integer i,j;

    //Bus Cycle Decode
    reg[7:0] A_tmp          ;
    reg[7:0] D_tmp          ;

     //RstTime
    time duration;

    //Functional
    reg[7:0] Status         = 8'hC0;
    reg[7:0] temp           ;
    reg oe = 1'b0;
    integer Page     ; // 0 - PageNum
    integer Blck     ; // 0 - BlockNum
    //integer Plane    ; // 0 - PlaneNum

    //TPD_DATA
    time REDQ_t;
    time CEDQ_t;
    time RENeg_event;
    time CENeg_event;
    reg FROMRE;
    reg FROMCE;
    integer   REDQ_01;
    integer   CEDQ_01;
    integer   REDQz_01;
    integer   CEDQz_01;
    integer   WER_01;

    reg[7:0] TempData;
    integer  Model_q;

    event oe_event;

    // states
    reg [3:0] current_state;
    reg [3:0] next_state;

    reg [1:0] RD_MODE;
    reg [1:0] STATUS_MODE;

    // FSM states
    parameter IDLE      = 4'h0;
    parameter RESET     = 4'h1;
    parameter RD_A0     = 4'h2;
    parameter RD_A1     = 4'h3;
    parameter BUFF_TR   = 4'h4;
    parameter RD        = 4'h5;
    parameter PREL_PRG  = 4'h6;
    parameter PRG_A0    = 4'h7;
    parameter PRG_A1    = 4'h8;
    parameter DATA_PRG  = 4'h9;
    parameter PGMS      = 4'hA;
    parameter RDY_PRG   = 4'hB;
    parameter PREL_ERS  = 4'hC;
    parameter ERS_A1    = 4'hD;
    parameter ERS_A2    = 4'hE;
    parameter BERS_EXEC = 4'hF;

    //read mode
    parameter READ_A   = 4'd0;
    parameter READ_B   = 4'd1;

    //status mode
    parameter NONE        = 4'd0;
    parameter STAT        = 4'd1;

///////////////////////////////////////////////////////////////////////////////
//Interconnect Path Delay Section
///////////////////////////////////////////////////////////////////////////////
    buf   (IO7_ipd, IO7 );
    buf   (IO6_ipd, IO6 );
    buf   (IO5_ipd, IO5 );
    buf   (IO4_ipd, IO4 );
    buf   (IO3_ipd, IO3 );
    buf   (IO2_ipd, IO2 );
    buf   (IO1_ipd, IO1 );
    buf   (IO0_ipd, IO0 );

    buf   (CLE_ipd  , CLE );
    buf   (ALE_ipd  , ALE );
    buf   (CENeg_ipd, CENeg );
    buf   (RENeg_ipd, RENeg );
    buf   (WENeg_ipd, WENeg );

///////////////////////////////////////////////////////////////////////////////
// Propagation  delay Section
///////////////////////////////////////////////////////////////////////////////
    nmos   (IO7, IO7_Pass, 1);
    nmos   (IO6, IO6_Pass, 1);
    nmos   (IO5, IO5_Pass, 1);
    nmos   (IO4, IO4_Pass, 1);
    nmos   (IO3, IO3_Pass, 1);
    nmos   (IO2, IO2_Pass, 1);
    nmos   (IO1, IO1_Pass, 1);
    nmos   (IO0, IO0_Pass, 1);
    nmos   (R,   R_zd,     1);

    wire deg;

 // Needed for TimingChecks

    wire Check_IO0_WENeg;
    assign Check_IO0_WENeg    =  ~CENeg;

    wire Check_IO0_CENeg;
    assign Check_IO0_CENeg    =  ~RENeg;

    wire Check_IO0_RENeg;
    assign Check_IO0_RENeg    =  ~WENeg;

    wire Check_CENeg_posedge;
    assign Check_CENeg_posedge = TRANSFER;

specify

    // they can be taken from SDF file
    // With all the other delays real delays would be taken from SDF file

    specparam       tpd_CENeg_IO0      = 1;//tcea, tchz
    specparam       tpd_RENeg_IO0      = 3;//trea, trhZ
    specparam       tpd_WENeg_R        = 10;//twb
    specparam       tpd_RENeg_R        = 10;//trb
    specparam       tpd_CENeg_R        = 1;//tcry

    //tsetup values
    specparam       tsetup_CLE_WENeg   = 0;//tcls edge \
    specparam       tsetup_CENeg_WENeg = 1;//tcs edge \
    specparam       tsetup_ALE_WENeg   = 0;//tals edge \
    specparam       tsetup_IO0_WENeg   = 2;//tds edge /
    specparam       tsetup_ALE_RENeg   = 5;//tclr edge \
    specparam       tsetup_CLE_RENeg   = 5;//tar edge \
    specparam       tsetup_WENeg_RENeg = 6;//twhr edge \

    //thold values
    specparam       thold_CLE_WENeg    = 1;//tclh edge /
    specparam       thold_CENeg_WENeg  = 1;//tch edge /
    specparam       thold_ALE_WENeg    = 1;//talh edge /
    specparam       thold_IO0_WENeg    = 1;//tdh edge /

    //tpw values
    specparam       tpw_WENeg_negedge  = 3;//twp
    specparam       tpw_WENeg_posedge  = 1;//twh
    specparam       tpw_RENeg_negedge  = 1;//trp
    specparam       tpw_RENeg_posedge  = 1;//treh
    specparam       tpw_CENeg_posedge  = 1;//tceh
    specparam       tperiod_WENeg      = 5;//twc
    specparam       tperiod_RENeg      = 5;//trc

    //Other hold timings
    specparam thold_IO0_RENeg          = 1;//toh
    specparam thold_IO0_CENeg          = 1;//toh

    //tdevice values: values for internal delays
    // Program Operation
    specparam       tdevice_PROG       =   200;  //200ns
    //Block Erase Operation
    specparam       tdevice_BERS       =   1000;  //1us
    //Data transfer time
    specparam       tdevice_TR         =   15;  //150ns

///////////////////////////////////////////////////////////////////////////////
// Input Port  Delays  don't require Verilog description
///////////////////////////////////////////////////////////////////////////////
// Path delays                                                               //
///////////////////////////////////////////////////////////////////////////////

// specify transport delay for Data output paths
    specparam       PATHPULSE$CENeg$IO0     =   (0);
    specparam       PATHPULSE$CENeg$IO1     =   (0);
    specparam       PATHPULSE$CENeg$IO2     =   (0);
    specparam       PATHPULSE$CENeg$IO3     =   (0);
    specparam       PATHPULSE$CENeg$IO4     =   (0);
    specparam       PATHPULSE$CENeg$IO5     =   (0);
    specparam       PATHPULSE$CENeg$IO6     =   (0);
    specparam       PATHPULSE$CENeg$IO7     =   (0);

    specparam       PATHPULSE$RENeg$IO0     =   (0);
    specparam       PATHPULSE$RENeg$IO1     =   (0);
    specparam       PATHPULSE$RENeg$IO2     =   (0);
    specparam       PATHPULSE$RENeg$IO3     =   (0);
    specparam       PATHPULSE$RENeg$IO4     =   (0);
    specparam       PATHPULSE$RENeg$IO5     =   (0);
    specparam       PATHPULSE$RENeg$IO6     =   (0);
    specparam       PATHPULSE$RENeg$IO7     =   (0);

// Data ouptut paths
    if (FROMCE)
            ( CENeg => IO0 ) = tpd_CENeg_IO0;
    if (FROMCE)
            ( CENeg => IO1 ) = tpd_CENeg_IO0;
    if (FROMCE)
            ( CENeg => IO2 ) = tpd_CENeg_IO0;
    if (FROMCE)
            ( CENeg => IO3 ) = tpd_CENeg_IO0;
    if (FROMCE)
            ( CENeg => IO4 ) = tpd_CENeg_IO0;
    if (FROMCE)
            ( CENeg => IO5 ) = tpd_CENeg_IO0;
    if (FROMCE)
            ( CENeg => IO6 ) = tpd_CENeg_IO0;
    if (FROMCE)
            ( CENeg => IO7 ) = tpd_CENeg_IO0;

    if (FROMRE)
            ( RENeg => IO0 ) = tpd_RENeg_IO0;
    if (FROMRE)
            ( RENeg => IO1 ) = tpd_RENeg_IO0;
    if (FROMRE)
            ( RENeg => IO2 ) = tpd_RENeg_IO0;
    if (FROMRE)
            ( RENeg => IO3 ) = tpd_RENeg_IO0;
    if (FROMRE)
            ( RENeg => IO4 ) = tpd_RENeg_IO0;
    if (FROMRE)
            ( RENeg => IO5 ) = tpd_RENeg_IO0;
    if (FROMRE)
            ( RENeg => IO6 ) = tpd_RENeg_IO0;
    if (FROMRE)
            ( RENeg => IO7 ) = tpd_RENeg_IO0;

// R output paths
    (CENeg => R) = tpd_CENeg_R;

    if ( ~CENeg )
        ( WENeg =>  R ) = tpd_WENeg_R;

    if ( ~CENeg )
        ( RENeg =>  R ) = tpd_RENeg_R;

////////////////////////////////////////////////////////////////////////////////
// Timing Violation                                                           //
////////////////////////////////////////////////////////////////////////////////

        $setup ( IO0 ,posedge WENeg &&& Check_IO0_WENeg ,tsetup_IO0_WENeg,Viol);
        $setup ( IO1 ,posedge WENeg &&& Check_IO0_WENeg ,tsetup_IO0_WENeg,Viol);
        $setup ( IO2 ,posedge WENeg &&& Check_IO0_WENeg ,tsetup_IO0_WENeg,Viol);
        $setup ( IO3 ,posedge WENeg &&& Check_IO0_WENeg ,tsetup_IO0_WENeg,Viol);
        $setup ( IO4 ,posedge WENeg &&& Check_IO0_WENeg ,tsetup_IO0_WENeg,Viol);
        $setup ( IO5 ,posedge WENeg &&& Check_IO0_WENeg ,tsetup_IO0_WENeg,Viol);
        $setup ( IO6 ,posedge WENeg &&& Check_IO0_WENeg ,tsetup_IO0_WENeg,Viol);
        $setup ( IO7 ,posedge WENeg &&& Check_IO0_WENeg ,tsetup_IO0_WENeg,Viol);

        $hold ( posedge WENeg &&& Check_IO0_WENeg , IO0 ,thold_IO0_WENeg, Viol);
        $hold ( posedge WENeg &&& Check_IO0_WENeg , IO1 ,thold_IO0_WENeg, Viol);
        $hold ( posedge WENeg &&& Check_IO0_WENeg , IO2 ,thold_IO0_WENeg, Viol);
        $hold ( posedge WENeg &&& Check_IO0_WENeg , IO3 ,thold_IO0_WENeg, Viol);
        $hold ( posedge WENeg &&& Check_IO0_WENeg , IO4 ,thold_IO0_WENeg, Viol);
        $hold ( posedge WENeg &&& Check_IO0_WENeg , IO5 ,thold_IO0_WENeg, Viol);
        $hold ( posedge WENeg &&& Check_IO0_WENeg , IO6 ,thold_IO0_WENeg, Viol);
        $hold ( posedge WENeg &&& Check_IO0_WENeg , IO7 ,thold_IO0_WENeg, Viol);

        $hold ( posedge CENeg &&& Check_IO0_CENeg , IO0 ,thold_IO0_CENeg, Viol);
        $hold ( posedge CENeg &&& Check_IO0_CENeg , IO1 ,thold_IO0_CENeg, Viol);
        $hold ( posedge CENeg &&& Check_IO0_CENeg , IO2 ,thold_IO0_CENeg, Viol);
        $hold ( posedge CENeg &&& Check_IO0_CENeg , IO3 ,thold_IO0_CENeg, Viol);
        $hold ( posedge CENeg &&& Check_IO0_CENeg , IO4 ,thold_IO0_CENeg, Viol);
        $hold ( posedge CENeg &&& Check_IO0_CENeg , IO5 ,thold_IO0_CENeg, Viol);
        $hold ( posedge CENeg &&& Check_IO0_CENeg , IO6 ,thold_IO0_CENeg, Viol);
        $hold ( posedge CENeg &&& Check_IO0_CENeg , IO7 ,thold_IO0_CENeg, Viol);

        $hold ( posedge RENeg &&& Check_IO0_RENeg , IO0 ,thold_IO0_RENeg, Viol);
        $hold ( posedge RENeg &&& Check_IO0_RENeg , IO1 ,thold_IO0_RENeg, Viol);
        $hold ( posedge RENeg &&& Check_IO0_RENeg , IO2 ,thold_IO0_RENeg, Viol);
        $hold ( posedge RENeg &&& Check_IO0_RENeg , IO3 ,thold_IO0_RENeg, Viol);
        $hold ( posedge RENeg &&& Check_IO0_RENeg , IO4 ,thold_IO0_RENeg, Viol);
        $hold ( posedge RENeg &&& Check_IO0_RENeg , IO5 ,thold_IO0_RENeg, Viol);
        $hold ( posedge RENeg &&& Check_IO0_RENeg , IO6 ,thold_IO0_RENeg, Viol);
        $hold ( posedge RENeg &&& Check_IO0_RENeg , IO7 ,thold_IO0_RENeg, Viol);

        $setup ( CLE    ,negedge WENeg  ,tsetup_CLE_WENeg   , Viol);
        $setup ( ALE    ,negedge WENeg  ,tsetup_ALE_WENeg   , Viol);
        $setup ( CENeg  ,negedge WENeg  ,tsetup_CENeg_WENeg , Viol);
        $setup ( CLE    ,negedge RENeg  ,tsetup_CLE_RENeg   , Viol);
        $setup ( ALE    ,negedge RENeg  ,tsetup_ALE_RENeg   , Viol);
        $setup ( WENeg  ,negedge RENeg  ,tsetup_WENeg_RENeg , Viol);

        $hold  ( posedge WENeg  ,CLE    ,thold_CLE_WENeg    , Viol);
        $hold  ( posedge WENeg  ,ALE    ,thold_ALE_WENeg    , Viol);
        $hold  ( posedge WENeg  ,CENeg  ,thold_CENeg_WENeg  , Viol);

        $width (posedge CENeg &&& Check_CENeg_posedge , tpw_CENeg_posedge);
        $width (posedge WENeg                         , tpw_WENeg_posedge);
        $width (negedge WENeg                         , tpw_WENeg_negedge);
        $width (posedge RENeg                         , tpw_RENeg_posedge);
        $width (negedge RENeg                         , tpw_RENeg_negedge);
        $period(negedge WENeg                         , tperiod_WENeg);
        $period(posedge WENeg                         , tperiod_WENeg);
        $period(negedge RENeg                         , tperiod_RENeg);
        $period(posedge RENeg                         , tperiod_RENeg);

    endspecify

     //Used as wait periods
    time       poweredupT      = 10; // 10ns
    time       INTCET          = 1;   // 1ns
    time       RstErsT         = 500;// 500ns
    time       RstProgT        = 20; // 20ns
    time       RstReadT        = 10;  // 10ns

////////////////////////////////////////////////////////////////////////////////
// Main Behavior Block                                                        //
////////////////////////////////////////////////////////////////////////////////

 reg deq;
    //////////////////////////////////////////////////////////
    //          Output Data Gen
    //////////////////////////////////////////////////////////

   always @(DOut_zd)
   begin : OutputZGen1
        if (DOut_zd[0] === 1'bz)
        begin
            CEDQ_t = CENeg_event  + CEDQz_01;
            REDQ_t = RENeg_event  + REDQz_01;
            FROMRE = 1'b1;
            FROMCE = ((CEDQ_t < REDQ_t) && (CEDQ_t > $time)) ||(REDQ_t < $time);
            if ( ~ FROMCE)
            begin
                TempData   = DOut_zd;
                #( REDQz_01 - CEDQz_01 ) DOut_Pass  =  TempData;
            end
            else
                DOut_Pass = DOut_zd;
        end
    end

    always @(DOut_zd)
    begin : OutputGen
        if (DOut_zd[0] !== 1'bz)
        begin
            disable OutputZGen1;
            CEDQ_t = CENeg_event  + CEDQ_01;
            REDQ_t = RENeg_event  + REDQ_01;
            FROMCE = 1'b1;
            FROMRE = ((REDQ_t >= CEDQ_t) && ( REDQ_t >= $time));
            DOut_Pass = DOut_zd;
        end
    end

   always @(posedge CENeg)
   begin : OutputZGen2
        CENeg_event = $time;
        CEDQ_t = CENeg_event  + CEDQz_01;
        REDQ_t = RENeg_event  + REDQz_01;
        FROMCE = ((CEDQ_t < REDQ_t) && (CEDQ_t > $time));
        FROMRE = ~FROMCE;
        if (FROMCE)
        begin
            disable OutputZGen1;
            DOut_Pass <= 8'bz;
        end
        else
            DOut_Pass = 8'bz;
    end

    always @(DIn, DOut)
    begin
        if (DIn==DOut)
            deq=1'b1;
        else
            deq=1'b0;
    end
    // check when data is generated from model to avoid setuphold check in
    // those occasion
    assign deg=deq;

    // initialize memory and load preoload files if any
    initial
    begin: InitMemory
    integer i,j;
    integer m_mem[0:(PageSize+1)*PageNum+PageSize];
        for (i=0;i<= PageNum;i=i+1)
        begin
            for (j=0;j<= PageSize;j=j+1)
            begin
                m_mem[i*PageSize+j]=MaxData;
            end
        end

        for (i=0;i<= PageNum;i=i+1)
        begin
            for (j=0;j<= PageSize;j=j+1)
            begin
                Mem[i*(PageSize+1)+j] =m_mem[i*PageSize+j];
            end
        end
    end

    initial
    begin
        TRANSFER        =1'b0;
        INTCE           =1'b0;
        ERS_ACT         =1'b0;
        PRG_ACT         =1'b0;
        CPY_ACT         =1'b0;
        RSTSTART        =1'b0;
        RSTDONE         =1'b0;
        NEXT_PAGE       =1'b0;
        LAST_PAGE       =1'b0;
        write           =1'b0;
        read            =1'b0;

            for(j=0;j<=PageSize;j=j+1)
                WrBuffData[(PageSize+1)+j] = -1;
            WrBuffStartAddr = -1;
            WrBuffEndAddr   = -1;
            WrBuffBlock     = -1;
            WrBuffPage      = -1;
            ErsQueue        = -1;

            ErsPlane  = 1'b0;
            WrPlane   = 1'b0;
            CpyPlaneS = 1'b0;
            CpyPlaneD = 1'b0;

        current_state  = IDLE;
        next_state     = IDLE;
        RD_MODE        = READ_A;
        STATUS_MODE    = NONE;
        Status         = 8'hC0;
        CpyCntS        = 0;
        CpyCntD        = 0;
    end

     //Power Up time 10 ns;
    initial
    begin
        PoweredUp = 1'b0;
        #poweredupT  PoweredUp = 1'b1;
    end

    //Program Operation
    always @(posedge PROG_in)
    begin:ProgTime
        #(tdevice_PROG+WER_01) PROG_out = 1'b1;
    end
    always @(negedge PROG_in)
    begin
        disable ProgTime;
        PROG_out = 1'b0;
    end
    //Block Erase Operation
    always @(posedge BERS_in)
    begin : ErsTime
        #(tdevice_BERS+WER_01) BERS_out = 1'b1;
    end
    always @(negedge BERS_in)
    begin
        disable ErsTime;
        BERS_out = 1'b0;
    end
    //Data transfer time
    always @(posedge TR_in)
    begin : DataTransferTime
        #(tdevice_TR) TR_out = 1'b1;
    end
    always @(negedge TR_in)
    begin
        disable DataTransferTime;
        TR_out = 1'b0;
    end

    ////////////////////////////////////////////////////////////////////////////
    ////     obtain 'LAST_EVENT information
    ////////////////////////////////////////////////////////////////////////////
    always @(RENeg)
    begin
        RENeg_event = $time;
    end
    always @(CENeg)
    begin
        CENeg_event = $time;
    end

    ////////////////////////////////////////////////////////////////////////////
    // process for reset control and FSM state transition
    ////////////////////////////////////////////////////////////////////////////
    always @(next_state, PoweredUp)
    begin
        if (PoweredUp)
        begin
            current_state = next_state;
            reseted       = 1'b1;
        end
        else
        begin
            current_state = IDLE;
            RD_MODE       = READ_A;
            STATUS_MODE   = NONE;
            reseted       = 1'b0;
        end
    end

    //////////////////////////////////////////////////////////////////////////
    //process for generating the write and read signals
    //////////////////////////////////////////////////////////////////////////
    always @(*)// (WENeg, CENeg, RENeg)
    begin
        if (~WENeg && ~CENeg && RENeg)
            write  =  1'b1;
        else if (WENeg &&  ~CENeg && RENeg)
            write  =  1'b0;
        else
            write = 1'b0;
        if (WENeg &&  ~CENeg && ~RENeg && ~ALE && ~CLE )
            read = 1'b1;
        else if (WENeg &&  ~CENeg && RENeg && ~ALE && ~CLE )
            read = 1'b0;
        else
            read = 1'b0;
    end

    //////////////////////////////////////////////////////////////////////////
    //Latches 8 bit address on rising edge of RE#
    //Latches data on rising edge of WE#
    //////////////////////////////////////////////////////////////////////////
    always @(A)
    begin
        // sample new address or data
        if ( ~WENeg && ~CENeg )
            A_tmp    = A[7:0];
            D_tmp    = DIn[7:0];
        end

    always @( negedge WENeg)
    begin
        // sample new address or data
        if (~CENeg)
        begin
            A_tmp    = A[7:0];
            D_tmp    = DIn[7:0];
        end
    end

    always @ (posedge WENeg)
    begin
        // latch 8 bit read address
        if (ALE && ~CENeg && WENeg)
            AddrCom = A_tmp[7:0];
        // latch data
        if (~ALE && ~CENeg && RENeg)
            Data   =  D_tmp[7:0];
    end

    //////////////////////////////////////////////////////////////////////////
    // Process that controls CE interception of read operations
    //////////////////////////////////////////////////////////////////////////
    always @(posedge TRANSFER)
    begin : CEInt0
        if (CENeg)
            #INTCET INTCE = 1'b1;
    end

    always @(posedge CENeg)
    begin : CEInt1
        if (TRANSFER)
            #INTCET INTCE = 1'b1;
    end

    always @(negedge CENeg)
    begin
        disable CEInt0;
        disable CEInt1;
        INTCE = 1'b0;
    end

    ////////////////////////////////////////////////////////////////////////////
    // Timing control for the Reset Operation
    ////////////////////////////////////////////////////////////////////////////

    event rstdone_event;
    always @ (posedge reseted)
    begin
        disable rstdone_process;
        RSTDONE = 1'b1;  // reset done
    end

    always @ (posedge RSTSTART)
    begin
        if (reseted &&  RSTDONE)
        begin
            if (ERS_ACT)
                duration = RstErsT + WER_01;
            else if (PRG_ACT)
                duration = RstProgT+ WER_01;
            else
                duration = RstReadT+ WER_01;
            RSTDONE   = 1'b0;
            ->rstdone_event;
        end
    end

    always @(rstdone_event)
    begin:rstdone_process
        #duration RSTDONE = 1'b1;
    end

    ////////////////////////////////////////////////////////////////////////////
    // Main Behavior Process
    // combinational process for next state generation
    ////////////////////////////////////////////////////////////////////////////

    //WRITE CYCLE TRANSITIONS
    always @(negedge write or negedge reseted)
    begin
        if (reseted != 1'b1 )
            next_state = current_state;
        else
            case (current_state)
            IDLE :
            begin
                if (CLE  && Data==8'h00 && ~ CPY_ACT  )
                    next_state = IDLE; // READ AREA A
                else if ( CLE  && Data==8'h01 && ~ CPY_ACT  )
                    next_state = IDLE; // READ AREA B
                else if ( CLE  && Data==8'h70 && ~ CPY_ACT )
                    next_state = IDLE; // read status
                else if ( CLE  && Data==8'h80 && ~ CPY_ACT )
                    next_state = PREL_PRG;
                else if ( CLE  && Data==8'h60 && ~ CPY_ACT )
                    next_state = PREL_ERS;
                else if ( CLE  && Data==8'hFF  )
                    next_state = RESET; // reset
                else if ( ALE  && STATUS_MODE == NONE)
                    next_state = RD_A0;
            end
            RD_A0 :
            begin
                if ( ALE )
                    next_state = RD_A1;
                else if ( CLE  && Data==8'hFF  )
                    next_state = RESET; // reset
            end
            RD_A1 :
            begin
                if ( ALE )
                    next_state = BUFF_TR;
                else if ( CLE  && Data==8'hFF  )
                    next_state = RESET; // reset
            end
            BUFF_TR :
            begin
                if ( CLE  && Data==8'hFF )
                    next_state = RESET; // reset
            end
            RD :
            begin
                if ( CLE  && Data==8'h00 && ~ CPY_ACT )
                    next_state = IDLE; // READ AREA A
                else if ( CLE  && Data==8'h01 && ~ CPY_ACT )
                    next_state = IDLE; // READ AREA B
                else if ( CLE  && Data==8'h70 && ~ CPY_ACT )
                    next_state = IDLE; // read status
                else if ( CLE  && Data==8'h80 && ~ CPY_ACT )
                    next_state = PREL_PRG;
                else if ( CLE  && Data==8'h60 && ~ CPY_ACT )
                    next_state = PREL_ERS;
                else if ( CLE  && Data==8'hFF  )
                    next_state = RESET; // reset
                else if ( ALE  )
                    next_state = RD_A0;
            end
            PREL_PRG :
            begin
                if ( ALE  )
                    next_state = PRG_A0;
                else if ( CLE  && Data==8'hFF  )
                    next_state = RESET; // reset
            end
            PRG_A0 :
            begin
                if ( ALE  )
                    next_state = PRG_A1;
                else if ( CLE  && Data==8'hFF  )
                    next_state = RESET; // reset
            end
            PRG_A1 :
            begin
                if ( ALE  )
                    next_state = DATA_PRG;
                else if ( CLE  && Data==8'hFF  )
                    next_state = RESET; // reset
            end
            DATA_PRG :
            begin
                if (CLE &&(Data==8'h10 )
                        && WrAddr==WrBuffStartAddr)
                    next_state = IDLE;
                else if ( CLE  && Data==8'h10  )
                    next_state = PGMS;
                else if ( CLE  && Data==8'hFF  )
                    next_state = RESET; // reset
                else if ( ~ALE && ~CLE && WrAddr < PageSize+1 )
                    next_state = DATA_PRG; // write next word to buffer
            end
            PGMS :
            begin
                if ( CLE  && Data==8'hFF  )
                    next_state = RESET; // reset
                else if ( CLE  && Data==8'h70  )
                    next_state = PGMS; // read status
            end
            RDY_PRG :
            begin
                if ( CLE  && Data==8'h80  )
                    next_state = PREL_PRG;
                else if ( CLE  && Data==8'h70  )
                    next_state = RDY_PRG; // read status
                else if ( CLE  && Data==8'hFF  )
                    next_state = RESET; // reset
            end
            PREL_ERS :
            begin
                if ( ALE  )
                    next_state = ERS_A1;
                else if ( CLE  && Data==8'hFF  )
                    next_state = RESET; // reset
            end
            ERS_A1 :
            begin
                if ( ALE  )
                    next_state = ERS_A2;
                else if ( CLE  && Data==8'hFF  )
                    next_state = RESET; // reset
            end
            ERS_A2 :
            begin
                if ( CLE  && Data==8'h60  && ErsCnt < 3 )
                    next_state = PREL_ERS;
                else if ( CLE  && Data==8'hD0  )
                    next_state = BERS_EXEC;
                else if ( CLE  && Data==8'hFF  )
                    next_state = RESET; // reset
            end
            BERS_EXEC :
            begin
                if ( CLE  && Data==8'hFF  )
                    next_state = RESET; // reset
                else if ( CLE  && Data==8'h70  )
                    next_state = BERS_EXEC; // read status
            end
            endcase
    end

    // RESET state, RSTDONE
    always @(posedge RSTDONE)
    begin: StateGen1
        if (current_state == RESET)
            next_state = IDLE;
    end

    // BUFF_TR, TR_out
    always @(posedge TR_out)
    begin: StateGen2
        if (current_state == BUFF_TR)
            next_state = RD; // buffer transfered
    end

    // BUFF_TR, INTCE
    always @(posedge INTCE)
    begin: StateGen3
        if (current_state == BUFF_TR && CENeg)
            next_state = IDLE; // read intercepted
    end

    // RD, read negedge
    always @(negedge read)
    begin: StateGen4
        if (reseted!=1'b1)
            next_state = current_state;
        else
        begin
            if (current_state == RD && NEXT_PAGE)
                next_state <= IDLE;
        end
    end

    // PGMS, PROG_out
    always @(posedge PROG_out)
    begin: StateGen5
        if (current_state == PGMS )
        begin
            next_state = IDLE; // programming done
        end
    end

    // BERS_EXEC, BERS_out
    always @(posedge BERS_out)
    begin: StateGen7
        if (current_state == BERS_EXEC )
            next_state = IDLE;
    end

    ///////////////////////////////////////////////////////////////////////////
    //FSM Output generation and general funcionality
    ///////////////////////////////////////////////////////////////////////////

    always @(posedge read)
    begin
          ->oe_event;
    end

    always @(oe_event)
    begin
        oe = 1'b1;
        #1 oe = 1'b0;
    end

    always @( posedge oe)
    begin: Output
        case (current_state)
            IDLE :
            begin
                if ( STATUS_MODE !== NONE )
                    READ_STATUS(STATUS_MODE);
            end
            RD :
            begin
                READ_DATA(Address,PageAddr);
            end
            PGMS :
            begin
                if ( STATUS_MODE !== NONE )
                    READ_STATUS(STATUS_MODE);
            end
            RDY_PRG :
            begin
                if ( STATUS_MODE !== NONE )
                    READ_STATUS(STATUS_MODE);
            end
            BERS_EXEC :
            begin
                if ( STATUS_MODE !== NONE )
                    READ_STATUS(STATUS_MODE);
            end
        endcase
    end

    always @(negedge write)
    begin: Func0
        if ( reseted === 1'b1 )
        case (current_state)
        IDLE :
        begin
            if ( CLE && Data==8'h00 && ~CPY_ACT )
            begin
                RD_MODE = READ_A; // READ AREA A
                STATUS_MODE = NONE;
                Status  = 8'b11000000;
            end
            else if ( CLE && Data==8'h01 && ~CPY_ACT )
            begin
                RD_MODE = READ_B; // READ AREA B
                STATUS_MODE = NONE;
            end
            else if ( CLE && Data==8'h70 && ~CPY_ACT )
                STATUS_MODE = STAT; // read status
            else if ( CLE && Data==8'h80 && ~CPY_ACT )
            begin
                STATUS_MODE = NONE;
                WrCnt   = 0;
                WrPlane = 0;
                Status  = 8'b11000000;
            end
            else if ( CLE && Data==8'h60 && ~CPY_ACT )
            begin
                STATUS_MODE = NONE;
                ErsCnt= 0;
                ErsPlane= 0;
                    ErsQueue= -1;
                Status  = 8'b11000000;
            end
            else if ( CLE && Data==8'hFF )
            begin
                STATUS_MODE = NONE;
                RSTSTART  = 1'b1;
                RSTSTART  <= #1 1'b0;
                R_zd      = 1'b0;
            end
            else if ( ALE && STATUS_MODE == NONE )
            begin
                Address = AddrCom;
            end
        end
        RD_A0 :
        begin
            if ( ALE )
                Page = AddrCom;
            else if ( CLE && Data==8'hFF )
            begin
                STATUS_MODE = NONE;
                RSTSTART  = 1'b1;
                RSTSTART  <= #1 1'b0;
                R_zd      = 1'b0;
            end
        end
        RD_A1 :
        begin
            if ( ALE )
            begin
                Page = Page + ( AddrCom*12'h100);
                PageAddr  = Page;
                BlockAddr = Page / (BlockSize + 1);
                if ( CE_int_enable )
                    TRANSFER  = 1'b1;
                TR_in     = 1'b1;
                R_zd      = 1'b0;
                Status[6] = 1'b0;
            end
            else if ( CLE && Data==8'hFF )
            begin
                STATUS_MODE = NONE;
                RSTSTART  = 1'b1;
                RSTSTART  <= #1 1'b0;
                R_zd      = 1'b0;
            end
        end
        BUFF_TR :
        begin
            if ( CLE && Data==8'hFF )
            begin
                TR_in = 1'b0;
                TRANSFER    = 1'b0;
                STATUS_MODE = NONE;
                RSTSTART  = 1'b1;
                RSTSTART  <= #1 1'b0;
                R_zd      = 1'b0;
            end
        end
        RD :
        begin
            if ( CLE && Data==8'h00 && ~CPY_ACT )
            begin
                RD_MODE = READ_A; // READ AREA A
                STATUS_MODE = NONE;
            end
            else if ( CLE && Data==8'h01 && ~CPY_ACT )
            begin
                RD_MODE = READ_B; // READ AREA B
                STATUS_MODE = NONE;
            end
            else if ( CLE && Data==8'h70 && ~CPY_ACT )
            begin
                STATUS_MODE = STAT; // read status
                if ( RD_MODE == READ_B )
                    RD_MODE = READ_A;
            end
            else if ( CLE && Data==8'h80 && ~CPY_ACT )
            begin
                STATUS_MODE = NONE;
                WrCnt   = 0;
                WrPlane = 0;
                Status  = 8'b11000000;
            end
            else if ( CLE && Data==8'h60 && ~CPY_ACT )
            begin
                STATUS_MODE = NONE;
                ErsCnt= 0;
                ErsPlane= 0;
                ErsQueue= -1;
                Status  = 8'b11000000;
            end
            else if ( CLE && Data==8'h03 && CpyCntS < 4 )
            begin
                STATUS_MODE = NONE;
                CPY_ACT = 1'b1;
                Blck = Page / (BlockSize + 1);
                if (CpyCntS )
                    Status  = 8'b11000000;
                if (CpyPlaneS)
                begin
                    Status[4:0] = 4'b1111;
                    CpyPlaneS   = 4'b1111;
                    CpyPlaneD   = 4'b1111;
                        WrBuffBlock = -1;
                        WrBuffPage  = -1;
                end
                else
                begin
                    Status[1] = 1'b0;
                    CpyPlaneS= 1'b1;
                    for(i=0;i<=527;i=i+1)
                            WrBuffData[PageSize+1+i]=
                                              Mem[Page*(PageSize+1)+i];
                end
                CpyCntS =CpyCntS+1;
            end
            else if ( CLE && Data==8'hFF )
            begin
                STATUS_MODE = NONE;
                RSTSTART  = 1'b1;
                RSTSTART  <= #1 1'b0;
                R_zd      = 1'b0;
            end
            else if ( ALE )
            begin
                STATUS_MODE = NONE;
                Address = AddrCom;
                if ( RD_MODE == READ_B )
                    RD_MODE = READ_A;
            end
        end
        PREL_PRG :
        begin
            if ( ALE )
            begin
                if ( RD_MODE == READ_A )
                begin
                    WrAddr                 = AddrCom;
                    WrBuffStartAddr = AddrCom;
                end
                else if ( RD_MODE == READ_B )
                begin
                    WrAddr                 = AddrCom + 12'h100;
                    WrBuffStartAddr = AddrCom + 12'h100;
                end
            end
            else if ( CLE && Data==8'hFF )
            begin
                RSTSTART  = 1'b1;
                RSTSTART  <= #1 1'b0;
                R_zd      = 1'b0;
            end
        end
        PRG_A0 :
        begin
            if ( ALE )
                Page = AddrCom;
            else if ( CLE && Data==8'hFF )
            begin
                RSTSTART  = 1'b1;
                RSTSTART  <= #1 1'b0;
                R_zd      = 1'b0;
            end
        end
        PRG_A1 :
        begin
            if ( ALE )
                Page = Page + ( AddrCom*12'h100);
            else if ( CLE && Data==8'hFF )
            begin
                RSTSTART  = 1'b1;
                RSTSTART  <= #1 1'b0;
                R_zd      = 1'b0;
            end
        end
        DATA_PRG :
        begin
            if ( CLE && Data==8'h10
                            && WrAddr==WrBuffStartAddr )
            begin
                //do nothing
            end
            else if ( CLE && (Data==8'h10 ) )
            begin
                Blck = Page / (BlockSize + 1);
                if ( WrCnt==0 )
                begin
                    WrPage = Page % (BlockSize+1);
                end
                WrBuffEndAddr   = WrAddr-1;
                if ( RD_MODE == READ_B && WrCnt > 0 )
                begin
                    Status[1]   = 1'b1;
                    WrBuffBlock = -1;
                    WrBuffPage  = -1;
                end
                else if ( WrCnt>0 && (Page % (BlockSize+1))!==WrPage )
                begin
                    Status[1]   = 1'b1;
                    WrBuffBlock = -1;
                    WrBuffPage  = -1;
                end
                else if ( WrPlane !== 1'b0 )
                begin
                    Status[4:0] = ~(0);
                    WrPlane     = ~(0);
                        WrBuffBlock= -1;
                        WrBuffPage = -1;
                end
                else
                begin
                    Status[1]   = 1'b0;
                    WrBuffBlock = Blck;
                    WrBuffPage  = Page;
                    WrPlane = 1'b1;
                end
                PROG_in  = 1'b1;
                PRG_ACT  = 1'b0;
                PRG_ACT  <= #1 1'b1;
                R_zd     = 1'b0;
                Status[7]= 1'b1;
                Status[6]= 1'b0;
                if ( Status[1] == 1'b0 )
                    Status[0] = 1'b0;
                else
                    Status[0] = 1'b1;
            end
            else if ( CLE && Data==8'hFF )
            begin
                RSTSTART  = 1'b1;
                RSTSTART  <= #1 1'b0;
                R_zd      = 1'b0;
            end
            else if ( ~ALE && ~CLE && WrAddr < PageSize+1 )
            begin
                WrBuffData[(PageSize+1)+WrAddr] = Data;
                WrAddr = WrAddr + 1;
            end
        end
        PGMS :
        begin
            if ( CLE && Data==8'hFF )
            begin
                WrCnt   = -1;
                PROG_in = 1'b0;
                STATUS_MODE = NONE;
                RSTSTART  = 1'b1;
                RSTSTART  <= #1 1'b0;
                R_zd      = 1'b0;
            end
            else if ( CLE && Data==8'h70 )
                STATUS_MODE = STAT; // read status
        end
        RDY_PRG :
        begin
            if ( CLE && Data==8'h80 )
            begin
                STATUS_MODE = NONE;
                WrCnt = WrCnt + 1;
            end
            else if ( CLE && Data==8'h70 )
                STATUS_MODE = STAT; // read status
            else if ( CLE && Data==8'hFF )
            begin
                STATUS_MODE = NONE;
                RSTSTART  = 1'b1;
                RSTSTART  <= #1 1'b0;
                R_zd      = 1'b0;
            end
        end
        PREL_ERS :
        begin
            if ( ALE )
                Page = AddrCom;
            else if ( CLE && Data==8'hFF )
            begin
                RSTSTART  = 1'b1;
                RSTSTART  <= #1 1'b0;
                R_zd      = 1'b0;
            end
        end
        ERS_A1 :
        begin
            if ( ALE )
                Page = Page + ( AddrCom*12'h100);
            else if ( CLE && Data==8'hFF )
            begin
                RSTSTART  = 1'b1;
                RSTSTART  <= #1 1'b0;
                R_zd      = 1'b0;
            end
        end
        ERS_A2 :
        begin
            if ( CLE && Data==8'h60 && ErsCnt < 3 )
            begin
                Blck = Page / (BlockSize + 1);
                if ( ErsPlane !== 1'b0 )
                begin
                    Status[1:0] = ~(0);
                    ErsPlane    = ~(0);
                        ErsQueue= -1;
                end
                else
                begin
                    Status[1]  = 1'b0;
                    ErsQueue = Blck;
                    ErsPlane  = 1'b1;
                end
                ErsCnt <= #1(ErsCnt + 1);
            end
            else if ( CLE && Data==8'hD0 )
            begin
                Blck = Page / (BlockSize + 1);
                if ( ErsPlane !== 1'b0 )
                begin
                    Status[1:0] = ~(0);
                    ErsPlane    = ~(0);
                        ErsQueue= -1;
                end
                else
                begin
                    Status[1]  = 1'b0;
                    ErsQueue = Blck;
                    ErsPlane  = 1'b1;
                end
                BERS_in = 1'b1;
                ERS_ACT = 1'b0;
                ERS_ACT <= #1 1'b1;
                R_zd    = 1'b0;
                Status[7] = 1'b1;
                Status[6] = 1'b0;
                if ( Status [1] == 1'b0 )
                    Status[0] = 1'b0;
                else
                    Status[0] = 1'b1;
            end
            else if ( CLE && Data==8'hFF )
            begin
                ErsCnt    = -1;
                RSTSTART  = 1'b1;
                RSTSTART  <= #1 1'b0;
                R_zd      = 1'b0;
            end
        end
        BERS_EXEC :
        begin
            if ( CLE && Data==8'hFF )
            begin
                ErsCnt  = -1;
                BERS_in = 1'b0;
                STATUS_MODE = NONE;
                RSTSTART  = 1'b1;
                RSTSTART  <= #1 1'b0;
                R_zd      = 1'b0;
            end
            else if ( CLE && Data==8'h70 )
                STATUS_MODE = STAT; // read status
        end
        endcase
    end

    //RESET state, RSTDONE
    always @(posedge RSTDONE)
    begin: Func1
        if (current_state == RESET )
        begin
            if ( RD_MODE == READ_B )
                RD_MODE = READ_A;
            PRG_ACT = 1'b0;
            ERS_ACT = 1'b0;
            CPY_ACT = 1'b0;
            R_zd    = 1'b1;
            Status      = 8'b11000000;
        end
    end

    //BUFF_TR state, TR_out
    always @(posedge TR_out)
    begin: Func2
        if (current_state == BUFF_TR )
        begin
            // transfer buffer
            if ( RD_MODE == READ_B )
                Address = Address + 12'h100;
            TRANSFER = 1'b0;
            R_zd     = 1'b1;
            Status[6]= 1'b1;
            TR_in    = 1'b0;
        end
    end

    //BUFF_TR state, INTCE
    always @(posedge INTCE)
    begin: Func3
        if (current_state == BUFF_TR && CENeg)
        begin
            //read intercepted
            if ( RD_MODE == READ_B )
                RD_MODE = READ_A;
            TRANSFER = 1'b0;
            R_zd     = 1'b1;
            Status[6]= 1'b1;
            TR_in    = 1'b0;
        end
    end

    //PGMS state,PROG_out
    always @(posedge PROG_out)
    begin: Func4
    integer i,j,k;
        if (current_state==PGMS)
        begin
            PROG_in   = 1'b0;
            PRG_ACT   = 1'b0;
            R_zd      = 1'b1;
            Status[6] = 1'b1;
            if ( read && STATUS_MODE!==NONE )
                READ_STATUS(STATUS_MODE);
            if ( RD_MODE == READ_B )
                RD_MODE = READ_A;
                if ( WrBuffBlock !== -1 )
                begin
                    for(j=WrBuffStartAddr;j<=WrBuffEndAddr;j=j+1)
                    begin
                        Mem[WrBuffPage*(PageSize+1)+j]
                                        = WrBuffData[(PageSize+1)+j];
                        WrBuffData[(PageSize+1)+j]= -1;
                    end
                    WrBuffBlock = -1;
                end
            CPY_ACT         =1'b0;
        end
    end

    //BERS_EXEC state,ERS_ACT
    always @(posedge ERS_ACT)
    begin: Func5a
    integer i,j,k;
        if (current_state==BERS_EXEC)
        begin
                if ( ErsQueue !== -1 )
                    for(j= (ErsQueue)*(BlockSize+1);
                         j<=(ErsQueue)*(BlockSize+1) + BlockSize;j=j+1)
                    begin
                        for(k=0;k<=PageSize;k=k+1)
                            Mem[j*(PageSize+1)+k] = -1;
                    end
            Status[7] = 1'b1;
        end
    end

    //BERS_EXEC state,BERS_out
    always @(posedge BERS_out)
    begin: Func5b
    integer i,j,k;
        if (current_state==BERS_EXEC)
        begin
            BERS_in   = 1'b0;
            ERS_ACT   = 1'b0;
            R_zd      = 1'b1;
            Status[6] = 1'b1;
            if ( read && STATUS_MODE!==NONE )
                READ_STATUS(STATUS_MODE);
            if ( RD_MODE == READ_B )
                RD_MODE = READ_A;
                if ( ErsQueue !== -1 )
                    for(j= (ErsQueue)*(BlockSize+1);
                         j<=(ErsQueue)*(BlockSize+1) + BlockSize;j=j+1)
                    begin
                        for(k=0;k<=PageSize;k=k+1)
                            Mem[j*(PageSize+1)+k] = MaxData;
                    end
        end
    end

    //Output Disable Control
    always @(posedge RENeg )
    begin
        DOut_zd    = 8'bZ;
    end

    //Output Disable Control
    always @(posedge CENeg)
    begin
        DOut_zd    = 8'bZ;
    end

   task READ_STATUS;
   input reg[1:0] mode;
   begin
       DOut_zd = Status;
       DOut_zd[4:1] = 4'b0;
   end
   endtask

   task READ_DATA;
   inout integer Addr;
   inout integer Page;
   begin
        if (Mem[Page*(PageSize+1)+Addr] !== -1)
            DOut_zd  = Mem[Page*(PageSize+1)+Addr];
        else
            DOut_zd  = 8'bx;
        if (Addr == PageSize)
        begin
            Addr  = 0;
            if (RD_MODE == READ_B)
                RD_MODE = READ_A;
            NEXT_PAGE  = 1'b1;
            if ((Page % (BlockSize+1)) == BlockSize)
                LAST_PAGE  = 1'b1;
            else
            begin
                LAST_PAGE  = 1'b0;
                Page       = Page + 1;
            end
        end
        else
        begin
            Addr       = Addr+1;
            NEXT_PAGE  = 1'b0;
        end
   end
   endtask

   reg  BuffInRE,  BuffInCE,  BuffInzRE,  BuffInzCE ,BuffInR;
   wire BuffOutRE, BuffOutCE, BuffOutzRE, BuffOutzCE,BuffOutR;

    BUFFER    BUFRE          (BuffOutRE  , BuffInRE);
    BUFFER    BUFCE          (BuffOutCE  , BuffInCE);
    BUFFER    BUFZRE         (BuffOutzRE , BuffInzRE);
    BUFFER    BUFZCE         (BuffOutzCE , BuffInzCE);
    BUFFER    BUFR           (BuffOutR   , BuffInR);

    initial
    begin
        BuffInRE    = 1'b1;
        BuffInCE    = 1'b1;
        BuffInzRE   = 1'b1;
        BuffInzCE   = 1'b1;
        BuffInR     = 1'b1;
    end

    always @(posedge BuffOutRE)
    begin
        REDQ_01 = $time;
    end
    always @(posedge BuffOutCE)
    begin
        CEDQ_01 = $time;
    end
    always @(posedge BuffOutzRE)
    begin
        REDQz_01 = $time;
    end
    always @(posedge BuffOutzCE)
    begin
        CEDQz_01 = $time;
    end
    always @(posedge BuffOutR)
    begin
        WER_01   = $time;
    end

endmodule

/*module BUFFER (OUT,IN);
    input IN;
    output OUT;
    buf   ( OUT, IN);
endmodule*/
