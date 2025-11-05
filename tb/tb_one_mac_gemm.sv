module tb_one_mac_gemm;
  ////////////////////////////
  // Design Time Parameters //
  ////////////////////////////

  // SRAM Parameters
  localparam int DataWidthA = 8;
  localparam int DataDepthA = 1024;
  localparam int DataWidthB = 8;
  localparam int DataDepthB = 1024;
  localparam int DataWidthC = 32;
  localparam int DataDepthC = 1024;

  // The address width for the system
  localparam int AddrWidthA = (DataDepthA <= 1) ? 1 : $clog2(DataDepthA);
  localparam int AddrWidthB = (DataDepthB <= 1) ? 1 : $clog2(DataDepthB);
  localparam int AddrWidthC = (DataDepthC <= 1) ? 1 : $clog2(DataDepthC);
  localparam int
  MaxDataDepth = (DataDepthA >= DataDepthB) ?
                                 ((DataDepthA >= DataDepthC) ? DataDepthA : DataDepthC) :
                                 ((DataDepthB >= DataDepthC) ? DataDepthB : DataDepthC);
  localparam int AddrWidth = (MaxDataDepth <= 1) ? 1 : $clog2(MaxDataDepth);

  ///////////////////
  // Test Sequence //
  ///////////////////
  `include "gen_data/tasks.svh"

  ////////////////////////////////////////////////////////////////////////////
  // Runtime Configurations, will be assigned with meaningful numbers later //
  ////////////////////////////////////////////////////////////////////////////

  int   M = 0;
  int   K = 0;
  int   N = 0;

  ////////////////////////
  // Start of Testbench //
  ////////////////////////

  // Clock and reset
  logic clk_i;
  logic rst_ni;
  logic start;
  initial begin
    clk_i = 1'b0;
    start = 1'b0;
    forever #5 clk_i = ~clk_i;  // 100MHz clock
  end
  initial begin
    rst_ni = 1'b0;
    #50;
    rst_ni = 1'b1;
  end

  // A, B, and C SRAM interfaces
  logic [AddrWidthA-1:0] sram_a_addr;
  logic [DataWidthA-1:0] sram_a_rdata;
  sram_emulator #(
      .NumWords (DataDepthA),
      .DataWidth(DataWidthA)
  ) i_sram_a (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .req_i(1'b1),
      .we_i(1'b0),
      .addr_i(sram_a_addr),
      .wdata_i('0),
      .be_i('0),
      .rdata_o(sram_a_rdata)
  );

  logic [AddrWidthB-1:0] sram_b_addr;
  logic [DataWidthB-1:0] sram_b_rdata;
  sram_emulator #(
      .NumWords (DataDepthB),
      .DataWidth(DataWidthB)
  ) i_sram_b (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .req_i(1'b1),
      .we_i(1'b0),
      .addr_i(sram_b_addr),
      .wdata_i('0),
      .be_i('0),
      .rdata_o(sram_b_rdata)
  );

  logic [AddrWidthC-1:0] sram_c_addr;
  logic [DataWidthC-1:0] sram_c_wdata;
  logic sram_c_we;
  sram_emulator #(
      .NumWords (DataDepthC),
      .DataWidth(DataWidthC)
  ) i_sram_c (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .req_i(1'b1),
      .we_i(sram_c_we),
      .addr_i(sram_c_addr),
      .wdata_i(sram_c_wdata),
      .be_i('1),
      .rdata_o()  // Not used
  );

  // GEMM Accelerator Top Module
  logic done;
  gemm_accelerator_top #(
      .DataWidthA(DataWidthA),
      .DataWidthB(DataWidthB),
      .DataWidthC(DataWidthC),
      .SRAMAddrWidthA(AddrWidthA),
      .SRAMAddrWidthB(AddrWidthB),
      .SRAMAddrWidthC(AddrWidthC)
  ) i_gemm_accelerator (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .start_i(start),
      .M_size_i(M[AddrWidth-1:0]),
      .K_size_i(K[AddrWidth-1:0]),
      .N_size_i(N[AddrWidth-1:0]),
      .sram_a_addr_o(sram_a_addr),
      .sram_b_addr_o(sram_b_addr),
      .sram_c_addr_o(sram_c_addr),
      .sram_a_rdata_i(sram_a_rdata),
      .sram_b_rdata_i(sram_b_rdata),
      .sram_c_wdata_o(sram_c_wdata),
      .sram_c_we_o(sram_c_we),
      .done_o(done)
  );

  // Test tasks
  task automatic load_MKN_a_b(input string dir);
    begin
      // Load M, K, N values
      string file_path;
      int fd;
      // build path and open file
      file_path = {dir, "/MKN.txt"};
      fd = $fopen(file_path, "r");
      if (fd == 0) begin
        $display("ERROR: cannot open %s", file_path);
        $fatal;
      end
      // read three decimal lines: M, K, N
      if ($fscanf(fd, "%d\n", M) != 1) begin
        $display("ERROR: failed to read M from %s", file_path);
        $fatal;
      end
      if ($fscanf(fd, "%d\n", K) != 1) begin
        $display("ERROR: failed to read K from %s", file_path);
        $fatal;
      end
      if ($fscanf(fd, "%d\n", N) != 1) begin
        $display("ERROR: failed to read N from %s", file_path);
        $fatal;
      end
      $fclose(fd);
      $display("Loaded sizes: M=%0d K=%0d N=%0d from %s", M, K, N, file_path);
      // Load matrix A
      i_sram_a.load_data({dir, "/A.hex"});
      // Load matrix B
      i_sram_b.load_data({dir, "/B.hex"});
    end
  endtask

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

  task automatic verify_result_c(input string dir);
    begin
      // Load expected matrix C
      logic [DataWidthC-1:0] expected_c_mem[DataDepthC-1:0];
      foreach (expected_c_mem[i]) expected_c_mem[i] = '0;
      $readmemh({dir, "/C.hex"}, expected_c_mem);
      // Compare with SRAM C contents
      for (int unsigned addr = 0; addr < DataDepthC; addr++) begin
        if (i_sram_c.sram[addr] !== expected_c_mem[addr]) begin
          $display("ERROR: Mismatch at address %0d: expected %h, got %h", addr,
                   expected_c_mem[addr], i_sram_c.sram[addr]);
          $fatal;
        end
      end
      $display("Result matrix C verification passed!");
    end
  endtask

  // Test control
  initial begin
    wait (rst_ni == 1'b1);
    @(posedge clk_i);
    foreach (tasks[i]) begin
      $display("Starting test task: %s", tasks[i]);
      // Load data
      load_MKN_a_b(tasks[i]);
      // Start GEMM operation and wait for completion
      start_and_wait_gemm();
      // Verify result
      verify_result_c(tasks[i]);
      $display("Completed test task: %s", tasks[i]);
    end
    $display("All test tasks completed successfully!");
    $finish;
  end

endmodule
