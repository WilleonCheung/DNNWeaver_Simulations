`timescale 1ns/1ps
//`include"common.vh"
//-----------------------------------------------------------
//Simple Log2 calculation function
//-----------------------------------------------------------
/*`define C_LOG_2(n) (\
(n) <= (1<<0) ? 0 : (n) <= (1<<1) ? 1 :\
(n) <= (1<<2) ? 2 : (n) <= (1<<3) ? 3 :\
(n) <= (1<<4) ? 4 : (n) <= (1<<5) ? 5 :\
(n) <= (1<<6) ? 6 : (n) <= (1<<7) ? 7 :\
(n) <= (1<<8) ? 8 : (n) <= (1<<9) ? 9 :\
(n) <= (1<<10) ? 10 : (n) <= (1<<11) ? 11 :\
(n) <= (1<<12) ? 12 : (n) <= (1<<13) ? 13 :\
(n) <= (1<<14) ? 14 : (n) <= (1<<15) ? 15 :\
(n) <= (1<<16) ? 16 : (n) <= (1<<17) ? 17 :\
(n) <= (1<<18) ? 18 : (n) <= (1<<19) ? 19 :\
(n) <= (1<<20) ? 20 : (n) <= (1<<21) ? 21 :\
(n) <= (1<<22) ? 22 : (n) <= (1<<23) ? 23 :\
(n) <= (1<<24) ? 24 : (n) <= (1<<25) ? 25 :\
(n) <= (1<<26) ? 26 : (n) <= (1<<27) ? 27 :\
(n) <= (1<<28) ? 28 : (n) <= (1<<29) ? 29 :\
(n) <= (1<<30) ? 30 : (n) <= (1<<31) ? 31 : 32)*/
//-----------------------------------------------------------

module axi_master_tb_driver
#(
// ******************************************************************
// PARAMETERS
// ******************************************************************
   parameter integer OP_WIDTH                 = 64,
   parameter integer NUM_PE                   = 4,
   parameter integer NUM_PU                   = 4,

   parameter integer AXI_DATA_WIDTH           = 64,
   parameter integer AXI_ADDR_WIDTH           = 32,
   parameter integer C_M_AXI_SUPPORTS_WRITE   = 1,
   parameter integer C_M_AXI_SUPPORTS_READ    = 1,
   parameter integer C_M_AXI_READ_TARGET      = 32'hFFFF0000,
   parameter integer C_M_AXI_WRITE_TARGET     = 32'hFFFF8000,
   parameter integer C_OFFSET_WIDTH           = 11,
   parameter integer C_M_AXI_RD_BURST_LEN     = 16,
   parameter integer C_M_AXI_WR_BURST_LEN     = 4,
   parameter integer TX_SIZE_WIDTH            = 6,
   parameter integer VERBOSITY                = 3,
   parameter integer NUM_AXI                  = 1,
   parameter integer DATA_WIDTH               = 16,
   parameter integer BASE_ADDR                =32'h08000000        , 
   parameter integer TX_FIFO_DATA_WIDTH       = AXI_ADDR_WIDTH + TX_SIZE_WIDTH
// ******************************************************************
) (
// ******************************************************************
// IO
// ******************************************************************
    // System Signals
  input  wire                                         clk,
  input  wire                                         reset,

  input  wire  [ 32 -1 :0] aw_delay,
  input  wire  [ 32 -1 :0] w_delay,

    // Master Interface Write Address
  input  wire  [6*NUM_AXI-1:0]                 M_AXI_AWID,
  input  wire  [AXI_ADDR_WIDTH*NUM_AXI-1:0]    M_AXI_AWADDR,
  input  wire  [4*NUM_AXI-1:0]                 M_AXI_AWLEN,
  input  wire  [3*NUM_AXI-1:0]                 M_AXI_AWSIZE,
  input  wire  [2*NUM_AXI-1:0]                 M_AXI_AWBURST,
  input  wire  [2*NUM_AXI-1:0]                 M_AXI_AWLOCK,
  input  wire  [4*NUM_AXI-1:0]                 M_AXI_AWCACHE,
  input  wire  [3*NUM_AXI-1:0]                 M_AXI_AWPROT,
  input  wire  [4*NUM_AXI-1:0]                 M_AXI_AWQOS,
  input  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_AWUSER,
  input  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_AWVALID,
  output reg   [ NUM_AXI-1:0]                   M_AXI_AWREADY,

    // Master Interface Write Data
  input  wire                                         [6*NUM_AXI-1:0]                 M_AXI_WID,
  input  wire  [ IF_DATA_WIDTH        -1 : 0 ]        M_AXI_WDATA,
  input  wire  [ WSTRB_WIDTH          -1 : 0 ]        M_AXI_WSTRB,
  input  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_WLAST,
  input  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_WUSER,
  input  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_WVALID,
  output reg  [NUM_AXI-1:0]                   M_AXI_WREADY,

  // Master Interface Write Response
  output reg  [6*NUM_AXI-1:0]                 M_AXI_BID,
  output reg  [2*NUM_AXI-1:0]                 M_AXI_BRESP,
  output reg  [NUM_AXI-1:0]                   M_AXI_BUSER,
  output reg  [NUM_AXI-1:0]                   M_AXI_BVALID,
  input  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_BREADY,

    // Master Interface Read Address
  input  wire  [6*NUM_AXI-1:0]                 M_AXI_ARID,
  input  wire  [32*NUM_AXI-1:0]                M_AXI_ARADDR,
  input  wire  [4*NUM_AXI-1:0]                 M_AXI_ARLEN,
  input  wire  [3*NUM_AXI-1:0]                 M_AXI_ARSIZE,
  input  wire  [2*NUM_AXI-1:0]                 M_AXI_ARBURST,
  input  wire  [2*NUM_AXI-1:0]                 M_AXI_ARLOCK,
  input  wire  [4*NUM_AXI-1:0]                 M_AXI_ARCACHE,
  input  wire  [3*NUM_AXI-1:0]                 M_AXI_ARPROT,
  input  wire  [4*NUM_AXI-1:0]                 M_AXI_ARQOS,
  input  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_ARUSER,
  input  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_ARVALID,
  output reg  [NUM_AXI-1:0]                   M_AXI_ARREADY,

  // Master Interface Read Data
  output reg  [6*NUM_AXI-1:0]                 M_AXI_RID,
  output reg  [IF_DATA_WIDTH-1:0]             M_AXI_RDATA,
  output reg  [2*NUM_AXI-1:0]                 M_AXI_RRESP,
  output reg  [NUM_AXI-1:0]                   M_AXI_RLAST,
  output reg  [NUM_AXI-1:0]                   M_AXI_RUSER,
  output reg  [NUM_AXI-1:0]                   M_AXI_RVALID,
  input  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_RREADY



);

// ******************************************************************
// Localparam
// ******************************************************************
    localparam integer IF_DATA_WIDTH = AXI_DATA_WIDTH * NUM_AXI;
    localparam integer WSTRB_WIDTH   = AXI_DATA_WIDTH/8 * NUM_AXI;
//    localparam integer NUM_PU_W   = `C_LOG_2(NUM_PU)+1;

// ******************************************************************
// Regs and Wires
// ******************************************************************

  //reg  [ IF_DATA_WIDTH        -1 : 0 ]        ddr_ram [0:(1<<27)-1];
  reg  [ 15 : 0 ]        ddr_ram [0:(1<<27)-1];

  reg                                         r_fifo_push;
  reg                                         r_fifo_pop;
  reg  [ TX_FIFO_DATA_WIDTH   -1 : 0 ]        r_fifo_data_in;
  wire [ TX_FIFO_DATA_WIDTH   -1 : 0 ]        r_fifo_data_out;
  wire                                        r_fifo_empty;
  wire                                        r_fifo_full;

  reg                                         w_fifo_push;
  reg                                         w_fifo_pop;
  reg  [ TX_FIFO_DATA_WIDTH   -1 : 0 ]        w_fifo_data_in;
  wire [ TX_FIFO_DATA_WIDTH   -1 : 0 ]        w_fifo_data_out;
  wire                                        w_fifo_empty;
  wire                                        w_fifo_full;

  reg                                         fail_flag;

  integer                                     read_counter;
  integer                                     read_counter_valid;
  integer                                     write_counter;
// ******************************************************************

// ******************************************************************

always @(posedge clk)
begin
  if (reset)
    read_counter_valid <= 0;
  else if (M_AXI_RVALID && M_AXI_RREADY)
    read_counter_valid <= read_counter_valid + 4;
end

// Initialize regs
initial
begin
    read_counter = 0;
    write_counter = 0;
    M_AXI_AWREADY = 0;
    M_AXI_WREADY = 0;
    M_AXI_BID = 0;
    M_AXI_BRESP = 0;
    M_AXI_BUSER = 0;
    M_AXI_BVALID = 0;
    M_AXI_ARREADY = 0;
    M_AXI_RID = 0;
    M_AXI_RDATA = 0;
    M_AXI_RRESP = 0;
    M_AXI_RLAST = 0;
    M_AXI_RUSER = 0;
    M_AXI_RVALID = 0;
    fail_flag = 0;
    r_fifo_data_in = 0;
    r_fifo_push = 0;
    r_fifo_pop = 0;
    w_fifo_data_in = 0;
    w_fifo_push = 0;
    w_fifo_pop = 0;
end

//// MS: DDR RAM init

/// In Layer :conv0/Convolution
parameter IMG   = 32'h000000>>1;
parameter WEIGHT= 32'h2b5000>>1;
parameter BIAS  = 32'h2b7c00>>1;
parameter OP    = 32'h2b8800>>1;
parameter MEAN  = 32'h1d83c00>>1;
parameter SCALE = 32'h1d84800>>1;

parameter IMGSIZE=1397792;    //418x418x8
parameter WGHTSIZE=1152;     // 3x3x8x8x2
parameter BIASSIZE=32;
parameter MEANSIZE=16;
parameter SCALESIZE=16;

//// In Layer :conv1/Convolution 
parameter IMG1   = 32'h32f6400>>1;
parameter WEIGHT1= 32'h3459400>>1;
parameter BIAS1  = 32'h3462c00>>1;
parameter OP1    = 32'h3463800>>1;
parameter MEAN1  = 32'h41fb000>>1;
parameter SCALE1 = 32'h41fbc00>>1;

//parameter IMGSIZE1=705600;    //210x210x16
parameter WGHTSIZE1=4608;     //3x3x8x8x4x2
parameter BIASSIZE1=64;
parameter MEANSIZE1=32;
parameter SCALESIZE1=32;

//// In Layer :conv2/Convolution 
parameter IMG2   = 32'h4cddc00>>1;
parameter WEIGHT2= 32'h4d98000>>1;
parameter BIAS2  = 32'h4dbc800>>1;
parameter OP2    = 32'h4dbd400>>1;
parameter MEAN2  = 32'h54bb800>>1;
parameter SCALE2 = 32'h54bc400>>1;

//parameter IMGSIZE2=359552;  //106x106x32
parameter WGHTSIZE2=18432;    //3x3x8x8x8x4
parameter BIASSIZE2=128;
parameter MEANSIZE2=64;
parameter SCALESIZE2=64;

//// In Layer :conv3/Convolution 
parameter IMG3   = 32'h5a57000>>1;
parameter WEIGHT3= 32'h5abd400>>1;
parameter BIAS3  = 32'h5b4dc00>>1;
parameter OP3   = 32'h5b4e800>>1;
parameter MEAN3  = 32'h5f01000>>1;
parameter SCALE3 = 32'h5f01c00>>1;

//parameter IMGSIZE3=186624;   //54x54x64
parameter WGHTSIZE3=73728;  //3x3x8x8x(128/8)x8
parameter BIASSIZE3=256;
parameter MEANSIZE3=128;
parameter SCALESIZE3=128;

//// In Layer :conv4/Convolution 
parameter IMG4   = 32'h61f9800>>1;
parameter WEIGHT4= 32'h6236400>>1;
parameter BIAS4  = 32'h6476c00>>1;
parameter OP4   = 32'h6477800>>1;
parameter MEAN4  = 32'h6686400>>1;
parameter SCALE4 = 32'h6687000>>1;

//parameter IMGSIZE4=100352;   //28x28x128
parameter WGHTSIZE4=294912;
parameter BIASSIZE4=512;
parameter MEANSIZE4=256;
parameter SCALESIZE4=256;

//// In Layer :conv5/Convolution 
parameter IMG5   = 32'h682ec00>>1;
parameter WEIGHT5= 32'h6857c00>>1;
parameter BIAS5  = 32'h7158400>>1;
parameter OP5    = 32'h7159400>>1;
parameter MEAN5  = 32'h72bb400>>1;
parameter SCALE5 = 32'h72bc000>>1;

//parameter IMGSIZE5=57600;  //15x15x256
parameter WGHTSIZE5=1179648;
parameter BIASSIZE5=1024;
parameter MEANSIZE5=512;
parameter SCALESIZE5=512;

//// In Layer :conv6/Convolution 
parameter IMG6   = 32'h73bf000>>1;
parameter WEIGHT6= 32'h7410800>>1;
parameter BIAS6  = 32'h9811000>>1;
parameter OP6    = 32'h9812800>>1;
parameter MEAN6  = 32'h9a93800>>1;
parameter SCALE6 = 32'h9a94800>>1;

//parameter IMGSIZE6=115200;  // 15x15x512
parameter WGHTSIZE6=4718592;
parameter BIASSIZE6=2048;
parameter MEANSIZE6=1024;
parameter SCALESIZE6=1024;

//// In Layer :conv7/Convolution 
parameter IMG7   = 32'h9c17400>>1;
parameter WEIGHT7= 32'h9cb9c00>>1;
parameter BIAS7  = 32'he4ba400>>1;
parameter OP7    = 32'he4bbc00>>1;
parameter MEAN7  = 32'he73cc00>>1;
parameter SCALE7 = 32'he73dc00>>1;

//parameter IMGSIZE7=230400; //15x15x1024  
parameter WGHTSIZE7=9437184;
parameter BIASSIZE7=2048;
parameter MEANSIZE7=1024;
parameter SCALESIZE7=1024;

//// In Layer :conv8/Convolution 
parameter IMG8   = 32'he8c0800>>1;
parameter WEIGHT8= 32'he941000>>1;
parameter BIAS8  = 32'hed41800>>1;
parameter OP8    = 32'hed42400>>1;

parameter WGHTSIZE8=131072;
parameter BIASSIZE8=250;

// In Layer :fc0/Convolution 

// In Layer :fc1/Convolution

integer ii;
reg [15:0] data;
initial begin
  ii=0;
  data =1;
  /// Initial entire mem to 0
  for (ii=0;ii<(1<<27);ii=ii+1) begin
       ddr_ram[ii]=0;
  end

///////////////// Layer0 : Conv0
  $readmemh("./data/image.txt",ddr_ram,IMG,IMG+IMGSIZE-1);
  $readmemh("./data/conv0_weight.txt",ddr_ram,WEIGHT,WEIGHT+WGHTSIZE-1);
  $readmemh("./data/conv0_bias.txt",ddr_ram,BIAS,BIAS+BIASSIZE-1);
  $readmemh("./data/conv0_bn_mean.txt",ddr_ram,MEAN,MEAN+MEANSIZE-1);
  $readmemh("./data/conv0_bn_scale.txt",ddr_ram,SCALE,SCALE+SCALESIZE-1);
//////////////// Layer1 : Conv1
 $readmemh("./data/conv1_weight.txt",ddr_ram,WEIGHT1,WEIGHT1+WGHTSIZE1-1);
 $readmemh("./data/conv1_bias.txt",ddr_ram,BIAS1,BIAS1+BIASSIZE1-1);
 $readmemh("./data/conv1_bn_mean.txt",ddr_ram,MEAN1,MEAN1+MEANSIZE1-1);
 $readmemh("./data/conv1_bn_scale.txt",ddr_ram,SCALE1,SCALE1+SCALESIZE1-1);
////////////// Layer2 : Conv2
 $readmemh("./data/conv2_weight.txt",ddr_ram,WEIGHT2,WEIGHT2+WGHTSIZE2-1);
 $readmemh("./data/conv2_bias.txt",ddr_ram,BIAS2,BIAS2+BIASSIZE2-1);
 $readmemh("./data/conv2_bn_mean.txt",ddr_ram,MEAN2,MEAN2+MEANSIZE2-1);
 $readmemh("./data/conv2_bn_scale.txt",ddr_ram,SCALE2,SCALE2+SCALESIZE2-1);
//////////////// Layer3 : Conv3
 $readmemh("./data/conv3_weight.txt",ddr_ram,WEIGHT3,WEIGHT3+WGHTSIZE3-1);
 $readmemh("./data/conv3_bias.txt",ddr_ram,BIAS3,BIAS3+BIASSIZE3-1);
 $readmemh("./data/conv3_bn_mean.txt",ddr_ram,MEAN3,MEAN3+MEANSIZE3-1);
 $readmemh("./data/conv3_bn_scale.txt",ddr_ram,SCALE3,SCALE3+SCALESIZE3-1);
//////////////// Layer4 : Conv4
 $readmemh("./data/conv4_weight.txt",ddr_ram,WEIGHT4,WEIGHT4+WGHTSIZE4-1);
 $readmemh("./data/conv4_bias.txt",ddr_ram,BIAS4,BIAS4+BIASSIZE4-1);
 $readmemh("./data/conv4_bn_mean.txt",ddr_ram,MEAN4,MEAN4+MEANSIZE4-1);
 $readmemh("./data/conv4_bn_scale.txt",ddr_ram,SCALE4,SCALE4+SCALESIZE4-1);
//////////////// Layer5 : Conv5
 $readmemh("./data/conv5_weight.txt",ddr_ram,WEIGHT5,WEIGHT5+WGHTSIZE5-1);
 $readmemh("./data/conv5_bias.txt",ddr_ram,BIAS5,BIAS5+BIASSIZE5-1);
 $readmemh("./data/conv5_bn_mean.txt",ddr_ram,MEAN5,MEAN5+MEANSIZE5-1);
 $readmemh("./data/conv5_bn_scale.txt",ddr_ram,SCALE5,SCALE5+SCALESIZE5-1);
//////////////// Layer6 : Conv6
 $readmemh("./data/conv6_weight.txt",ddr_ram,WEIGHT6,WEIGHT6+WGHTSIZE6-1);
 $readmemh("./data/conv6_bias.txt",ddr_ram,BIAS6,BIAS6+BIASSIZE6-1);
 $readmemh("./data/conv6_bn_mean.txt",ddr_ram,MEAN6,MEAN6+MEANSIZE6-1);
 $readmemh("./data/conv6_bn_scale.txt",ddr_ram,SCALE6,SCALE6+SCALESIZE6-1);
//////////////// Layer7 : Conv7
 $readmemh("./data/conv7_weight.txt",ddr_ram,WEIGHT7,WEIGHT7+WGHTSIZE7-1);
 $readmemh("./data/conv7_bias.txt",ddr_ram,BIAS7,BIAS7+BIASSIZE7-1);
 $readmemh("./data/conv7_bn_mean.txt",ddr_ram,MEAN7,MEAN7+MEANSIZE7-1);
 $readmemh("./data/conv7_bn_scale.txt",ddr_ram,SCALE7,SCALE7+SCALESIZE7-1);
//////////////// Layer8 : conv8
 $readmemh("./data/conv8_weight.txt",ddr_ram,WEIGHT8,WEIGHT8+WGHTSIZE8-1);
 $readmemh("./data/conv8_bias.txt",ddr_ram,BIAS8,BIAS8+BIASSIZE8-1);
end
//////
always @(negedge clk)
begin
    ar_channel;
end

always @(negedge clk)
begin
    aw_channel;
end

always @(negedge clk)
begin
    r_channel;
end

always @(posedge clk)
begin
    w_channel;
end

always @(posedge clk)
begin
    b_channel;
end

// ******************************************************************
// TX-FIFO
// ******************************************************************
fifo_tb   #(
    .DATA_WIDTH               ( TX_FIFO_DATA_WIDTH       ),
    .ADDR_WIDTH               ( 2                       )
) r_fifo (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .push                     ( r_fifo_push              ),
    .pop                      ( r_fifo_pop               ),
    .data_in                  ( r_fifo_data_in           ),
    .data_out                 ( r_fifo_data_out          ),
    .empty                    ( r_fifo_empty             ),
    .full                     ( r_fifo_full              ),
    .fifo_count               (                          )
);

fifo_tb #(
    .DATA_WIDTH               ( TX_FIFO_DATA_WIDTH       ),
    .ADDR_WIDTH               ( 10                       )
) w_fifo (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .push                     ( w_fifo_push              ),
    .pop                      ( w_fifo_pop               ),
    .data_in                  ( w_fifo_data_in           ),
    .data_out                 ( w_fifo_data_out          ),
    .empty                    ( w_fifo_empty             ),
    .full                     ( w_fifo_full              ),
    .fifo_count               (                          )
);
// ******************************************************************

// ******************************************************************
// Tasks
// ******************************************************************

//-------------------------------------------------------------------
//task automatic delay;
task delay;
  input integer count;
  begin
    repeat (count) begin
      @(negedge clk);
    end
  end
endtask
//-------------------------------------------------------------------

//-------------------------------------------------------------------
//task automatic random_delay;
task random_delay;
  input integer MAX_DELAY;
  reg  [ 3 : 0 ] delay;
  begin
    delay = $random;
    delay[0] = 1'b1;
    repeat (delay) begin
      @(negedge clk);
    end
  end
endtask
//-------------------------------------------------------------------

//-------------------------------------------------------------------
//task automatic ar_channel;
task ar_channel;
  reg[AXI_ADDR_WIDTH-1:0] araddr;
  begin
    wait(!reset);
    wait(M_AXI_ARVALID && ~r_fifo_full);
    @(negedge clk);
    random_delay(16);
    M_AXI_ARREADY = 1'b1;
    araddr = M_AXI_ARADDR - BASE_ADDR;
    r_fifo_data_in = {araddr, M_AXI_ARLEN};
    r_fifo_push = 1'b1;
    @(negedge clk);
    r_fifo_push = 1'b0;
    wait(~M_AXI_ARVALID);
    M_AXI_ARREADY = 1'b0;
  end
endtask
//-------------------------------------------------------------------

//-------------------------------------------------------------------
wire [AXI_ADDR_WIDTH-1:0] addr_debug;
wire [4-1:0] arlen_debug;
assign {addr_debug, arlen_debug} = r_fifo_data_out;
//task automatic r_channel;
task r_channel;
  integer i, I;
  reg [AXI_ADDR_WIDTH-1:0] addr;
  reg [4-1:0] arlen;
  begin
    I = AXI_DATA_WIDTH / DATA_WIDTH;
    wait(!reset);
    //wait(M_AXI_RREADY && ~r_fifo_empty && !clk);
    wait(~r_fifo_empty && !clk);
    wait (M_AXI_RREADY);
    // if (~M_AXI_RREADY)
    // begin
    //   fail_flag = 1'b1;
    //   $display ("Read channel not ready");
    // end
    @(negedge clk);
    M_AXI_RVALID = 1'b0;
    r_fifo_pop = 1'b1;
    @(negedge clk);
    r_fifo_pop = 1'b0;
    {addr, arlen} = r_fifo_data_out;
    addr = addr >> 1;
    wait(M_AXI_RREADY);
    @(negedge clk);
    repeat(arlen) begin
      if (!M_AXI_RREADY)
      begin
        wait(M_AXI_RREADY);
        @(negedge clk);
      end
      for (i=0; i<I; i=i+1)
      begin
        M_AXI_RDATA[i*DATA_WIDTH+:DATA_WIDTH] = ddr_ram[addr+i];
        //$display ("M_AXI_R Addr:%d, Value:%d", (addr+i) << 1, ddr_ram[addr+i]);
        read_counter = read_counter + 1;
      end
      //$display ("Value:%h", M_AXI_RDATA);
      addr = addr+I;
      M_AXI_RVALID = 1'b1;
      @(negedge clk);
      M_AXI_RVALID = 1'b0;
    end
    if (!M_AXI_RREADY)
    begin
      wait(M_AXI_RREADY);
      @(negedge clk);
    end
    M_AXI_RVALID = 1'b1;
    M_AXI_RLAST = 1'b1;
    for (i=0; i<I; i=i+1)
    begin
      M_AXI_RDATA[i*DATA_WIDTH+:DATA_WIDTH] = ddr_ram[addr+i];
      //$display ("Last: M_AXI_R Addr:%d, Value:%d", (addr+i) << 1, ddr_ram[addr+i]);
      read_counter = read_counter + 1;
    end
    //$display ("Value:%h", M_AXI_RDATA);
    addr = addr + I;
    @(negedge clk);
    M_AXI_RLAST = 1'b0;
    M_AXI_RVALID = 1'b0;
  end
endtask
//-------------------------------------------------------------------

//-------------------------------------------------------------------
//task automatic b_channel;
task b_channel;
  begin
    wait(!reset);
    wait(M_AXI_WREADY && M_AXI_WVALID && M_AXI_WLAST);
    // Okay response
    M_AXI_BRESP = 1'b0;
    M_AXI_BVALID = 1'b1;
    wait(M_AXI_BREADY && M_AXI_BVALID);
    M_AXI_BVALID = 1'b0;
  end
endtask
//-------------------------------------------------------------------

//-------------------------------------------------------------------
task w_channel;
  reg [AXI_ADDR_WIDTH-1:0] awaddr;
  reg [4-1:0] awlen;
  integer offset;
  integer i, I;
  begin
    I = AXI_DATA_WIDTH / DATA_WIDTH;
    wait(!reset);
    wait(M_AXI_WVALID && ~w_fifo_empty && !clk);
    //repeat (10) @(negedge clk);
    M_AXI_WREADY = 1'b0;
    w_fifo_pop = 1'b1;
    @(negedge clk);
    //M_AXI_WREADY = 1'b1;
    w_fifo_pop = 1'b0;
    {awaddr, awlen} = w_fifo_data_out;
    awaddr = awaddr >> 1;
    offset = 0;
    repeat(awlen) begin
      if (!M_AXI_WVALID) begin
        wait(M_AXI_WVALID);
        @(negedge clk);
      end
      delay(w_delay);
      M_AXI_WREADY = 1'b1;
      for (i=0; i<I; i=i+1)
      begin
        if (ddr_ram[awaddr+offset] != M_AXI_WDATA[i*DATA_WIDTH+:DATA_WIDTH])
        begin
          //$error ("Write data does not match expected");
          //$display ("Expected: %h", ddr_ram[awaddr+offset]);
          //$display ("Got     : %h", M_AXI_WDATA[i*DATA_WIDTH+:DATA_WIDTH]);
          //$fatal(1);
        end
        ddr_ram[awaddr+offset] = M_AXI_WDATA[i*DATA_WIDTH+:DATA_WIDTH];
        //$display ("MS : M_AXI_W Addr:%d, Value:%d", (awaddr+offset) << 1, M_AXI_WDATA[i*DATA_WIDTH+:DATA_WIDTH]);
        //$display ("MS : DDR Addr: %x Value : %x", (awaddr+offset) , ddr_ram[awaddr+offset]);
        offset = offset + 1;
      end
      //$display ("%h", M_AXI_WDATA);
      @(negedge clk);
      M_AXI_WREADY = 1'b0;
    end

    if (!M_AXI_WVALID) begin
      wait(M_AXI_WVALID);
      @(negedge clk);
    end
    delay(w_delay);
    M_AXI_WREADY = 1'b1;
    if (~M_AXI_WLAST)
    begin
      fail_flag = 1'b1;
      $display ("Failed to asset WLAST\s num of writes = %d", awlen);
      $fatal;// ("Failed to assert WLAST", 0);
    end
    for (i=0; i<I; i=i+1)
    begin
      ddr_ram[awaddr+offset] = M_AXI_WDATA[i*DATA_WIDTH+:DATA_WIDTH];
      //$display ("LAST: M_AXI_W Addr:%d, Value:%d", (awaddr+offset) << 1, M_AXI_WDATA[i*DATA_WIDTH+:DATA_WIDTH]);
      //$display ("%h", M_AXI_WDATA);
      offset = offset + 1;
    end
    @(negedge clk);
    offset = 0;
    M_AXI_WREADY = 1'b0;
  end
endtask
//-------------------------------------------------------------------

//-------------------------------------------------------------------
//task automatic aw_channel;
task aw_channel;
  reg [AXI_ADDR_WIDTH-1:0] awaddr;
  begin
    wait(!reset);
    wait(M_AXI_AWVALID && ~w_fifo_full);
    //random_delay(16);
    @(negedge clk);
    delay(0);

    M_AXI_AWREADY = 1'b1;

    awaddr = M_AXI_AWADDR - BASE_ADDR;
    w_fifo_data_in = {awaddr, M_AXI_AWLEN};
    w_fifo_push = 1'b1;
    @(negedge clk);
    w_fifo_push = 1'b0;
    wait(~M_AXI_AWVALID);
    M_AXI_AWREADY = 1'b0;
  end
endtask
//-------------------------------------------------------------------

//-------------------------------------------------------------------
/*integer writes_remaining;
task automatic request_random_tx;
  begin
    wait(!reset);
    wait(rd_ready);
    rd_req = 1'b1;
    rd_req_size = 40;
    rd_addr = ($urandom>>10)<<10;
    if (VERBOSITY > 2)
      $display ("requesting %d reads", rd_req_size);
    @(posedge clk);
    @(posedge clk);
    rd_req = 1'b0;
    if (VERBOSITY > 2)
      $display ("request sent");
    wr_pu_id = 0;
    writes_remaining = rd_req_size;
    repeat(5) begin
      wait(wr_ready);
      @(negedge clk);
      wr_req = 1'b1;
      if (writes_remaining > 8)
        wr_req_size = 8;
      else
        wr_req_size = writes_remaining;
      @(negedge clk);
      wr_req = 1'b0;
      wait(wr_done);
      wr_pu_id = (wr_pu_id + 1) % NUM_PU;
      @(negedge clk);
      writes_remaining = writes_remaining - wr_req_size;
      @(negedge clk);
      @(negedge clk);
      @(negedge clk);
      @(negedge clk);
      @(negedge clk);
      @(negedge clk);
      @(negedge clk);
      @(negedge clk);
      @(negedge clk);
    end
  end
endtask
*/
//-------------------------------------------------------------------

//-------------------------------------------------------------------
task check_fail;
  if (fail_flag && !reset)
  begin
    $display("%c[1;31m",27);
    $display ("Test Failed");
    $display("%c[0m",27);
    $finish;
  end
endtask

//-------------------------------------------------------------------
task test_pass;
  begin
    $display("%c[1;32m",27);
    $display ("Test Passed");
    $display("%c[0m",27);
    $finish;
  end
endtask
//-------------------------------------------------------------------

//-------------------------------------------------------------------
/*
task initialize_fm;
  input integer addr;
  input integer fm_w;
  input integer fm_h;
  input integer fm_c;
  integer ii, jj, kk;
  integer idx;
  integer fm_w_ceil;
  integer addr_tmp;
  begin
    fm_w_ceil = ceil_a_by_b(fm_w, NUM_PE) * NUM_PE;
    addr_tmp = addr - BASE_ADDR;
    addr_tmp = addr_tmp >> 1;
    $display ("Initializing Feature map of size %d x %d x %d at location %h",
      fm_w, fm_h, fm_c, addr_tmp);
    for(ii=0; ii<fm_c; ii=ii+1)
    begin
      for(jj=0; jj<fm_h; jj=jj+1)
      begin
        for(kk=0; kk<fm_w_ceil; kk=kk+1)
        begin
          idx = kk + fm_w_ceil * (jj + fm_h * (ii));
          if (kk < fm_w)
            ddr_ram[addr_tmp+idx] = idx;
          else
            ddr_ram[addr_tmp+idx] = 0;
          $display ("Addr: %d, Value: %d", addr_tmp+idx, ddr_ram[addr_tmp+idx]);
        end
      end
    end
  end
endtask

//-------------------------------------------------------------------

  test_status #(
    .PREFIX                   ( "AXI_MASTER"             ),
    .TIMEOUT                  ( 1000000                  )
  ) status (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .pass                     ( pass                     ),
    .fail                     ( fail                     )
  );
*/
endmodule

