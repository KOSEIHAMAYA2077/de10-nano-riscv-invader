`timescale 1ns / 1ps

module sprite_overlay_rect (
    input  wire [23:0] background_rgb,
    input  wire [8:0]  fb_x,
    input  wire [7:0]  fb_y,
    input  wire [8:0]  sprite_x,
    input  wire [7:0]  sprite_y,
    input  wire        sprite_enable,
    input  wire [23:0] sprite_color,
    output wire [23:0] final_rgb
);

    localparam [9:0] SPRITE_WIDTH  = 10'd20;
    localparam [8:0] SPRITE_HEIGHT = 9'd16;

    wire       sprite_bounds;
    wire [4:0] local_x;
    wire [3:0] local_y;

    reg [19:0] body_row;
    reg [19:0] cyan_row;

    wire body_pixel;
    wire cyan_pixel;
    wire sprite_pixel_on;
    wire [23:0] sprite_pixel_color;
    wire ground_pixel;

    assign sprite_bounds = sprite_enable
                         && (fb_x >= sprite_x)
                         && ({1'b0, fb_x} < ({1'b0, sprite_x} + SPRITE_WIDTH))
                         && (fb_y >= sprite_y)
                         && ({1'b0, fb_y} < ({1'b0, sprite_y} + SPRITE_HEIGHT));

    assign local_x = fb_x - sprite_x;
    assign local_y = fb_y - sprite_y;

    // Space-Invaders-style cannon. Monitor is portrait (90 CW).
    // local_x = 0..19: physical vertical (0 = top = toward enemies).
    // local_y = 0..15: physical horizontal (8 = center axis).
    // Shape: 16x12 visible cannon inside the existing 20x16 collision box.
    // Keeping the box unchanged avoids changes to movement limits, bullet
    // spawn position, and enemy-bullet collision code.
    always @* begin
        body_row = 20'h00000;
        cyan_row = 20'h00000;

        case (local_y)
            // Blank margin at y=0,1,14,15 narrows the cannon to 12px.
            // Outer edges: base x=10..15.
            4'd2:  body_row = 20'h0FC00;
            4'd13: body_row = 20'h0FC00;
            // x=8..15
            4'd3:  body_row = 20'h0FF00;
            4'd12: body_row = 20'h0FF00;
            // x=6..15
            4'd4:  body_row = 20'h0FFC0;
            4'd11: body_row = 20'h0FFC0;
            // x=4..15
            4'd5:  body_row = 20'h0FFF0;
            4'd10: body_row = 20'h0FFF0;
            // Center barrel zone: body x=2..15, cyan barrel tip x=0,1.
            4'd6:  begin body_row = 20'h0FFFC; cyan_row = 20'h00003; end
            4'd7:  begin body_row = 20'h0FFFC; cyan_row = 20'h00003; end
            4'd8:  begin body_row = 20'h0FFFC; cyan_row = 20'h00003; end
            4'd9:  begin body_row = 20'h0FFFC; cyan_row = 20'h00003; end
            default: ;
        endcase
    end

    assign body_pixel = body_row[local_x];
    assign cyan_pixel = cyan_row[local_x];

    assign sprite_pixel_on    = sprite_bounds && (body_pixel || cyan_pixel);
    assign sprite_pixel_color = cyan_pixel ? 24'h80FFFF : sprite_color;

    // Static defence line just below the cannon. It shares this overlay so
    // no CPU state, MMIO register, or extra video pipeline stage is needed.
    // The short margins keep the line clear of the screen edges.
    assign ground_pixel = (fb_x >= 9'd316)
                       && (fb_x <  9'd317)
                       && (fb_y >= 8'd4)
                       && (fb_y <  8'd176);

    assign final_rgb = sprite_pixel_on ? sprite_pixel_color :
                       ground_pixel    ? 24'h00FF66 :
                                         background_rgb;

endmodule
