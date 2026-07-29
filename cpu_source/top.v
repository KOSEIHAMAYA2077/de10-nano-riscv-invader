/*
 * Game SoC integration for this project.
 *
 * CPU, program memory, framebuffer, game registers, keys, and performance
 * counters share a small memory-mapped bus.
 */
`timescale 1ns / 1ps
`define DATFILE "memfile.dat"

module game_data_memory(
    input         clk,
    input         write_enable,
    input  [31:0] byte_address,
    input  [31:0] write_data,
    output [31:0] read_data
);
    reg [31:0] words [0:511];
    wire [8:0] word_address = byte_address[10:2];

    initial
        $readmemh(`DATFILE, words);

    assign read_data = words[word_address];

    always @(posedge clk)
        if (write_enable)
            words[word_address] <= write_data;
endmodule

module game_program_memory(
    input  [8:0]  word_address,
    output [31:0] instruction
);
    reg [31:0] words [0:511];

    initial
        $readmemh(`DATFILE, words);

    assign instruction = words[word_address];
endmodule

module game_soc(
    input clk,
    input reset,
    input [1:0] key_state_async,

    output [31:0] writedata,
    output [31:0] dataaddr,
    output        memwrite,

    // framebuffer write port 出力
    output        fb_we,
    output [15:0] fb_waddr,
    output [31:0] fb_wdata,

    output reg [8:0]  sprite0_x,
    output reg [7:0]  sprite0_y,
    output reg        sprite0_enable,
    output reg [23:0] sprite0_color,

    output reg [8:0]  sprite1_x,
    output reg [7:0]  sprite1_y,
    output reg        sprite1_enable,

    output reg [8:0]  enemy_base_x,
    output reg [7:0]  enemy_base_y,
    output reg [31:0] enemy_alive_lo,
    output reg [22:0] enemy_alive_hi,
    output reg        enemy_enable,
    output reg [7:0]  score_bcd,

    output reg [8:0]  enemy_bullet_x,
    output reg [7:0]  enemy_bullet_y,
    output reg        enemy_bullet_enable,

    output [31:0] perf_cycles,
    output        perf_running,
    output        perf_done_toggle,
    output        perf_under_60hz
    );

   wire [31:0] pc;
   wire [31:0] instr;
   wire [31:0] readdata;

   wire        cpu_memwrite;

   wire        fb_sel;
   wire        perf_sel;
   wire        key_sel;
   wire        sprite_sel;
   wire        dmem_sel;
   wire        dmem_we;
   wire        perf_we;
   wire        sprite_we;

   wire [31:0] dmem_addr;
   wire [31:0] dmem_readdata;
   wire [31:0] perf_rdata;
   wire [31:0] key_rdata;
   wire [31:0] sprite_rdata;

   reg [1:0] key_meta;
   reg [1:0] key_sync;

   always @(posedge clk or posedge reset) begin
      if (reset) begin
         key_meta <= 2'b00;
         key_sync <= 2'b00;
      end else begin
         key_meta <= key_state_async;
         key_sync <= key_meta;
      end
   end

   // ------------------------------
   // CPU core
   // ------------------------------
   riscv riscv (
      clk,
      reset,
      pc,
      instr,
      cpu_memwrite,
      dataaddr,
      writedata,
      readdata
   );

   // ------------------------------
   // Instruction memory
   // ------------------------------
   game_program_memory program_memory (pc[10:2], instr);

   // ------------------------------
   // Memory map
   //
   // 0x0000_0000 ～ 0x0003_83FF : framebuffer
   // 0x0004_0000 ～              : dmem
   // 0x0008_0000 ～ 0x0008_000F : performance counter
   // 0x0008_0010                 : KEY state
   // 0x0008_0020 ～ 0x0008_002F : sprite0 registers
   // 0x0008_0030 ～ 0x0008_003B : sprite1 registers
   // 0x0008_0040 ～ 0x0008_0054 : enemy grid + score registers
   // 0x0008_0058 ～ 0x0008_0060 : enemy_bullet registers (x, y, enable)
   // ------------------------------
   assign perf_sel = (dataaddr >= 32'h0008_0000) &&
                     (dataaddr <  32'h0008_0010);

   assign key_sel  = (dataaddr >= 32'h0008_0010) &&
                     (dataaddr <  32'h0008_0014);

   assign sprite_sel = (dataaddr >= 32'h0008_0020) &&
                       (dataaddr <  32'h0008_0064);

   assign key_rdata = {30'd0, key_sync};

   assign fb_sel   = (dataaddr < 32'h0003_8400);
   assign dmem_sel = (dataaddr >= 32'h0004_0000) &&
                     !perf_sel && !key_sel && !sprite_sel;

   assign sprite_we = cpu_memwrite && sprite_sel &&
                      (dataaddr[1:0] == 2'b00);

   always @(posedge clk or posedge reset) begin
      if (reset) begin
         sprite0_x      <= 9'd295;
         sprite0_y      <= 8'd82;
         sprite0_enable <= 1'b0;
         sprite0_color  <= 24'h00FF00;
         sprite1_x      <= 9'd0;
         sprite1_y      <= 8'd0;
         sprite1_enable <= 1'b0;
         enemy_base_x   <= 9'd20;
         enemy_base_y   <= 8'd18;
         enemy_alive_lo <= 32'hFFFFFFFF;
         enemy_alive_hi <= 23'h7FFFFF;
         enemy_enable   <= 1'b0;
         score_bcd      <= 8'h00;
         enemy_bullet_x      <= 9'd0;
         enemy_bullet_y      <= 8'd0;
         enemy_bullet_enable <= 1'b0;
      end else if (sprite_we) begin
         case (dataaddr[6:2])
            5'd8:  sprite0_x      <= writedata[8:0];
            5'd9:  sprite0_y      <= writedata[7:0];
            5'd10: sprite0_enable <= writedata[0];
            5'd11: sprite0_color  <= writedata[23:0];
            5'd12: sprite1_x      <= writedata[8:0];
            5'd13: sprite1_y      <= writedata[7:0];
            5'd14: sprite1_enable <= writedata[0];
            5'd16: enemy_base_x   <= writedata[8:0];
            5'd17: enemy_base_y   <= writedata[7:0];
            5'd18: enemy_alive_lo <= writedata[31:0];
            5'd19: enemy_alive_hi <= writedata[22:0];
            5'd20: enemy_enable   <= writedata[0];
            5'd21: score_bcd      <= writedata[7:0];
            5'd22: enemy_bullet_x      <= writedata[8:0];
            5'd23: enemy_bullet_y      <= writedata[7:0];
            5'd24: enemy_bullet_enable <= writedata[0];
            default: ;
         endcase
      end
   end

   assign sprite_rdata =
      (dataaddr[6:2] == 5'd8)  ? {23'd0, sprite0_x} :
      (dataaddr[6:2] == 5'd9)  ? {24'd0, sprite0_y} :
      (dataaddr[6:2] == 5'd10) ? {31'd0, sprite0_enable} :
      (dataaddr[6:2] == 5'd11) ? {8'd0, sprite0_color} :
      (dataaddr[6:2] == 5'd12) ? {23'd0, sprite1_x} :
      (dataaddr[6:2] == 5'd13) ? {24'd0, sprite1_y} :
      (dataaddr[6:2] == 5'd14) ? {31'd0, sprite1_enable} :
      (dataaddr[6:2] == 5'd16) ? {23'd0, enemy_base_x} :
      (dataaddr[6:2] == 5'd17) ? {24'd0, enemy_base_y} :
      (dataaddr[6:2] == 5'd18) ? enemy_alive_lo :
      (dataaddr[6:2] == 5'd19) ? {9'd0, enemy_alive_hi} :
      (dataaddr[6:2] == 5'd20) ? {31'd0, enemy_enable} :
      (dataaddr[6:2] == 5'd21) ? {24'd0, score_bcd} :
      (dataaddr[6:2] == 5'd22) ? {23'd0, enemy_bullet_x} :
      (dataaddr[6:2] == 5'd23) ? {24'd0, enemy_bullet_y} :
      (dataaddr[6:2] == 5'd24) ? {31'd0, enemy_bullet_enable} :
                                32'h00000000;

   // ------------------------------
   // framebuffer write
   //
   // CPU dataaddr is byte address
   // framebuffer waddr is pixel index
   // 1 pixel = 4 byte
   // so fb_waddr = dataaddr >> 2
   // ------------------------------
   assign fb_we    = cpu_memwrite && fb_sel && (dataaddr[1:0] == 2'b00);
   assign fb_waddr = dataaddr[17:2];
   assign fb_wdata = writedata;

   // ------------------------------
   // dmem access
   //
   // dmem starts at 0x0004_0000 in CPU address space
   // but internal dmem address starts from 0
   // ------------------------------
   assign dmem_we   = cpu_memwrite && dmem_sel;
   assign dmem_addr = dmem_sel ? (dataaddr - 32'h0004_0000) : 32'h00000000;
   assign perf_we   = cpu_memwrite && perf_sel;

   game_data_memory data_memory (
      .clk          (clk),
      .write_enable (dmem_we),
      .byte_address (dmem_addr),
      .write_data   (writedata),
      .read_data    (dmem_readdata)
   );

   perf_counter u_perf_counter (
      .clk              (clk),
      .reset            (reset),

      .perf_we          (perf_we),
      .perf_addr        (dataaddr[3:0]),
      .perf_wdata       (writedata),
      .perf_rdata       (perf_rdata),

      .perf_cycles      (perf_cycles),
      .perf_running     (perf_running),
      .perf_done_toggle (perf_done_toggle),
      .perf_under_60hz  (perf_under_60hz)
   );


   // 現段階ではframebufferからのlwは未対応
   // dmem領域ならdmem_readdata
   // それ以外は0
   assign readdata =
      perf_sel ? perf_rdata :
      key_sel  ? key_rdata  :
      sprite_sel ? sprite_rdata :
      dmem_sel ? dmem_readdata :
      32'h00000000;

   // 外部観測用にCPU本来のmemwriteを出す
   assign memwrite = cpu_memwrite;

endmodule
