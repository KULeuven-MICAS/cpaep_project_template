# CPAEP Project Template
- This project template is for the CPAEP class for the AY 2025-2026 in KU Leuven
- This template serves as a base repository for running RTL simulations.
- Preferrably, setup your work in a linux subsystem

# Quick Start

1. First install pixi shell. You do this once if you don't have pixi shell in your environment yet.

```bash
curl -fsSL https://pixi.sh/install.sh | bash
```

2a. Initialize the pixi environment

```bash
pixi shell
```

2b. Check if Verilator works. It should return the latest version.

```bash
verilator --version
```

3. Build a verilator executable

```bash
make TEST_MODULE=tb_mac_pe all
```

4. Run the executable

```bash
bin/tb_mac_pe
```

The last command show show a log of outputs:

```bash
A:    45, B:    86, OUT:  3870
A:    38, B:     8, OUT:  4174
A:    55, B:    67, OUT:  7859
A:     7, B:    91, OUT:  8496
A:    37, B:    62, OUT: 10790
A:    93, B:    62, OUT: 16556
A:    27, B:    12, OUT: 16880
A:    83, B:    43, OUT: 20449
A:     9, B:    97, OUT: 21322
A:    60, B:    34, OUT: 23362
- tb/tb_mac_pe.sv:78: Verilog $finish
- S i m u l a t i o n   R e p o r t: Verilator 5.034 2025-02-24
- Verilator: $finish at 210ps; walltime 0.006 s; speed 25.882 ns/s
- Verilator: cpu 0.008 s on 1 threads; alloced 249 MB
```