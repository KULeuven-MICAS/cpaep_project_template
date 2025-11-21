module tb_gemm_top;
  //---------------------------
  // Design Time Parameters
  //---------------------------
  parameter int unsigned InDataWidth = 8;
  parameter int unsigned OutDataWidth = 32;

  // SRAM Parameters
  localparam int DataWidthA = InDataWidth;
  localparam int DataDepthA = 4096;
  localparam int DataWidthB = InDataWidth;
  localparam int DataDepthB = 4096;
  localparam int DataWidthC = OutDataWidth;
  localparam int DataDepthC = 4096;

  // The address width for the system
  localparam int AddrWidthA = (DataDepthA <= 1) ? 1 : $clog2(DataDepthA);
  localparam int AddrWidthB = (DataDepthB <= 1) ? 1 : $clog2(DataDepthB);
  localparam int AddrWidthC = (DataDepthC <= 1) ? 1 : $clog2(DataDepthC);
  localparam int
  MaxDataDepth = (DataDepthA >= DataDepthB) ?
                                 ((DataDepthA >= DataDepthC) ? DataDepthA : DataDepthC) :
                                 ((DataDepthB >= DataDepthC) ? DataDepthB : DataDepthC);
  localparam int AddrWidth = (MaxDataDepth <= 1) ? 1 : $clog2(MaxDataDepth);

  //---------------------------
  // Test Parameters
  //---------------------------
  localparam int unsigned MaxNum = 32;

  //---------------------------
  // Test Sequence
  //---------------------------
  `include "gen_data/tasks.svh"

  //---------------------------
  // Runtime Configurations, 
  // will be assigned with meaningful numbers later
  //---------------------------
  localparam int unsigned NumTests = 10;

  logic signed [ InDataWidth-1:0] W_memory [4608];
  logic signed [ InDataWidth-1:0] X_memory [4608];
  logic signed [OutDataWidth-1:0] Y_memory [4608];

  function automatic void gemm_golden(
    input  logic [AddrWidth-1:0] M,
    input  logic [AddrWidth-1:0] K,
    input  logic [AddrWidth-1:0] N,
    input  logic signed [ InDataWidth-1:0] W_i [4608],
    input  logic signed [ InDataWidth-1:0] X_i [4608],
    output logic signed [OutDataWidth-1:0] Y_o [4608]
  );
      int unsigned m, n, k;
      int signed acc;

      for (m = 0; m < M; m++) begin
          for (n = 0; n<N; n++) begin
            acc = 0;
            for (k = 0; k < K; k++) begin
              acc += $signed(W_i[m*K + k]) * $signed(X_i[k*N + n]);
            end
            Y_o[m*N + n] = acc;
          end
      end
  endfunction


  logic [AddrWidthA-1:0] sram_a_addr;
  logic [DataWidthA-1:0] sram_a_rdata;
  logic [AddrWidthB-1:0] sram_b_addr;
  logic [DataWidthB-1:0] sram_b_rdata;

  logic [AddrWidth-1:0] M_i, K_i, N_i;

  //---------------------------
  // Start of Testbench
  //---------------------------

  // Clock and reset
  logic clk_i;
  logic rst_ni;
  logic start;

  `include "includes/common_tasks.svh"

  initial begin
    clk_i = 1'b0;
    start = 1'b0;
    forever #5 clk_i = ~clk_i;  // 100MHz clock
  end
  

  logic [AddrWidthC-1:0] sram_c_addr;
  logic [DataWidthC-1:0] sram_c_wdata;
  logic sram_c_we;

  sram_emulator #(
      .NumWords (   DataDepthC ),
      .DataWidth(   DataWidthC )
  ) i_sram_c (
      .clk_i    (        clk_i ),
      .rst_ni   (       rst_ni ),
      .req_i    (         1'b1 ),
      .we_i     (    sram_c_we ),
      .addr_i   (  sram_c_addr ),
      .wdata_i  ( sram_c_wdata ),
      .be_i     (           '1 ),
      .rdata_o  (              )  // Not used
  );

  // GEMM Accelerator Top Module
  logic done;
  gemm_accelerator_top #(
      .DataWidthA     ( DataWidthA       ),
      .DataWidthB     ( DataWidthB       ),
      .DataWidthC     ( DataWidthC       ),
      .SRAMAddrWidthA ( AddrWidthA       ),
      .SRAMAddrWidthB ( AddrWidthB       ),
      .SRAMAddrWidthC ( AddrWidthC       )
  ) i_gemm_accelerator (
      .clk_i          ( clk_i            ),
      .rst_ni         ( rst_ni           ),
      .start_i        ( start            ),
      .M_size_i       ( M_i ),
      .K_size_i       ( K_i ),
      .N_size_i       ( N_i ),
      .sram_a_addr_o  ( sram_a_addr      ),
      .sram_b_addr_o  ( sram_b_addr      ),
      .sram_c_addr_o  ( sram_c_addr      ),
      .sram_a_rdata_i ( W_memory[sram_a_addr]     ),
      .sram_b_rdata_i ( X_memory[sram_b_addr]     ),
      .sram_c_wdata_o ( sram_c_wdata     ),
      .sram_c_we_o    ( sram_c_we        ),
      .done_o         ( done             )
  );

  task automatic start_and_wait_gemm();
    begin
      automatic int cycle_count;
      cycle_count = 0;
      // Start the GEMM operation
      @(posedge clk_i);
      start = 1'b1;
      @(posedge clk_i);
      start = 1'b0;
      while (done == 1'b0) begin
        @(posedge clk_i);
        cycle_count = cycle_count + 1;
        if (cycle_count > 100000) begin
          $display("ERROR: GEMM operation timeout after %0d cycles", cycle_count);
          $fatal;
        end
      end
      @(posedge clk_i);
      $display("GEMM operation completed in %0d cycles", cycle_count);
    end
  endtask

  task automatic verify_result_c(
    input logic signed [OutDataWidth-1:0] Y_o [4608],
    input logic fatal_on_mismatch
  );
    begin
      // Compare with SRAM C contents
      for (int unsigned addr = 0; addr < DataDepthC; addr++) begin
        if (i_sram_c.sram[addr] !== Y_o[addr]) begin
          $display("ERROR: Mismatch at address %0d: expected %h, got %h",
                  addr, Y_o[addr], i_sram_c.sram[addr]);
          if (fatal_on_mismatch)
            $fatal;
        end
      end
      $display("Result matrix C verification passed!");
    end
  endtask


  // Test control
  initial begin

    for (integer num_test = 0; num_test < NumTests; num_test++) begin
      $display("Starting test number: %0d", num_test);
      
      M_i = $urandom()%MaxNum+1;
      K_i = $urandom()%MaxNum+1;
      N_i = $urandom()%MaxNum+1;

      $display("M: %0d, K: %0d, N: %0d", M_i, K_i, N_i);

      for (integer m = 0; m < M_i; m++) begin
        for (integer k = 0; k < K_i; k++) begin
          W_memory[m*K_i + k] = $urandom()%(2**InDataWidth);
        end
      end

      for (integer k = 0; k < K_i; k++) begin
        for (integer n = 0; n < N_i; n++) begin
          X_memory[k*N_i + n] = $urandom()%(2**InDataWidth);
        end
      end

      gemm_golden(
        M_i,
        K_i,
        N_i,
        W_memory,
        X_memory,
        Y_memory
      );

      rst_ni = 1'b0;
      #50;
      rst_ni = 1'b1;

      clk_delay(3);

      start_and_wait_gemm();
      verify_result_c(Y_memory, 0);

      clk_delay(5);
    end
    
    $display("All test tasks completed successfully!");
    $finish;
  end

endmodule
