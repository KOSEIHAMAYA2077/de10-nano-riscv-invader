`timescale 1ns / 1ps

module sprite_overlay_bullet (
    input  wire [23:0] background_rgb,
    input  wire [8:0]  fb_x,
    input  wire [7:0]  fb_y,
    input  wire [8:0]  bullet_x,
    input  wire [7:0]  bullet_y,
    input  wire        bullet_enable,
    output wire [23:0] final_rgb
);

    localparam [9:0] BULLET_WIDTH  = 10'd8;
    localparam [8:0] BULLET_HEIGHT = 9'd2;

    wire bullet_bounds;

    assign bullet_bounds = bullet_enable
                         && (fb_x >= bullet_x)
                         && ({1'b0, fb_x} < ({1'b0, bullet_x} + BULLET_WIDTH))
                         && (fb_y >= bullet_y)
                         && ({1'b0, fb_y} < ({1'b0, bullet_y} + BULLET_HEIGHT));

    assign final_rgb = bullet_bounds ? 24'hFFFFFF : background_rgb;

endmodule
