//--------------------------
// MAC PE Testbench
// - Unit test to check the functionality of the PE
//--------------------------

module tb_mac_pe;

  // Parameters
  parameter DATA_WIDTH = 16;

  // Inputs
  logic clk_i;
  logic rst_ni;
  logic [DATA_WIDTH-1:0] a_i, b_i;
  logic a_valid_i, b_valid_i;
  logic acc_clr_i;

  // Outputs
  logic [2*DATA_WIDTH-1:0] c_o;

  // Include some common tasks
  `include "includes/common_tasks.svh"

  // Instantiate the MAC PE module
  mac_pe #(
      .DataWidthA(DATA_WIDTH),
      .DataWidthB(DATA_WIDTH)
  ) i_mac_pe (
      .clk_i    (clk_i),
      .rst_ni   (rst_ni),
      .a_i      (a_i),
      .b_i      (b_i),
      .a_valid_i(a_valid_i),
      .b_valid_i(b_valid_i),
      .acc_clr_i(acc_clr_i),
      .c_o      (c_o)
  );

  // Clock generation
  initial begin
    clk_i = 0;
    forever #5 clk_i = ~clk_i;  // Toggle clock every 5 time units
  end

  // Test sequence
  initial begin
    $dumpfile("tb_mac_pe.vcd");
    $dumpvars(0, tb_mac_pe);

    // Initialize inputs
    clk_i     = 0;
    rst_ni    = 0;
    a_i       = 0;
    b_i       = 0;
    a_valid_i = 0;
    b_valid_i = 0;
    acc_clr_i = 0;

    clk_delay(3);

    // Release reset
    #1;
    rst_ni = 1;

    clk_delay(3);

    // Wait for a few clock cycles
    for (int i = 0; i < 10; i++) begin
      a_i = $urandom_range(100);  // Random value for A
      b_i = $urandom_range(100);  // Random value for B
      a_valid_i = 1;
      b_valid_i = 1;
      @(posedge clk_i);
      $display("A: %d, B: %d, OUT: %d", a_i, b_i, c_o);
    end

    // Finish simulation after some time
    clk_delay(5);

    $finish;
  end

endmodule
