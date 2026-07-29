`timescale 1ns / 1ps

module sprite_overlay_score (
    input  wire [23:0] background_rgb,
    input  wire [8:0]  fb_x,
    input  wire [7:0]  fb_y,
    input  wire [7:0]  score_bcd,
    output wire [23:0] final_rgb
);

    // Portrait physical top-right:
    // logical X is the physical vertical axis, logical Y is the physical horizontal axis.
    localparam [8:0] SCORE_X = 9'd4;
    localparam [7:0] SCORE_Y = 8'd164;

    localparam [8:0] SCORE_H = 9'd10; // 5 font rows x 2 scale
    localparam [8:0] SCORE_W = 9'd14; // 2 digits: 6 + 2 gap + 6

    wire in_score_box = ({1'b0, fb_x} >= {1'b0, SCORE_X})
                      && ({1'b0, fb_x} <  ({1'b0, SCORE_X} + SCORE_H))
                      && ({1'b0, fb_y} >= {1'b0, SCORE_Y})
                      && ({1'b0, fb_y} <  ({1'b0, SCORE_Y} + SCORE_W));

    wire [8:0] local_x = fb_x - SCORE_X;

    // fb_y (logical Y) increases toward the physical LEFT, not the physical
    // right (confirmed by the KEY0/KEY1 movement convention: Y++ = physical
    // left). Mirror it here so the tens digit lands on the physical left,
    // the ones digit on the physical right, and each glyph itself is not
    // drawn backwards.
    wire [7:0] local_y_raw = fb_y - SCORE_Y;
    wire [7:0] local_y     = (SCORE_W[7:0] - 8'd1) - local_y_raw;

    wire tens_region = in_score_box && (local_y < 8'd6);
    wire ones_region = in_score_box && (local_y >= 8'd8) && (local_y < 8'd14);

    wire [2:0] font_row = local_x[3:1]; // scale 2
    wire [2:0] font_col_tens = local_y[2:1];
    wire [7:0] local_y_ones = local_y - 8'd8;
    wire [2:0] font_col_ones = local_y_ones[2:1];

    wire [3:0] score_tens = score_bcd[7:4];
    wire [3:0] score_ones = score_bcd[3:0];

    function [2:0] digit_row;
        input [3:0] digit;
        input [2:0] row;
        begin
            case (digit)
                4'd0: begin
                    case (row)
                        3'd0: digit_row = 3'b111;
                        3'd1: digit_row = 3'b101;
                        3'd2: digit_row = 3'b101;
                        3'd3: digit_row = 3'b101;
                        default: digit_row = 3'b111;
                    endcase
                end
                4'd1: begin
                    case (row)
                        3'd0: digit_row = 3'b010;
                        3'd1: digit_row = 3'b110;
                        3'd2: digit_row = 3'b010;
                        3'd3: digit_row = 3'b010;
                        default: digit_row = 3'b111;
                    endcase
                end
                4'd2: begin
                    case (row)
                        3'd0: digit_row = 3'b111;
                        3'd1: digit_row = 3'b001;
                        3'd2: digit_row = 3'b111;
                        3'd3: digit_row = 3'b100;
                        default: digit_row = 3'b111;
                    endcase
                end
                4'd3: begin
                    case (row)
                        3'd0: digit_row = 3'b111;
                        3'd1: digit_row = 3'b001;
                        3'd2: digit_row = 3'b111;
                        3'd3: digit_row = 3'b001;
                        default: digit_row = 3'b111;
                    endcase
                end
                4'd4: begin
                    case (row)
                        3'd0: digit_row = 3'b101;
                        3'd1: digit_row = 3'b101;
                        3'd2: digit_row = 3'b111;
                        3'd3: digit_row = 3'b001;
                        default: digit_row = 3'b001;
                    endcase
                end
                4'd5: begin
                    case (row)
                        3'd0: digit_row = 3'b111;
                        3'd1: digit_row = 3'b100;
                        3'd2: digit_row = 3'b111;
                        3'd3: digit_row = 3'b001;
                        default: digit_row = 3'b111;
                    endcase
                end
                4'd6: begin
                    case (row)
                        3'd0: digit_row = 3'b111;
                        3'd1: digit_row = 3'b100;
                        3'd2: digit_row = 3'b111;
                        3'd3: digit_row = 3'b101;
                        default: digit_row = 3'b111;
                    endcase
                end
                4'd7: begin
                    case (row)
                        3'd0: digit_row = 3'b111;
                        3'd1: digit_row = 3'b001;
                        3'd2: digit_row = 3'b010;
                        3'd3: digit_row = 3'b010;
                        default: digit_row = 3'b010;
                    endcase
                end
                4'd8: begin
                    case (row)
                        3'd0: digit_row = 3'b111;
                        3'd1: digit_row = 3'b101;
                        3'd2: digit_row = 3'b111;
                        3'd3: digit_row = 3'b101;
                        default: digit_row = 3'b111;
                    endcase
                end
                4'd9: begin
                    case (row)
                        3'd0: digit_row = 3'b111;
                        3'd1: digit_row = 3'b101;
                        3'd2: digit_row = 3'b111;
                        3'd3: digit_row = 3'b001;
                        default: digit_row = 3'b111;
                    endcase
                end
                default: digit_row = 3'b000;
            endcase
        end
    endfunction

    wire [2:0] tens_row_bits = digit_row(score_tens, font_row);
    wire [2:0] ones_row_bits = digit_row(score_ones, font_row);

    wire tens_pixel = tens_region
                    && (score_tens != 4'd0)
                    && (((tens_row_bits >> (3'd2 - font_col_tens)) & 3'b001) != 3'b000);

    wire ones_pixel = ones_region
                    && (((ones_row_bits >> (3'd2 - font_col_ones)) & 3'b001) != 3'b000);

    assign final_rgb = (tens_pixel || ones_pixel) ? 24'hFFFFFF : background_rgb;

endmodule
