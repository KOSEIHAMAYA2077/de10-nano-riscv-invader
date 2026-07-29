# CPU subsystem

`riscv.v` is a new, project-specific RV32I implementation written from the
public RISC-V instruction-set specification. It replaces the earlier
textbook-derived CPU files; those files are not part of this copy.

The core keeps the existing SoC-facing interface:

- asynchronous instruction input with a byte-addressed program counter;
- a 32-bit data address and write-data bus;
- one write-enable signal;
- asynchronous 32-bit read data.

It implements the RV32I register/immediate ALU operations, conditional
branches, `LUI`, `AUIPC`, `JAL`, `JALR`, `LW`, and `SW`. Byte and halfword
stores are deliberately unsupported because the surrounding hardware has no
byte-enable signals. Unsupported encodings behave as a NOP and cannot assert
the memory write signal.

`top.v` contains the project-specific memory map and game peripherals. Its
top-level module is `game_soc`.

Before publishing the whole repository, choose a license for the original
project files and retain the existing notices on third-party Terasic and
Altera files.
