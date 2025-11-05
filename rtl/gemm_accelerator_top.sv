// The controller for GeMM operation
module gemm_accelerator_top #(
    parameter int unsigned AddrWidth = 16,
    parameter int unsigned DataWidthA = 8,
    parameter int unsigned DataWidthB = 8,
    parameter int unsigned DataWidthC = 32,
    // Calculated parameters: The Address width for the SRAMs
    parameter int unsigned SRAMAddrWidthA = AddrWidth - $clog2(DataWidthA / 8),  // Example value
    parameter int unsigned SRAMAddrWidthB = AddrWidth - $clog2(DataWidthB / 8),  // Example value
    parameter int unsigned SRAMAddrWidthC = AddrWidth - $clog2(DataWidthC / 8)  // Example value
) (
    input logic clk_i,
    input logic rst_ni,
    input logic start_i,
    input logic [AddrWidth-1:0] M_size_i,
    input logic [AddrWidth-1:0] K_size_i,
    input logic [AddrWidth-1:0] N_size_i,
    output logic [SRAMAddrWidthA-1:0] sram_a_addr_o,
    output logic [SRAMAddrWidthB-1:0] sram_b_addr_o,
    output logic [SRAMAddrWidthC-1:0] sram_c_addr_o,
    input logic [DataWidthA-1:0] sram_a_rdata_i,
    input logic [DataWidthB-1:0] sram_b_rdata_i,
    output logic [DataWidthC-1:0] sram_c_wdata_o,
    output logic sram_c_we_o,
    output logic done_o
);

  logic [AddrWidth-1:0] M_count;
  logic [AddrWidth-1:0] K_count;
  logic [AddrWidth-1:0] N_count;

  gemm_controller #(
      .AddrWidth(AddrWidth)
  ) i_gemm_controller (
      .clk_i,
      .rst_ni,
      .start_i,
      .result_valid_o(sram_c_we_o),
      .done_o,
      .M_size_i,
      .K_size_i,
      .N_size_i,
      .M_count_o(M_count),
      .K_count_o(K_count),
      .N_count_o(N_count)
  );

  // Address generation logic: Assume the matrices are stored in row-major order
  // Please be adjust this part to align with your designed memory layout
  assign sram_a_addr_o = (M_count * K_size_i + K_count);
  assign sram_b_addr_o = (K_count * N_size_i + N_count);
  assign sram_c_addr_o = (M_count * N_size_i + N_count);

  // The MAC PE instantiation and data path logics
  mac_pe #(
      .InputDataWidth (DataWidthA),
      .OutputDataWidth(DataWidthC)
  ) i_mac_pe (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .a_i(sram_a_rdata_i),
      .b_i(sram_b_rdata_i),
      .a_valid_i(1'b1),  // Assuming data is always valid as there is no contention on SRAM resources
      .b_valid_i(1'b1),  // Assuming data is always valid as there is no contention on SRAM resources
      .acc_clr_i(sram_c_we_o),  // Clear accumulator when writing back
      .c_o(sram_c_wdata_o)
  );

endmodule
