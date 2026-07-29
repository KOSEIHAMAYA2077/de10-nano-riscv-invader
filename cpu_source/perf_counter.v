`timescale 1ns / 1ps

module perf_counter (
    input  wire        clk,
    input  wire        reset,

    input  wire        perf_we,
    input  wire [3:0]  perf_addr,
    input  wire [31:0] perf_wdata,
    output reg  [31:0] perf_rdata,

    output reg  [31:0] perf_cycles,
    output reg         perf_running,
    output reg         perf_done_toggle,
    output wire        perf_under_60hz
);

    localparam LIMIT_60HZ = 32'd833333;

    reg [31:0] counter;

    assign perf_under_60hz = (perf_cycles < LIMIT_60HZ);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter          <= 32'd0;
            perf_cycles      <= 32'd0;
            perf_running     <= 1'b0;
            perf_done_toggle <= 1'b0;
        end else begin
            if (perf_running) begin
                counter <= counter + 32'd1;
            end

            if (perf_we) begin
                case (perf_addr[3:2])
                    2'b00: begin
                        // 0x0008_0000 : START
                        counter      <= 32'd0;
                        perf_running <= 1'b1;
                    end

                    2'b01: begin
                        // 0x0008_0004 : STOP
                        perf_cycles      <= counter;
                        perf_running     <= 1'b0;
                        perf_done_toggle <= ~perf_done_toggle;
                    end

                    default: begin
                    end
                endcase
            end
        end
    end

    always @(*) begin
        case (perf_addr[3:2])
            2'b10: perf_rdata = perf_cycles;                           // RESULT
            2'b11: perf_rdata = {30'd0, perf_running, perf_under_60hz}; // STATUS
            default: perf_rdata = 32'd0;
        endcase
    end

endmodule
