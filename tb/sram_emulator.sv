module sram_emulator #(
  parameter int unsigned NumWords     = 32'd1024, // Number of Words in data array
  parameter int unsigned DataWidth    = 32'd128,  // Data signal width
  parameter int unsigned ByteWidth    = 32'd8,    // Width of a data byte: This defines the granularity of the write byte enable
  parameter int unsigned NumPorts     = 32'd1,    // Number of read and write ports: Do not  use values other than 1 in this project
  parameter int unsigned Latency      = 32'd0,    // Latency when the read data is available: Do not use values other than 0 in this project
  parameter              SimInit      = "zeros",  // Simulation initialization: Do not modify this parameter in this project
  // DEPENDENT PARAMETERS, DO NOT OVERWRITE!
  parameter int unsigned AddrWidth = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1,
  parameter int unsigned BeWidth   = (DataWidth + ByteWidth - 32'd1) / ByteWidth, // ceil_div
  parameter type         addr_t    = logic [AddrWidth-1:0],
  parameter type         data_t    = logic [DataWidth-1:0],
  parameter type         be_t      = logic [BeWidth-1:0]
) (
  input  logic                 clk_i,      // Clock
  input  logic                 rst_ni,     // Asynchronous reset active low
  // input ports
  input  logic  [NumPorts-1:0] req_i,      // request
  input  logic  [NumPorts-1:0] we_i,       // write enable
  input  addr_t [NumPorts-1:0] addr_i,     // request address
  input  data_t [NumPorts-1:0] wdata_i,    // write data
  input  be_t   [NumPorts-1:0] be_i,       // write byte enable
  // output ports
  output data_t [NumPorts-1:0] rdata_o     // read data
);

  // memory array
  data_t sram [NumWords-1:0];
  // hold the read address when no read access is made
  addr_t [NumPorts-1:0] r_addr_q;

  // SRAM simulation initialization
  data_t init_val[NumWords-1:0];
  initial begin : proc_sram_init
    for (int unsigned i = 0; i < NumWords; i++) begin
      case (SimInit)
        "zeros":  init_val[i] = {DataWidth{1'b0}};
        "ones":   init_val[i] = {DataWidth{1'b1}};
        "random": init_val[i] = {DataWidth{$urandom()}};
        default:  init_val[i] = {DataWidth{1'bx}};
      endcase
    end
  end

  // set the read output if requested
  // The read data at the highest array index is set combinational.
  // It gets then delayed for a number of cycles until it gets available at the output at
  // array index 0.

  // read data output assignment
  data_t [NumPorts-1:0][Latency-1:0] rdata_q,  rdata_d;
  if (Latency == 32'd0) begin : gen_no_read_lat
    for (genvar i = 0; i < NumPorts; i++) begin : gen_port
      assign rdata_o[i] = (req_i[i] && !we_i[i]) ? sram[addr_i[i]] : sram[r_addr_q[i]];
    end
  end else begin : gen_read_lat

    always_comb begin
      for (int unsigned i = 0; i < NumPorts; i++) begin
        rdata_o[i] = rdata_q[i][0];
        for (int unsigned j = 0; j < (Latency-1); j++) begin
          rdata_d[i][j] = rdata_q[i][j+1];
        end
        rdata_d[i][Latency-1] = (req_i[i] && !we_i[i]) ? sram[addr_i[i]] : sram[r_addr_q[i]];
      end
    end
  end

  // In case simulation initialization is disabled (SimInit == 'none'), don't assign to the sram
  // content at all. This improves simulation performance in tools like verilator
  if (SimInit == "none") begin
    // write memory array without initialization
    always @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        for (int i = 0; i < NumPorts; i++) begin
          r_addr_q[i] <= {AddrWidth{1'b0}};
        end
      end else begin
        // read value latch happens before new data is written to the sram
        for (int unsigned i = 0; i < NumPorts; i++) begin
          if (Latency != 0) begin
            for (int unsigned j = 0; j < Latency; j++) begin
              rdata_q[i][j] <= rdata_d[i][j];
            end
          end
        end
        // there is a request for the SRAM, latch the required register
        for (int unsigned i = 0; i < NumPorts; i++) begin
          if (req_i[i]) begin
            if (we_i[i]) begin
              // update value when write is set at clock
              for (int unsigned j = 0; j < BeWidth; j++) begin
                if (be_i[i][j]) begin
                  sram[addr_i[i]][j*ByteWidth+:ByteWidth] <= wdata_i[i][j*ByteWidth+:ByteWidth];
                end
              end
            end else begin
              // otherwise update read address for subsequent non request cycles
              r_addr_q[i] <= addr_i[i];
            end
          end // if req_i
        end // for ports
      end // if !rst_ni
    end
  end else begin
    // write memory array
    always @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        sram <= init_val;
        for (int i = 0; i < NumPorts; i++) begin
          r_addr_q[i] <= {AddrWidth{1'b0}};
          // initialize the read output register for each port
          if (Latency != 32'd0) begin
            for (int unsigned j = 0; j < Latency; j++) begin
              rdata_q[i][j] <= init_val[{AddrWidth{1'b0}}];
            end
          end
        end
      end else begin
        // read value latch happens before new data is written to the sram
        for (int unsigned i = 0; i < NumPorts; i++) begin
          if (Latency != 0) begin
            for (int unsigned j = 0; j < Latency; j++) begin
              rdata_q[i][j] <= rdata_d[i][j];
            end
          end
        end
        // there is a request for the SRAM, latch the required register
        for (int unsigned i = 0; i < NumPorts; i++) begin
          if (req_i[i]) begin
            if (we_i[i]) begin
              // update value when write is set at clock
              for (int unsigned j = 0; j < BeWidth; j++) begin
                if (be_i[i][j]) begin
                  sram[addr_i[i]][j*ByteWidth+:ByteWidth] <= wdata_i[i][j*ByteWidth+:ByteWidth];
                end
              end
            end else begin
              // otherwise update read address for subsequent non request cycles
              r_addr_q[i] <= addr_i[i];
            end
          end // if req_i
        end // for ports
      end // if !rst_ni
    end
  end

// Validate parameters.
// pragma translate_off
`ifndef VERILATOR
`ifndef TARGET_SYNTHESIS
  initial begin: p_assertions
    assert ($bits(addr_i)  == NumPorts * AddrWidth) else $fatal(1, "AddrWidth problem on `addr_i`");
    assert ($bits(wdata_i) == NumPorts * DataWidth) else $fatal(1, "DataWidth problem on `wdata_i`");
    assert ($bits(be_i)    == NumPorts * BeWidth)   else $fatal(1, "BeWidth   problem on `be_i`"   );
    assert ($bits(rdata_o) == NumPorts * DataWidth) else $fatal(1, "DataWidth problem on `rdata_o`");
    assert (NumWords  >= 32'd1) else $fatal(1, "NumWords has to be > 0");
    assert (DataWidth >= 32'd1) else $fatal(1, "DataWidth has to be > 0");
    assert (ByteWidth >= 32'd1) else $fatal(1, "ByteWidth has to be > 0");
    assert (NumPorts  >= 32'd1) else $fatal(1, "The number of ports must be at least 1!");
  end
  for (genvar i = 0; i < NumPorts; i++) begin : gen_assertions
    assert property ( @(posedge clk_i) disable iff (!rst_ni)
        (req_i[i] |-> (addr_i[i] < NumWords))) else
      $warning("Request address %0h not mapped, port %0d, expect random write or read behavior!",
          addr_i[i], i);
  end

`endif
`endif
task automatic load_data(input string filename);
  begin
    // Initialization of the memory array
    foreach (sram[i]) sram[i] = '0;
    // Load data from file
    $readmemh(filename, sram);
    $display("Loaded data from %s into memory", filename);
  end
endtask
// pragma translate_on
endmodule