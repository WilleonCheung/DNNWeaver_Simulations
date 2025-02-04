`include "dw_params.vh"
`include "common.vh"
//`define DEBUG
module dnn_accelerator_tb;


  localparam integer TID_WIDTH         = 6;
  localparam integer ADDR_W            = 32;
  localparam integer OP_WIDTH          = 16;
  localparam integer DATA_W            = 64;
  localparam integer NUM_PU            = `num_pu;
  localparam integer NUM_PE            = `num_pe;
  localparam integer BASE_ADDR_W       = ADDR_W;
  localparam integer OFFSET_ADDR_W     = ADDR_W;
  localparam integer TX_SIZE_WIDTH     = 20;
  localparam integer RD_LOOP_W         = 32;
  localparam integer D_TYPE_W          = 2;
  localparam integer ROM_ADDR_W        = 3;

  localparam integer ROM_WIDTH = (BASE_ADDR_W + OFFSET_ADDR_W +
    RD_LOOP_W)*2 + D_TYPE_W;
  parameter BASE_ADDR = 32'h88000000;

  wire [ RD_LOOP_W            -1 : 0 ]        pu_id;
  wire [ D_TYPE_W             -1 : 0 ]        d_type;

  reg [324-1:0] mmap_ram[0:1023];

  wire                                        clk;
  wire                                        reset;
  reg                                         start;
  wire                                        done;
  wire                                        rd_req;
  wire                                        rd_ready;
  wire [ TX_SIZE_WIDTH        -1 : 0 ]        rd_req_size;
  wire [ TX_SIZE_WIDTH        -1 : 0 ]        rd_rvalid_size;
  wire [ ADDR_W               -1 : 0 ]        rd_addr;
  wire                                        wr_req;
  wire                                        wr_done;
  wire [ ADDR_W               -1 : 0 ]        wr_addr;
  wire [ TX_SIZE_WIDTH        -1 : 0 ]        wr_req_size;

    // Master Interface Write Address
  wire [ TID_WIDTH            -1 : 0 ]        M_AXI_AWID;
  wire [ ADDR_W               -1 : 0 ]        M_AXI_AWADDR;
  wire [ 4                    -1 : 0 ]        M_AXI_AWLEN;
  wire [ 3                    -1 : 0 ]        M_AXI_AWSIZE;
  wire [ 2                    -1 : 0 ]        M_AXI_AWBURST;
  wire [ 2                    -1 : 0 ]        M_AXI_AWLOCK;
  wire [ 4                    -1 : 0 ]        M_AXI_AWCACHE;
  wire [ 3                    -1 : 0 ]        M_AXI_AWPROT;
  wire [ 4                    -1 : 0 ]        M_AXI_AWQOS;
  wire                                        M_AXI_AWVALID;
  wire                                        M_AXI_AWREADY;

    // Master Interface Write Data
  wire [ TID_WIDTH            -1 : 0 ]        M_AXI_WID;
  wire [ DATA_W               -1 : 0 ]        M_AXI_WDATA;
  wire [ DATA_W/8             -1 : 0 ]        M_AXI_WSTRB;
  wire                                        M_AXI_WLAST;
  wire                                        M_AXI_WVALID;
  wire                                        M_AXI_WREADY;

    // Master Interface Write Response
  wire [ TID_WIDTH            -1 : 0 ]        M_AXI_BID;
  wire [ 2                    -1 : 0 ]        M_AXI_BRESP;
  wire                                        M_AXI_BVALID;
  wire                                        M_AXI_BREADY;

    // Master Interface Read Address
  wire [ TID_WIDTH            -1 : 0 ]        M_AXI_ARID;
  wire [ ADDR_W               -1 : 0 ]        M_AXI_ARADDR;
  wire [ 4                    -1 : 0 ]        M_AXI_ARLEN;
  wire [ 3                    -1 : 0 ]        M_AXI_ARSIZE;
  wire [ 2                    -1 : 0 ]        M_AXI_ARBURST;
  wire [ 2                    -1 : 0 ]        M_AXI_ARLOCK;
  wire [ 4                    -1 : 0 ]        M_AXI_ARCACHE;
  wire [ 3                    -1 : 0 ]        M_AXI_ARPROT;
  wire [ 4                    -1 : 0 ]        M_AXI_ARQOS;
  wire                                        M_AXI_ARVALID;
  wire                                        M_AXI_ARREADY;

    // Master Interface Read Data
  wire [ TID_WIDTH            -1 : 0 ]        M_AXI_RID;
  wire [ DATA_W               -1 : 0 ]        M_AXI_RDATA;
  wire [ 2                    -1 : 0 ]        M_AXI_RRESP;
  wire                                        M_AXI_RLAST;
  wire                                        M_AXI_RVALID;
  wire                                        M_AXI_RREADY;

  integer read_count;
  integer write_count;

  always @(posedge clk)
    if (reset || start)
      read_count <= 0;
    else if (M_AXI_RVALID && M_AXI_RREADY)
      read_count <= read_count + 1;

  always @(posedge clk)
    if (reset || start)
      write_count <= 0;
    else if (M_AXI_WVALID && M_AXI_WREADY)
      write_count <= write_count + 1;


  initial begin
    $dumpfile("dnn_accelerator_tb.vcd");
    $dumpvars(0,dnn_accelerator_tb);
  end

  reg [2-1:0] _l_type;
  reg [TX_SIZE_WIDTH-1:0] _stream_rvalid_size;
  reg [BASE_ADDR_W-1:0] _stream_rd_base_addr;
  reg [TX_SIZE_WIDTH-1:0] _stream_rd_size;
  reg [OFFSET_ADDR_W-1:0] _stream_rd_offset;
  reg [RD_LOOP_W-1:0] _stream_rd_loop_ic;
  reg [RD_LOOP_W-1:0] _stream_rd_loop_oc;
  reg [TX_SIZE_WIDTH-1:0] _buffer_rvalid_size;
  reg [BASE_ADDR_W-1:0] _buffer_rd_base_addr;
  reg [TX_SIZE_WIDTH-1:0] _buffer_rd_size;
  reg [OFFSET_ADDR_W-1:0] _buffer_rd_offset;
  reg [RD_LOOP_W-1:0] _buffer_rd_loop_max;

  integer max_layers;
  integer rom_idx;
  integer ddr_idx;
  integer tmp;

  integer ii, jj;

  reg signed [15:0] out;
  initial begin
    driver.status.start;
    max_layers = `max_layers;

    rom_idx = 0;

    repeat (2) begin
      wait(accelerator.PU_GEN[0].u_PU.u_controller.state == 0);
      driver.send_start;
      wait(accelerator.PU_GEN[0].u_PU.u_controller.state == 4)
      wait(accelerator.PU_GEN[0].u_PU.u_controller.state == 0);
      wait(accelerator.pu_done);

      wait(accelerator.mem_ctrl_top.u_mem_ctrl.done);
      repeat(100) begin
        @(negedge clk);
    end
      $display("Read count = %d\nWrite_count = %d", read_count, write_count);
      jj=  (32'h0169dd0)>>1;
      $display("MS : Printing Output");
    for(ii=jj;ii<jj+16*`num_pu;ii=ii+1) begin
         out = u_axim_driver.ddr_ram[ii];
         $display("Addr: %x, Data: %d",ii,out);
    end
      end
    driver.status.test_pass;
  end

// ==================================================================
  clk_rst_driver
  clkgen(
    .clk                      ( clk                      ),
    .reset_n                  (                          ),
    .reset                    ( reset                    )
  );
// ==================================================================

// ==================================================================
// DnnWeaver
// ==================================================================
  dnn_accelerator #(
  // INPUT PARAMETERS
    .NUM_PE                   ( NUM_PE                   ),
    .NUM_PU                   ( NUM_PU                   ),
    .ADDR_W                   ( ADDR_W                   ),
    .AXI_DATA_W               ( DATA_W                   ),
    .BASE_ADDR_W              ( BASE_ADDR_W              ),
    .OFFSET_ADDR_W            ( OFFSET_ADDR_W            ),
    .RD_LOOP_W                ( RD_LOOP_W                ),
    .TX_SIZE_WIDTH            ( TX_SIZE_WIDTH            ),
    //.ROM_ADDR_W               ( ROM_ADDR_W               )
    .D_TYPE_W                 ( D_TYPE_W                 )
  ) accelerator ( // PORTS
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .start                    ( start                    ),
    .done                     ( done                     ),

    .M_AXI_AWID               ( M_AXI_AWID               ),
    .M_AXI_AWADDR             ( M_AXI_AWADDR             ),
    .M_AXI_AWLEN              ( M_AXI_AWLEN              ),
    .M_AXI_AWSIZE             ( M_AXI_AWSIZE             ),
    .M_AXI_AWBURST            ( M_AXI_AWBURST            ),
    .M_AXI_AWLOCK             ( M_AXI_AWLOCK             ),
    .M_AXI_AWCACHE            ( M_AXI_AWCACHE            ),
    .M_AXI_AWPROT             ( M_AXI_AWPROT             ),
    .M_AXI_AWQOS              ( M_AXI_AWQOS              ),
    .M_AXI_AWVALID            ( M_AXI_AWVALID            ),
    .M_AXI_AWREADY            ( M_AXI_AWREADY            ),
    .M_AXI_WID                ( M_AXI_WID                ),
    .M_AXI_WDATA              ( M_AXI_WDATA              ),
    .M_AXI_WSTRB              ( M_AXI_WSTRB              ),
    .M_AXI_WLAST              ( M_AXI_WLAST              ),
    .M_AXI_WVALID             ( M_AXI_WVALID             ),
    .M_AXI_WREADY             ( M_AXI_WREADY             ),
    .M_AXI_BID                ( M_AXI_BID                ),
    .M_AXI_BRESP              ( M_AXI_BRESP              ),
    .M_AXI_BVALID             ( M_AXI_BVALID             ),
    .M_AXI_BREADY             ( M_AXI_BREADY             ),
    .M_AXI_ARID               ( M_AXI_ARID               ),
    .M_AXI_ARADDR             ( M_AXI_ARADDR             ),
    .M_AXI_ARLEN              ( M_AXI_ARLEN              ),
    .M_AXI_ARSIZE             ( M_AXI_ARSIZE             ),
    .M_AXI_ARBURST            ( M_AXI_ARBURST            ),
    .M_AXI_ARLOCK             ( M_AXI_ARLOCK             ),
    .M_AXI_ARCACHE            ( M_AXI_ARCACHE            ),
    .M_AXI_ARPROT             ( M_AXI_ARPROT             ),
    .M_AXI_ARQOS              ( M_AXI_ARQOS              ),
    .M_AXI_ARVALID            ( M_AXI_ARVALID            ),
    .M_AXI_ARREADY            ( M_AXI_ARREADY            ),
    .M_AXI_RID                ( M_AXI_RID                ),
    .M_AXI_RDATA              ( M_AXI_RDATA              ),
    .M_AXI_RRESP              ( M_AXI_RRESP              ),
    .M_AXI_RLAST              ( M_AXI_RLAST              ),
    .M_AXI_RVALID             ( M_AXI_RVALID             ),
    .M_AXI_RREADY             ( M_AXI_RREADY             )
  );
// ==================================================================

assign rd_req = dnn_accelerator_tb.accelerator.mem_ctrl_top.rd_req;
assign rd_req_size = dnn_accelerator_tb.accelerator.mem_ctrl_top.rd_req_size;

assign wr_done = dnn_accelerator_tb.accelerator.mem_ctrl_top.wr_done;
assign wr_req = dnn_accelerator_tb.accelerator.mem_ctrl_top.wr_req;
assign wr_req_size = dnn_accelerator_tb.accelerator.mem_ctrl_top.wr_req_size;
assign wr_addr = dnn_accelerator_tb.accelerator.mem_ctrl_top.wr_addr;

// ==================================================================
  dnn_accelerator_tb_driver #(
  // INPUT PARAMETERS
    .NUM_PE                   ( NUM_PE                   ),
    .NUM_PU                   ( NUM_PU                   ),
    .ADDR_W                   ( ADDR_W                   ),
    .BASE_ADDR_W              ( BASE_ADDR_W              ),
    .OFFSET_ADDR_W            ( OFFSET_ADDR_W            ),
    .RD_LOOP_W                ( RD_LOOP_W                ),
    .TX_SIZE_WIDTH            ( TX_SIZE_WIDTH            ),
    .D_TYPE_W                 ( D_TYPE_W                 ),
    .ROM_ADDR_W               ( ROM_ADDR_W               )
  ) driver ( // PORTS
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .start                    ( start                    ),
    .done                     ( done                     ),
    .rd_req                   ( rd_req                   ),
    .rd_ready                 (                          ),
    .rd_req_size              ( rd_req_size              ),
    .rd_addr                  ( rd_addr                  ),
    .wr_req                   ( wr_req                   ),
    .wr_done                  ( wr_done                  ),
    .wr_req_size              ( wr_req_size              ),
    .wr_addr                  ( wr_addr                  )
  );
// ==================================================================

// ==================================================================
axi_master_tb_driver
#(
    .AXI_DATA_WIDTH           ( DATA_W                   ),
    .OP_WIDTH                 ( OP_WIDTH                 ),
    .NUM_PE                   ( NUM_PE                   ),
    .BASE_ADDR                (BASE_ADDR                 ),
    .TX_SIZE_WIDTH            ( TX_SIZE_WIDTH            )
) u_axim_driver (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .M_AXI_AWID               ( M_AXI_AWID               ),
    .M_AXI_AWADDR             ( M_AXI_AWADDR             ),
    .M_AXI_AWLEN              ( M_AXI_AWLEN              ),
    .M_AXI_AWSIZE             ( M_AXI_AWSIZE             ),
    .M_AXI_AWBURST            ( M_AXI_AWBURST            ),
    .M_AXI_AWLOCK             ( M_AXI_AWLOCK             ),
    .M_AXI_AWCACHE            ( M_AXI_AWCACHE            ),
    .M_AXI_AWPROT             ( M_AXI_AWPROT             ),
    .M_AXI_AWQOS              ( M_AXI_AWQOS              ),
    .M_AXI_AWVALID            ( M_AXI_AWVALID            ),
    .M_AXI_AWREADY            ( M_AXI_AWREADY            ),
    .M_AXI_WID                ( M_AXI_WID                ),
    .M_AXI_WDATA              ( M_AXI_WDATA              ),
    .M_AXI_WSTRB              ( M_AXI_WSTRB              ),
    .M_AXI_WLAST              ( M_AXI_WLAST              ),
    .M_AXI_WVALID             ( M_AXI_WVALID             ),
    .M_AXI_WREADY             ( M_AXI_WREADY             ),
    .M_AXI_BID                ( M_AXI_BID                ),
    .M_AXI_BRESP              ( M_AXI_BRESP              ),
    .M_AXI_BVALID             ( M_AXI_BVALID             ),
    .M_AXI_BREADY             ( M_AXI_BREADY             ),
    .M_AXI_ARID               ( M_AXI_ARID               ),
    .M_AXI_ARADDR             ( M_AXI_ARADDR             ),
    .M_AXI_ARLEN              ( M_AXI_ARLEN              ),
    .M_AXI_ARSIZE             ( M_AXI_ARSIZE             ),
    .M_AXI_ARBURST            ( M_AXI_ARBURST            ),
    .M_AXI_ARLOCK             ( M_AXI_ARLOCK             ),
    .M_AXI_ARCACHE            ( M_AXI_ARCACHE            ),
    .M_AXI_ARPROT             ( M_AXI_ARPROT             ),
    .M_AXI_ARQOS              ( M_AXI_ARQOS              ),
    .M_AXI_ARVALID            ( M_AXI_ARVALID            ),
    .M_AXI_ARREADY            ( M_AXI_ARREADY            ),
    .M_AXI_RID                ( M_AXI_RID                ),
    .M_AXI_RDATA              ( M_AXI_RDATA              ),
    .M_AXI_RRESP              ( M_AXI_RRESP              ),
    .M_AXI_RLAST              ( M_AXI_RLAST              ),
    .M_AXI_RVALID             ( M_AXI_RVALID             ),
    .M_AXI_RREADY             ( M_AXI_RREADY             )
);
// ==================================================================

localparam integer ADDR_SIZE_W = ADDR_W + TX_SIZE_WIDTH;

reg [ADDR_SIZE_W-1:0] buffer [0:1023];
integer rd_ptr;
integer wr_ptr;
initial begin
  rd_ptr = 0;
  wr_ptr = 0;
end

always @(posedge clk)
  if (wr_req)
    put_addr_size;
/*
always @(posedge clk)
  if (wr_done )
    get_addr_size;
*/
task put_addr_size;
  reg [ADDR_W-1:0] addr;
  reg [TX_SIZE_WIDTH-1:0] tx_size;
  begin
    addr = wr_addr;
    tx_size = wr_req_size;
    buffer[wr_ptr] = {addr, tx_size};
    {addr, tx_size} = buffer[wr_ptr];
    wr_ptr = wr_ptr + 1;
    //$display ("Write pointer = %d", wr_ptr);
    //$display ("Requesting %d transactions at addr = %h", tx_size, addr);
  end
endtask

task get_addr_size;
  integer num_writes_finished;
  reg [ADDR_W-1:0] addr;
  reg [TX_SIZE_WIDTH-1:0] tx_size;
  begin
    num_writes_finished = wr_ptr - rd_ptr;
    repeat (num_writes_finished) begin
      {addr, tx_size} = buffer[rd_ptr];
      //$display("Finished %d transactions at address %h",
        //tx_size, addr);
`ifdef DEBUG
      print_mem(addr, tx_size);
`endif
      rd_ptr = rd_ptr+1;
    //$display ("Read pointer = %d", rd_ptr);
    end
  end
endtask

always @(posedge clk)
  if (wr_done )
    get_layerdata;

task get_layerdata;
  integer num_writes_finished;
  integer fp;
  reg [ADDR_W-1:0] addr;
  reg [TX_SIZE_WIDTH-1:0] tx_size;
  integer ii;
  reg signed [16-1:0] tmp;
  begin
    num_writes_finished = wr_ptr - rd_ptr;
   if(accelerator.PU_GEN[0].u_PU.u_controller.l==1)
   begin
       fp=$fopen("conv1.txt","w");
   end
   else if(accelerator.PU_GEN[0].u_PU.u_controller.l==2)
   begin
       fp=$fopen("conv2.txt","w");
   end
   else if(accelerator.PU_GEN[0].u_PU.u_controller.l==3)
   begin
       fp=$fopen("ip1.txt","w");
   end
   else if(accelerator.PU_GEN[0].u_PU.u_controller.l==0)
   begin
       fp=$fopen("ip2.txt","w");
   end
    repeat (num_writes_finished) begin
      {addr, tx_size} = buffer[rd_ptr];
        addr= (addr-BASE_ADDR)>>1;
//        $display("WriteFile:: Printing memory at address %h", addr);
        for (ii=0; ii<tx_size*4; ii=ii+1) begin
          tmp = u_axim_driver.ddr_ram[addr+ii];
             //$fwrite(fp,"%d\n",(tmp));
             $fwrite(fp,"Addr: %x, Data %x\n",addr+ii,(tmp));
        end
      rd_ptr = rd_ptr+1;
    end
    $fclose(fp);
  end
endtask

`ifdef DEBUG
integer fp_ip;
integer ip_cnt;
reg signed [15:0] op0,op1,opadd;
initial begin
    fp_ip=$fopen("ip1.csv","w");
    ip_cnt=0;
   wait(accelerator.PU_GEN[0].u_PU.u_controller.l==2);
   repeat(20) @(posedge clk);
    while(ip_cnt<801) begin
        @(posedge clk);
        if(accelerator.PU_GEN[0].u_PU.PE_GENBLK[0].u_PE.macc_enable==1) begin
            op0=accelerator.PU_GEN[0].u_PU.PE_GENBLK[0].u_PE.macc_op_0;
            op1=accelerator.PU_GEN[0].u_PU.PE_GENBLK[0].u_PE.macc_op_1;
            opadd=accelerator.PU_GEN[0].u_PU.PE_GENBLK[0].u_PE.macc_op_add;
            $fdisplay(fp_ip,"%d,%d,%d,%d",op0,op1,opadd,accelerator.PU_GEN[0].u_PU.PE_GENBLK[0].u_PE.MACC_pe.out_reg);
            ip_cnt<= ip_cnt+1;
        end
    end
    
    $fclose(fp_ip);
   
end
`endif
task print_mem;
  input [ADDR_W-1:0] addr;
  input [TX_SIZE_WIDTH-1:0] tx_size;
  integer ii;
  reg signed [16-1:0] tmp;
  begin
    addr = (addr-BASE_ADDR)>>1;
    $display("Printing memory at address %h", addr);
    for (ii=0; ii<tx_size*4; ii=ii+1) begin
      tmp = u_axim_driver.ddr_ram[addr+ii];
//MS
     // $write("%6d ", tmp);
     // $write("%f ", tmp);
     // $write("%x ", tmp);
     if(tmp[15]==1)
         $write("- %d ",(0-tmp));
     else 
         $write("+ %d ",(tmp));
      if (ii%4==3) $display;
    end
    $display;
  end
endtask
/// MS
`ifdef DEBUG
integer fp_expt;
integer expt_i;
reg signed [15:0] expdata;
initial begin
  expdata=0;
   fp_expt=$fopen("ip2weights.txt","r");
   $display( "Printing expected data : Final Layer");
  for(expt_i=0;expt_i<176;expt_i=expt_i+1) begin
   $fscanf(fp_expt,"%h",expdata);
   $display( "Data[%d]=%d",expt_i,expdata);
  end
  $fclose(fp_expt);
end
`endif
////////
integer in_addr;
integer in_dim[0:3];
integer w_addr;
integer w_dim[0:3];
integer num_layers;
integer l_count;
reg [4-1:0] l_type;
integer tmp_var;
integer tmp_var2;
initial begin
  $display("Getting MMAP from file ../hardware/include/tb_mmap.txt");
  $readmemb("../hardware/include/tb_mmap.vh", mmap_ram);
  num_layers = mmap_ram[0];
  for (l_count=0; l_count<num_layers; l_count=l_count+1)
  begin
    {l_type, in_addr, in_dim[0], in_dim[1], in_dim[2], in_dim[3], w_addr, w_dim[0], w_dim[1], w_dim[2], w_dim[3]} = mmap_ram[l_count+1];

    $display("*********************");
    $display("Layer Number %d", l_count);
    $display("Layer Type %d", l_type);

    $display("Input address = %h", in_addr);
    $display("Input size = %d x %d x %d x %d", in_dim[0], in_dim[1], in_dim[2], in_dim[3]);

    $display("Weight address = %h", w_addr);
    $display("Weight size = %d x %d x %d x %d", w_dim[0], w_dim[1], w_dim[2], w_dim[3]);
    $display("*********************");
 // original 
 //   if (l_type == 0 && l_count == 0) begin
    if (l_type == 0 ) begin
    //if (l_count <1 ) begin
      //if(l_count==0)
      //   initialize_stream(in_addr, in_dim[0], in_dim[1], in_dim[2], in_dim[3],l_count);
      //initialize_buffer(w_addr, w_dim[0], w_dim[1], w_dim[2], w_dim[3], 4,l_count);
    end
    else  if (l_type == 1) begin
      //initialize_buffer(in_addr, in_dim[0], in_dim[1], in_dim[2], in_dim[3], 0,l_count);
      //tmp_var = ceil_a_by_b(w_dim[2], NUM_PE);
      //tmp_var2 = ceil_a_by_b(w_dim[0], NUM_PE)*NUM_PE;
//      initialize_stream(w_addr, 1, 1, tmp_var2, w_dim[2]+1,l_count);
    end

  end
end

integer fp_input;
integer fp_weights_conv1;
task initialize_stream;
  input integer addr;
  input integer dim0;
  input integer dim1;
  input integer dim2;
  input integer dim3;
  input integer l_count;
  integer d0, d1, d2, d3;
  integer offset;
  integer d2_padded;
  integer val;
  begin
    $display("Initizlaizing stream for l_count: %d",l_count);
    if(l_count==0)begin 
      fp_input= $fopen("conv1_ip.txt","w");
    end
    $display("Initializing stream data at %h", addr);
    $display("Stream dimensions %d, %d, %d, %d", dim0, dim1, dim2, dim3);
    d2_padded = ceil_a_by_b(dim2, NUM_PE) * ceil_a_by_b(NUM_PE, 4) * 4;

    addr = (addr - BASE_ADDR) >> 1;
    $display("Padded dimensions = %d", d2_padded);
    for (d0=0; d0<dim0; d0=d0+1) begin
      for (d1=0; d1<dim1; d1=d1+1) begin
        for (d3=0; d3<dim3; d3=d3+1) begin
          for (d2=0; d2<d2_padded; d2=d2+1) begin
            offset = d2+d2_padded*(d3 + dim3 * d1);
            if (d2 < dim2)
              val = d2+dim2*(d3);
            else
              val = 0;
            u_axim_driver.ddr_ram[addr+offset] = val;
            
           if(l_count==0) 
              $fdisplay(fp_input,"Address %h: Value: %d", addr+offset, val);
            //$display("Address %h: Value: %d", addr+offset, val);
          end
        end
      end
    end
    if(l_count==0) 
     $fclose(fp_input);
  end
endtask
/*
task initialize_buffer;
  input integer addr;
  input integer dim0;
  input integer dim1;
  input integer dim2;
  input integer dim3;
  input integer bias_size;
  input integer l_count;
  integer d0, d1, d2, d3;
  integer data;
  integer offset, val;
  integer wlen;
  begin
    if(l_count==0) 
       fp_weights_conv1= $fopen("weights_conv1.txt","w");
    $display("Initializing buffer data at %h", addr);
    $display("Buffer dimensions %d, %d, %d, %d", dim0, dim1, dim2, dim3);
    addr = (addr-32'h08000000)>>1;
    wlen = (ceil_a_by_b(dim2*dim3, 4)*4+bias_size);
    //d1 = input channels
    //d0 = output channels
    for (d1=0; d1<dim1; d1=d1+1) begin
      for (d0=0; d0<dim0; d0=d0+1) begin
        for (d2=0; d2<wlen; d2=d2+1) begin
          offset = d2+wlen*(d1+dim1*d0);
          data= offset+lcount*10;
          if (d2 >= bias_size)
            val =data ;
          else
            val = 64'h0;
          u_axim_driver.ddr_ram[addr+offset] = {val,val};
          if(l_count==0) 
          $fdisplay(fp_weights_conv1,"Address %h: Value: %d", addr+offset, ddr_ram[addr+offset]);
        end
      end
    end
          if(l_count==0) 
          $fclose(fp_weights_conv1);
  end
endtask */
///// MS
task initialize_buffer;
  input integer addr;
  input integer dim0;
  input integer dim1;
  input integer dim2;
  input integer dim3;
  input integer bias_size;
  input integer l_count;
  integer d0, d1, d2, d3;
  integer data;
  integer offset, val;
  integer wlen;
  integer num_mem;
  reg[15:0] i; 
  begin
    i=0;
    if(l_count==0) 
       fp_weights_conv1= $fopen("weights_conv1.txt","w");
    $display("Initializing buffer data at %h", addr);
    $display("Buffer dimensions %d, %d, %d, %d", dim0, dim1, dim2, dim3);
    addr = (addr-BASE_ADDR);
    wlen = (ceil_a_by_b(dim2*dim3, 4)*4+bias_size)*2; // NUm Bytes
    num_mem= wlen/8;
    //d1 = input channels
    //d0 = output channels
    for (d1=0; d1<dim1; d1=d1+1) begin
      for (d0=0; d0<dim0; d0=d0+1) begin
        for (d2=0; d2<num_mem; d2=d2+1) begin
          offset = d2+num_mem*(d1+dim1*d0);
          data= offset+l_count*10;
          if (d2 >= bias_size*2/8)
            val =i+1 ;
          else
            val = 0;
          u_axim_driver.ddr_ram[addr+offset] = {val,val};
          if(l_count==0) 
          $fdisplay(fp_weights_conv1,"Address %h: Value: %d", addr+offset, u_axim_driver.ddr_ram[addr+offset]);
        end
      end
    end
          if(l_count==0) 
          $fclose(fp_weights_conv1);
  end
endtask
///MS
integer fp_poolout;
initial begin
   fp_poolout=$fopen("conv1_pool1.txt","w");
    wait(accelerator.PU_GEN[0].u_PU.u_controller.l_inc==1)
    #2000;
    $fclose(fp_poolout);
    //$stop;
end

always @(posedge clk) begin
    if(l_count==0 && accelerator.PU_GEN[0].pu_write_req==1) begin
         $fdisplay(fp_poolout,"%h",accelerator.PU_GEN[0].pu_write_data);
    end 
end

initial begin

end
endmodule
