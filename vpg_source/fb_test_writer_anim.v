`timescale 1ns / 1ps

module fb_test_writer_anim #(
    parameter WAIT_CYCLES = 32'd10_000_000
)(
    input  wire        clk,
    input  wire        reset_n,

    output reg         we,
    output reg [15:0]  waddr,
    output reg [31:0]  wdata,

    output reg         image_sel,
    output reg         frame_done
);

    localparam FB_WIDTH  = 320;
    localparam FB_HEIGHT = 180;
    localparam FB_LAST   = 16'd57599;

    localparam ST_WRITE = 1'b0;
    localparam ST_WAIT  = 1'b1;

    reg        state;
    reg [15:0] addr;
    reg [8:0]  x;          // 0..319
    reg [7:0]  y;          // 0..179
    reg [31:0] wait_count;

    // ------------------------------------------------------------
    // image_sel = 0:
    //   vertical color bars
    //
    // image_sel = 1:
    //   horizontal color bars
    //
    // pixel format:
    //   [31:24] unused
    //   [23:16] R
    //   [15:8]  G
    //   [7:0]   B
    // ------------------------------------------------------------
    function [31:0] pixel_color;
        input       sel;
        input [8:0] px;
        input [7:0] py;
        begin
            if (sel == 1'b0) begin
                // image 0: vertical bars
                if (px < 9'd80) begin
                    pixel_color = 32'h00FF0000; // red
                end else if (px < 9'd160) begin
                    pixel_color = 32'h0000FF00; // green
                end else if (px < 9'd240) begin
                    pixel_color = 32'h000000FF; // blue
                end else begin
                    pixel_color = 32'h00FFFFFF; // white
                end
            end else begin
                // image 1: horizontal bars
                if (py < 8'd45) begin
                    pixel_color = 32'h0000FFFF; // cyan
                end else if (py < 8'd90) begin
                    pixel_color = 32'h00FF00FF; // magenta
                end else if (py < 8'd135) begin
                    pixel_color = 32'h00FFFF00; // yellow
                end else begin
                    pixel_color = 32'h00000000; // black
                end
            end
        end
    endfunction

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state      <= ST_WRITE;
            addr       <= 16'd0;
            x          <= 9'd0;
            y          <= 8'd0;
            wait_count <= 32'd0;

            we         <= 1'b0;
            waddr      <= 16'd0;
            wdata      <= 32'd0;

            image_sel  <= 1'b0;
            frame_done <= 1'b0;
        end else begin
            frame_done <= 1'b0;

            case (state)
                ST_WRITE: begin
                    we    <= 1'b1;
                    waddr <= addr;
                    wdata <= pixel_color(image_sel, x, y);

                    if (addr == FB_LAST) begin
                        addr       <= 16'd0;
                        x          <= 9'd0;
                        y          <= 8'd0;
                        we         <= 1'b1;
                        frame_done <= 1'b1;
                        image_sel  <= ~image_sel;
                        wait_count <= 32'd0;
                        state      <= ST_WAIT;
                    end else begin
                        addr <= addr + 16'd1;

                        if (x == FB_WIDTH - 1) begin
                            x <= 9'd0;
                            y <= y + 8'd1;
                        end else begin
                            x <= x + 9'd1;
                        end
                    end
                end

                ST_WAIT: begin
                    we <= 1'b0;

                    if (wait_count == WAIT_CYCLES - 1) begin
                        wait_count <= 32'd0;
                        addr       <= 16'd0;
                        x          <= 9'd0;
                        y          <= 8'd0;
                        state      <= ST_WRITE;
                    end else begin
                        wait_count <= wait_count + 32'd1;
                    end
                end

                default: begin
                    state <= ST_WRITE;
                end
            endcase
        end
    end

endmodule