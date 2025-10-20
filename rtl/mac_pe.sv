//--------------------------
// Simple MAC processing element
// - Does a multiply and add
// - Accumulates the output if inputs are valid
//--------------------------

module mac_pe #(
  parameter int unsigned DATA_WIDTH = 16
)(
  // Clock and reset
  input  logic                     clk_i,
  input  logic                     rst_ni,
  // Input operands
  input  logic [DATA_WIDTH-1:0]    a_i,
  input  logic [DATA_WIDTH-1:0]    b_i,
  // Valid signals for inputs
  input  logic                     a_valid_i,
  input  logic                     b_valid_i,
  // Clear signal for output
  input  logic                     acc_clr_i,
  // Output accumulation
  output logic [2*DATA_WIDTH-1:0]    acc_o
);

  // Wires and logic
  logic acc_valid;
  logic [2*DATA_WIDTH-1:0] mult_result;

  assign acc_valid = a_valid_i || b_valid_i;
  assign mult_result = a_i * b_i;

  // Accumulation unit
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      acc_o <= {2*DATA_WIDTH{1'b0}};
    end else if (acc_clr_i) begin
      acc_o <= {2*DATA_WIDTH{1'b0}};
    end else if (acc_valid) begin
      acc_o <= acc_o + mult_result;
    end else begin
      acc_o <= acc_o;
    end
  end

endmodule