// --------------------------------------------------------------------
// Copyright (c) 2007 by Terasic Technologies Inc. 
// --------------------------------------------------------------------
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development 
//   Kits made by Terasic.  Other use of this code, including the selling 
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use 
//   or functionality of this code.
//
// --------------------------------------------------------------------
//           
//                     Terasic Technologies Inc
//                     356 Fu-Shin E. Rd Sec. 1. JhuBei City,
//                     HsinChu County, Taiwan
//                     302
//
//                     web: http://www.terasic.com/
//                     email: support@terasic.com
//
// --------------------------------------------------------------------

`include "vpg.h"

module vpg(
	clk_50,
	reset_n,
	mode,
	mode_change,
	key_pressed,
	vpg_pclk,
	vpg_de,
	vpg_hs,
	vpg_vs,
	vpg_r,
	vpg_g,
	vpg_b,
	perf_cycles,
	perf_running,
	perf_done_toggle,
	perf_under_60hz
);

input					clk_50;
input					reset_n;
input		[3:0]		mode;
input					mode_change;
input		[1:0]		key_pressed;
output				vpg_pclk;
output				vpg_de;
output				vpg_hs;
output				vpg_vs;
output	[7:0]		vpg_r;
output	[7:0]		vpg_g;
output	[7:0]		vpg_b;
output	[31:0]	perf_cycles;
output				perf_running;
output				perf_done_toggle;
output				perf_under_60hz;

//=======================================================
//  Signal declarations
//=======================================================
//=============== PLL reconfigure
wire [63:0] reconfig_to_pll, reconfig_from_pll;
wire        gen_clk_locked;
wire [31:0] mgmt_readdata, mgmt_writedata;
wire        mgmt_read, mgmt_write;
wire [5:0]  mgmt_address;
//============= assign timing constant  
reg  [11:0] h_total, h_sync, h_start, h_end; 
reg  [11:0] v_total, v_sync, v_start, v_end; 
reg  [11:0] v_active_14, v_active_24, v_active_34; 

// framebuffer demo signals
wire        timing_hs;
wire        timing_vs;
wire        timing_de;
wire [7:0]  timing_r;
wire [7:0]  timing_g;
wire [7:0]  timing_b;

wire        fb_we;
wire [15:0] fb_waddr;
wire [31:0] fb_wdata;

wire [15:0] fb_raddr;
wire [31:0] fb_rdata;

wire        reader_de;
wire        reader_hs;
wire        reader_vs;
wire [23:0] reader_rgb;
wire [8:0]  reader_fb_x;
wire [7:0]  reader_fb_y;
wire [23:0] after0_rgb;
wire [23:0] after_enemy_rgb;
wire [23:0] after_bullet_rgb;
wire [23:0] final_rgb;
reg         output_de;
reg         output_hs;
reg         output_vs;
reg  [23:0] output_rgb;

// game SoC からの信号
wire [31:0] cpu_writedata;
wire [31:0] cpu_dataaddr;
wire        cpu_memwrite;
wire        cpu_reset;
wire [8:0]  cpu_sprite0_x;
wire [7:0]  cpu_sprite0_y;
wire        cpu_sprite0_enable;
wire [23:0] cpu_sprite0_color;
wire [8:0]  cpu_sprite1_x;
wire [7:0]  cpu_sprite1_y;
wire        cpu_sprite1_enable;
wire [8:0]  cpu_enemy_base_x;
wire [7:0]  cpu_enemy_base_y;
wire [31:0] cpu_enemy_alive_lo;
wire [22:0] cpu_enemy_alive_hi;
wire        cpu_enemy_enable;
wire [7:0]  cpu_score_bcd;
wire [8:0]  cpu_enemy_bullet_x;
wire [7:0]  cpu_enemy_bullet_y;
wire        cpu_enemy_bullet_enable;

reg [8:0]  sprite0_x_meta;
reg [8:0]  sprite0_x_sync;
reg [8:0]  sprite0_x_video;
reg [7:0]  sprite0_y_meta;
reg [7:0]  sprite0_y_sync;
reg [7:0]  sprite0_y_video;
reg        sprite0_enable_meta;
reg        sprite0_enable_sync;
reg        sprite0_enable_video;
reg [23:0] sprite0_color_meta;
reg [23:0] sprite0_color_sync;
reg [23:0] sprite0_color_video;
reg [8:0]  sprite1_x_meta;
reg [8:0]  sprite1_x_sync;
reg [8:0]  sprite1_x_video;
reg [7:0]  sprite1_y_meta;
reg [7:0]  sprite1_y_sync;
reg [7:0]  sprite1_y_video;
reg        sprite1_enable_meta;
reg        sprite1_enable_sync;
reg        sprite1_enable_video;
reg [8:0]  enemy_base_x_meta;
reg [8:0]  enemy_base_x_sync;
reg [8:0]  enemy_base_x_video;
reg [7:0]  enemy_base_y_meta;
reg [7:0]  enemy_base_y_sync;
reg [7:0]  enemy_base_y_video;
reg [31:0] enemy_alive_lo_meta;
reg [31:0] enemy_alive_lo_sync;
reg [31:0] enemy_alive_lo_video;
reg [22:0] enemy_alive_hi_meta;
reg [22:0] enemy_alive_hi_sync;
reg [22:0] enemy_alive_hi_video;
reg        enemy_enable_meta;
reg        enemy_enable_sync;
reg        enemy_enable_video;
reg [7:0]  score_bcd_meta;
reg [7:0]  score_bcd_sync;
reg [7:0]  score_bcd_video;
reg [8:0]  enemy_bullet_x_meta;
reg [8:0]  enemy_bullet_x_sync;
reg [8:0]  enemy_bullet_x_video;
reg [7:0]  enemy_bullet_y_meta;
reg [7:0]  enemy_bullet_y_sync;
reg [7:0]  enemy_bullet_y_video;
reg        enemy_bullet_enable_meta;
reg        enemy_bullet_enable_sync;
reg        enemy_bullet_enable_video;
reg        sprite_prev_vs;

assign cpu_reset = !reset_n | !gen_clk_locked;

//=======================================================
//  Sub-module
//=======================================================
//=============== PLL reconfigure
pll_reconfig u_pll_reconfig (
	.mgmt_clk(clk_50),
	.mgmt_reset(!reset_n),
	.mgmt_readdata(mgmt_readdata),
	.mgmt_waitrequest(),
	.mgmt_read(mgmt_read),
	.mgmt_write(mgmt_write),
	.mgmt_address(mgmt_address),
	.mgmt_writedata(mgmt_writedata),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll) );

pll u_pll (
	.refclk(clk_50),           
	.rst(!reset_n),              
	.outclk_0(vpg_pclk), 
	.locked(gen_clk_locked),           
	.reconfig_to_pll(reconfig_to_pll),  
	.reconfig_from_pll(reconfig_from_pll) );

pll_controller u_pll_controller (
	.clk(clk_50),
	.reset_n(reset_n),
	.mode(mode),
	.mode_change(mode_change),
	.mgmt_readdata(mgmt_readdata),
	.mgmt_read(mgmt_read),
	.mgmt_write(mgmt_write),
	.mgmt_address(mgmt_address),
	.mgmt_writedata(mgmt_writedata) );

//=============== pattern generator according to vga timing
vga_generator u_vga_generator (                                    
	.clk(vpg_pclk),                
	.reset_n(gen_clk_locked),                                                
	.h_total(h_total),           
	.h_sync(h_sync),           
	.h_start(h_start),             
	.h_end(h_end),                                                    
	.v_total(v_total),           
	.v_sync(v_sync),            
	.v_start(v_start),           
	.v_end(v_end), 
	.v_active_14(v_active_14), 
	.v_active_24(v_active_24), 
	.v_active_34(v_active_34), 

.vga_hs(timing_hs),//変更場所
.vga_vs(timing_vs),
.vga_de(timing_de),
.vga_r(timing_r),
.vga_g(timing_g),
.vga_b(timing_b)
);

game_soc u_game_soc (
    .clk       (clk_50),
    .reset     (cpu_reset),
    .key_state_async (key_pressed),

    .writedata (cpu_writedata),
    .dataaddr  (cpu_dataaddr),
    .memwrite  (cpu_memwrite),

    .fb_we     (fb_we),
    .fb_waddr  (fb_waddr),
    .fb_wdata  (fb_wdata),

    .sprite0_x      (cpu_sprite0_x),
    .sprite0_y      (cpu_sprite0_y),
    .sprite0_enable (cpu_sprite0_enable),
    .sprite0_color  (cpu_sprite0_color),

    .sprite1_x      (cpu_sprite1_x),
    .sprite1_y      (cpu_sprite1_y),
    .sprite1_enable (cpu_sprite1_enable),

    .enemy_base_x   (cpu_enemy_base_x),
    .enemy_base_y   (cpu_enemy_base_y),
    .enemy_alive_lo (cpu_enemy_alive_lo),
    .enemy_alive_hi (cpu_enemy_alive_hi),
    .enemy_enable   (cpu_enemy_enable),
    .score_bcd      (cpu_score_bcd),

    .enemy_bullet_x      (cpu_enemy_bullet_x),
    .enemy_bullet_y      (cpu_enemy_bullet_y),
    .enemy_bullet_enable (cpu_enemy_bullet_enable),

    .perf_cycles      (perf_cycles),
    .perf_running     (perf_running),
    .perf_done_toggle (perf_done_toggle),
    .perf_under_60hz  (perf_under_60hz)
);

framebuffer_320x180 u_framebuffer_320x180 (
    .wclk  (clk_50),
    .we    (fb_we),
    .waddr (fb_waddr),
    .wdata (fb_wdata),

    .rclk  (vpg_pclk),
    .raddr (fb_raddr),
    .rdata (fb_rdata)
);

framebuffer_reader_6x u_framebuffer_reader_6x (
    .clk      (vpg_pclk),
    .reset_n  (gen_clk_locked),

    .in_de    (timing_de),
    .in_hs    (timing_hs),
    .in_vs    (timing_vs),

    .fb_raddr (fb_raddr),
    .fb_rdata (fb_rdata),

    .out_de   (reader_de),
    .out_hs   (reader_hs),
    .out_vs   (reader_vs),
    .out_rgb  (reader_rgb),
    .out_fb_x (reader_fb_x),
    .out_fb_y (reader_fb_y)
);

// Synchronize CPU-domain sprite registers, then apply them once per frame.
always @(posedge vpg_pclk or negedge gen_clk_locked) begin
    if (!gen_clk_locked) begin
        sprite0_x_meta       <= 9'd295;
        sprite0_x_sync       <= 9'd295;
        sprite0_x_video      <= 9'd295;
        sprite0_y_meta       <= 8'd82;
        sprite0_y_sync       <= 8'd82;
        sprite0_y_video      <= 8'd82;
        sprite0_enable_meta  <= 1'b0;
        sprite0_enable_sync  <= 1'b0;
        sprite0_enable_video <= 1'b0;
        sprite0_color_meta   <= 24'h00FF00;
        sprite0_color_sync   <= 24'h00FF00;
        sprite0_color_video  <= 24'h00FF00;
        sprite1_x_meta       <= 9'd0;
        sprite1_x_sync       <= 9'd0;
        sprite1_x_video      <= 9'd0;
        sprite1_y_meta       <= 8'd0;
        sprite1_y_sync       <= 8'd0;
        sprite1_y_video      <= 8'd0;
        sprite1_enable_meta  <= 1'b0;
        sprite1_enable_sync  <= 1'b0;
        sprite1_enable_video <= 1'b0;
        enemy_base_x_meta    <= 9'd20;
        enemy_base_x_sync    <= 9'd20;
        enemy_base_x_video   <= 9'd20;
        enemy_base_y_meta    <= 8'd18;
        enemy_base_y_sync    <= 8'd18;
        enemy_base_y_video   <= 8'd18;
        enemy_alive_lo_meta  <= 32'hFFFFFFFF;
        enemy_alive_lo_sync  <= 32'hFFFFFFFF;
        enemy_alive_lo_video <= 32'hFFFFFFFF;
        enemy_alive_hi_meta  <= 23'h7FFFFF;
        enemy_alive_hi_sync  <= 23'h7FFFFF;
        enemy_alive_hi_video <= 23'h7FFFFF;
        enemy_enable_meta    <= 1'b0;
        enemy_enable_sync    <= 1'b0;
        enemy_enable_video   <= 1'b0;
        score_bcd_meta       <= 8'h00;
        score_bcd_sync       <= 8'h00;
        score_bcd_video      <= 8'h00;
        enemy_bullet_x_meta       <= 9'd0;
        enemy_bullet_x_sync       <= 9'd0;
        enemy_bullet_x_video      <= 9'd0;
        enemy_bullet_y_meta       <= 8'd0;
        enemy_bullet_y_sync       <= 8'd0;
        enemy_bullet_y_video      <= 8'd0;
        enemy_bullet_enable_meta  <= 1'b0;
        enemy_bullet_enable_sync  <= 1'b0;
        enemy_bullet_enable_video <= 1'b0;
        sprite_prev_vs       <= 1'b1;
    end else begin
        sprite0_x_meta      <= cpu_sprite0_x;
        sprite0_x_sync      <= sprite0_x_meta;
        sprite0_y_meta      <= cpu_sprite0_y;
        sprite0_y_sync      <= sprite0_y_meta;
        sprite0_enable_meta <= cpu_sprite0_enable;
        sprite0_enable_sync <= sprite0_enable_meta;
        sprite0_color_meta  <= cpu_sprite0_color;
        sprite0_color_sync  <= sprite0_color_meta;
        sprite1_x_meta      <= cpu_sprite1_x;
        sprite1_x_sync      <= sprite1_x_meta;
        sprite1_y_meta      <= cpu_sprite1_y;
        sprite1_y_sync      <= sprite1_y_meta;
        sprite1_enable_meta <= cpu_sprite1_enable;
        sprite1_enable_sync <= sprite1_enable_meta;
        enemy_base_x_meta   <= cpu_enemy_base_x;
        enemy_base_x_sync   <= enemy_base_x_meta;
        enemy_base_y_meta   <= cpu_enemy_base_y;
        enemy_base_y_sync   <= enemy_base_y_meta;
        enemy_alive_lo_meta <= cpu_enemy_alive_lo;
        enemy_alive_lo_sync <= enemy_alive_lo_meta;
        enemy_alive_hi_meta <= cpu_enemy_alive_hi;
        enemy_alive_hi_sync <= enemy_alive_hi_meta;
        enemy_enable_meta   <= cpu_enemy_enable;
        enemy_enable_sync   <= enemy_enable_meta;
        score_bcd_meta      <= cpu_score_bcd;
        score_bcd_sync      <= score_bcd_meta;
        enemy_bullet_x_meta      <= cpu_enemy_bullet_x;
        enemy_bullet_x_sync      <= enemy_bullet_x_meta;
        enemy_bullet_y_meta      <= cpu_enemy_bullet_y;
        enemy_bullet_y_sync      <= enemy_bullet_y_meta;
        enemy_bullet_enable_meta <= cpu_enemy_bullet_enable;
        enemy_bullet_enable_sync <= enemy_bullet_enable_meta;
        sprite_prev_vs      <= timing_vs;

        if (sprite_prev_vs && !timing_vs) begin
            sprite0_x_video      <= sprite0_x_sync;
            sprite0_y_video      <= sprite0_y_sync;
            sprite0_enable_video <= sprite0_enable_sync;
            sprite0_color_video  <= sprite0_color_sync;
            sprite1_x_video      <= sprite1_x_sync;
            sprite1_y_video      <= sprite1_y_sync;
            sprite1_enable_video <= sprite1_enable_sync;
            enemy_base_x_video   <= enemy_base_x_sync;
            enemy_base_y_video   <= enemy_base_y_sync;
            enemy_alive_lo_video <= enemy_alive_lo_sync;
            enemy_alive_hi_video <= enemy_alive_hi_sync;
            enemy_enable_video   <= enemy_enable_sync;
            score_bcd_video      <= score_bcd_sync;
            enemy_bullet_x_video      <= enemy_bullet_x_sync;
            enemy_bullet_y_video      <= enemy_bullet_y_sync;
            enemy_bullet_enable_video <= enemy_bullet_enable_sync;
        end
    end
end

sprite_overlay_rect u_sprite_overlay_rect (
    .background_rgb (reader_rgb),
    .fb_x           (reader_fb_x),
    .fb_y           (reader_fb_y),
    .sprite_x       (sprite0_x_video),
    .sprite_y       (sprite0_y_video),
    .sprite_enable  (sprite0_enable_video),
    .sprite_color   (sprite0_color_video),
    .final_rgb      (after0_rgb)
);

sprite_overlay_enemy u_sprite_overlay_enemy (
    .background_rgb     (after0_rgb),
    .fb_x                (reader_fb_x),
    .fb_y                (reader_fb_y),
    .enemy_base_x        (enemy_base_x_video),
    .enemy_base_y        (enemy_base_y_video),
    .enemy_alive_lo      (enemy_alive_lo_video),
    .enemy_alive_hi      (enemy_alive_hi_video),
    .enemy_enable        (enemy_enable_video),
    .enemy_bullet_x      (enemy_bullet_x_video),
    .enemy_bullet_y      (enemy_bullet_y_video),
    .enemy_bullet_enable (enemy_bullet_enable_video),
    .final_rgb           (after_enemy_rgb)
);

sprite_overlay_bullet u_sprite_overlay_bullet (
    .background_rgb (after_enemy_rgb),
    .fb_x           (reader_fb_x),
    .fb_y           (reader_fb_y),
    .bullet_x       (sprite1_x_video),
    .bullet_y       (sprite1_y_video),
    .bullet_enable  (sprite1_enable_video),
    .final_rgb      (after_bullet_rgb)
);

sprite_overlay_score u_sprite_overlay_score (
    .background_rgb (after_bullet_rgb),
    .fb_x           (reader_fb_x),
    .fb_y           (reader_fb_y),
    .score_bcd      (score_bcd_video),
    .final_rgb      (final_rgb)
);

// Register the completed pixel so RGB and control signals remain stable
// for the full HDMI pixel-clock period.
always @(posedge vpg_pclk or negedge gen_clk_locked) begin
    if (!gen_clk_locked) begin
        output_de  <= 1'b0;
        output_hs  <= 1'b1;
        output_vs  <= 1'b1;
        output_rgb <= 24'h000000;
    end else begin
        output_de  <= reader_de;
        output_hs  <= reader_hs;
        output_vs  <= reader_vs;
        output_rgb <= final_rgb;
    end
end

assign vpg_de = output_de;
assign vpg_hs = output_hs;
assign vpg_vs = output_vs;
assign vpg_r  = output_rgb[23:16];
assign vpg_g  = output_rgb[15:8];
assign vpg_b  = output_rgb[7:0];
//=======================================================
//  Structural coding
//=======================================================
//============= assign timing constant  
//h_total : total - 1
//h_sync : sync - 1
//h_start : sync + back porch - 1 - 2(delay)
//h_end : h_start + active
//v_total : total - 1
//v_sync : sync - 1
//v_start : sync + back porch - 1
//v_end : v_start + active
//v_active_14 : v_start + 1/4 active
//v_active_24 : v_start + 2/4 active
//v_active_34 : v_start + 3/4 active
always @(mode)
begin
	case (mode)
		`VGA_640x480p60: begin //640x480@60 25.175 MHZ
			{h_total, h_sync, h_start, h_end} <= {12'd799, 12'd95, 12'd141, 12'd781}; 
			{v_total, v_sync, v_start, v_end} <= {12'd524, 12'd1, 12'd34, 12'd514}; 
			{v_active_14, v_active_24, v_active_34} <= {12'd154, 12'd274, 12'd394};
		end	
		`MODE_720x480: begin //720x480@60 27MHZ (VIC=3, 480P)
			{h_total, h_sync, h_start, h_end} <= {12'd857, 12'd61, 12'd119, 12'd839}; 
			{v_total, v_sync, v_start, v_end} <= {12'd524, 12'd5, 12'd35, 12'd515}; 
			{v_active_14, v_active_24, v_active_34} <= {12'd155, 12'd275, 12'd395};
		end
		`MODE_1024x768: begin //1024x768@60 65MHZ (XGA)
			{h_total, h_sync, h_start, h_end} <= {12'd1343, 12'd135, 12'd293, 12'd1317}; 
			{v_total, v_sync, v_start, v_end} <= {12'd805, 12'd5, 12'd34, 12'd802}; 
			{v_active_14, v_active_24, v_active_34} <= {12'd226, 12'd418, 12'd610};
		end
		`MODE_1280x1024: begin //1280x1024@60   108MHZ (SXGA)
			{h_total, h_sync, h_start, h_end} <= {12'd1687, 12'd111, 12'd357, 12'd1637}; 
			{v_total, v_sync, v_start, v_end} <= {12'd1065, 12'd2, 12'd40, 12'd1064}; 
			{v_active_14, v_active_24, v_active_34} <= {12'd296, 12'd552, 12'd808};
		end	
		`FHD_1920x1080p60: begin //1920x1080p60 148.5MHZ (1080i)
			{h_total, h_sync, h_start, h_end} <= {12'd2199, 12'd43, 12'd189, 12'd2109}; 
			{v_total, v_sync, v_start, v_end} <= {12'd1124, 12'd4, 12'd40, 12'd1120}; 
			{v_active_14, v_active_24, v_active_34} <= {12'd310, 12'd580, 12'd850};
		end		
		default: begin //1920x1080p60 148.5MHZ (1080i)
			{h_total, h_sync, h_start, h_end} <= {12'd2199, 12'd43, 12'd189, 12'd2109}; 
			{v_total, v_sync, v_start, v_end} <= {12'd1124, 12'd4, 12'd40, 12'd1120}; 
			{v_active_14, v_active_24, v_active_34} <= {12'd310, 12'd580, 12'd850};
		end
	endcase
end

endmodule
