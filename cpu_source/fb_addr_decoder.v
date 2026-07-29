`timescale 1ns / 1ps

module fb_addr_decoder (
    input  wire [31:0] dataaddr,
    input  wire [31:0] writedata,
    input  wire        memwrite,

    output wire        fb_we,
    output wire [15:0] fb_waddr,
    output wire [31:0] fb_wdata
);

    // 320 * 180 * 4 byte = 0x00038400 byte
    // 0x0000_0000 <= dataaddr < 0x0003_8400
    wire fb_sel;

    assign fb_sel = (dataaddr < 32'h0003_8400);

    // CPU address is byte address.
    // framebuffer address is pixel index.
    // 1 pixel = 4 byte, so divide by 4.
    assign fb_waddr = dataaddr[17:2];

    assign fb_wdata = writedata;
    assign fb_we    = memwrite && fb_sel && (dataaddr[1:0] == 2'b00);



    assign perf_sel = (dataaddr >= 32'h0008_0000) &&
                  (dataaddr <  32'h0008_0010);
    assign dmem_sel = (dataaddr >= 32'h0004_0000) && !perf_sel;
endmodule