//--------------------------
// Simple MAC processing element
// - Does a multiply and add
// - Accumulates the output if inputs are valid
//--------------------------

module mac_pe #(
  parameter int unsigned DataWidthA = 8,
  parameter int unsigned DataWidthB = 8,
  parameter int unsigned DataWidthC = DataWidthA + DataWidthB
)(
  // Clock and reset
  input  logic                     clk_i,
  input  logic                     rst_ni,
  // Input operands
  input  logic signed [DataWidthA-1:0]    a_i,
  input  logic signed [DataWidthB-1:0]    b_i,
  // Valid signals for inputs
  input  logic                     a_valid_i,
  input  logic                     b_valid_i,
  // Clear signal for output
  input  logic                     acc_clr_i,
  // Output accumulation
  output logic signed [DataWidthC-1:0]    c_o
);

  // Wires and logic
  logic acc_valid;
  logic signed [DataWidthC-1:0] mult_result;

  assign acc_valid = a_valid_i && b_valid_i;
  assign mult_result = a_i * b_i;

  // Accumulation unit
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      c_o <= '0;
    end else if (acc_clr_i) begin
      c_o <= mult_result;
    end else if (acc_valid) begin
      c_o <= c_o + mult_result;
    end else begin
      c_o <= c_o;
    end
  end

endmodule
