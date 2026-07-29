`timescale 1ns / 1ps

module framebuffer_320x180 (
    input  wire        wclk,
    input  wire        we,
    input  wire [15:0] waddr,
    input  wire [31:0] wdata,

    input  wire        rclk,
    input  wire [15:0] raddr,
    output reg  [31:0] rdata
);

    localparam FB_SIZE = 57600;

    reg [31:0] mem [0:FB_SIZE-1];

    // write port
    always @(posedge wclk) begin
        if (we) begin
            mem[waddr] <= wdata;
        end
    end

    // read port
    // M10K推論のため同期読み出しにする
    always @(posedge rclk) begin
        rdata <= mem[raddr];
    end

endmodule