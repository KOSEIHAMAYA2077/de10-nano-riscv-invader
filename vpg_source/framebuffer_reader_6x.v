`timescale 1ns / 1ps

module framebuffer_reader_6x (
    input  wire        clk,
    input  wire        reset_n,

    input  wire        in_de,
    input  wire        in_hs,
    input  wire        in_vs,

    output wire [15:0] fb_raddr,
    input  wire [31:0] fb_rdata,

    output reg         out_de,
    output reg         out_hs,
    output reg         out_vs,
    output wire [23:0] out_rgb,
    output reg  [8:0]  out_fb_x,
    output reg  [7:0]  out_fb_y
);

    reg prev_de;
    reg prev_vs;

    reg [8:0] fb_x;   // 0..319
    reg [7:0] fb_y;   // 0..179

    reg [2:0] x_rep;  // 0..5
    reg [2:0] y_rep;  // 0..5

    // fb_y * 320 + fb_x
    // 320 = 256 + 64
    assign fb_raddr = ({8'd0, fb_y} << 8)
                    + ({8'd0, fb_y} << 6)
                    + {7'd0, fb_x};

    // framebuffer_320x180 は同期読み出しなので，
    // fb_rdata は raddr より1クロック遅れて出る．
    assign out_rgb = fb_rdata[23:0];

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            prev_de <= 1'b0;
            prev_vs <= 1'b1;

            fb_x <= 9'd0;
            fb_y <= 8'd0;

            x_rep <= 3'd0;
            y_rep <= 3'd0;

            out_de <= 1'b0;
            out_hs <= 1'b1;
            out_vs <= 1'b1;
            out_fb_x <= 9'd0;
            out_fb_y <= 8'd0;
        end else begin
            prev_de <= in_de;
            prev_vs <= in_vs;

            // framebufferの同期読み出しに合わせて1クロック遅延
            out_de <= in_de;
            out_hs <= in_hs;
            out_vs <= in_vs;
            out_fb_x <= fb_x;
            out_fb_y <= fb_y;

            // VSYNC falling edgeでframebuffer側のYを先頭に戻す
            // このdemoのVSYNCはsync期間でLowになる想定
            if (prev_vs && !in_vs) begin
                fb_y  <= 8'd0;
                y_rep <= 3'd0;
            end

            // active外では横方向を次行先頭に戻しておく
            if (!in_de) begin
                fb_x  <= 9'd0;
                x_rep <= 3'd0;
            end else begin
                // active中は横6pixelごとにfb_xを1進める
                if (x_rep == 3'd5) begin
                    x_rep <= 3'd0;

                    if (fb_x != 9'd319) begin
                        fb_x <= fb_x + 9'd1;
                    end
                end else begin
                    x_rep <= x_rep + 3'd1;
                end
            end

            // DE falling edgeでactive line終了
            // 6本のFHD lineごとにfb_yを1進める
            if (prev_de && !in_de) begin
                if (y_rep == 3'd5) begin
                    y_rep <= 3'd0;

                    if (fb_y != 8'd179) begin
                        fb_y <= fb_y + 8'd1;
                    end
                end else begin
                    y_rep <= y_rep + 3'd1;
                end
            end
        end
    end

endmodule
