/*
 * Small RV32I core written specifically for this project.
 *
 * This is an original implementation derived from the public RISC-V
 * instruction-set specification.  It does not reuse the former textbook
 * implementation.
 *
 * The core is single-cycle and uses a simple word-wide memory interface.
 * Word loads/stores are supported; byte and halfword stores are intentionally
 * omitted because the surrounding system has no byte-enable signals.
 */
`timescale 1ns / 1ps

module riscv(
    input         clk,
    input         reset,
    output [31:0] pc,
    input  [31:0] instr,
    output reg    memwrite,
    output reg [31:0] aluout,
    output [31:0] writedata,
    input  [31:0] readdata
);

    localparam [6:0] OP_LOAD   = 7'b0000011;
    localparam [6:0] OP_IMM    = 7'b0010011;
    localparam [6:0] OP_AUIPC  = 7'b0010111;
    localparam [6:0] OP_STORE  = 7'b0100011;
    localparam [6:0] OP_REG    = 7'b0110011;
    localparam [6:0] OP_LUI    = 7'b0110111;
    localparam [6:0] OP_BRANCH = 7'b1100011;
    localparam [6:0] OP_JALR   = 7'b1100111;
    localparam [6:0] OP_JAL    = 7'b1101111;

    reg [31:0] program_counter;
    reg [31:0] registers [0:31];

    reg [31:0] next_pc;
    reg        register_write;
    reg [4:0]  register_destination;
    reg [31:0] register_write_data;

    wire [6:0] opcode = instr[6:0];
    wire [4:0] rs1    = instr[19:15];
    wire [4:0] rs2    = instr[24:20];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    wire [31:0] rs1_value = (rs1 == 5'd0) ? 32'd0 : registers[rs1];
    wire [31:0] rs2_value = (rs2 == 5'd0) ? 32'd0 : registers[rs2];

    wire [31:0] immediate_i =
        {{20{instr[31]}}, instr[31:20]};
    wire [31:0] immediate_s =
        {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] immediate_b =
        {{19{instr[31]}}, instr[31], instr[7],
         instr[30:25], instr[11:8], 1'b0};
    wire [31:0] immediate_u =
        {instr[31:12], 12'b0};
    wire [31:0] immediate_j =
        {{11{instr[31]}}, instr[31], instr[19:12],
         instr[20], instr[30:21], 1'b0};

    assign pc        = program_counter;
    assign writedata = rs2_value;

    /*
     * Decode and execute in one combinational stage.  Unknown or unsupported
     * encodings behave as a NOP, which keeps accidental memory writes off.
     */
    always @(*) begin
        next_pc                  = program_counter + 32'd4;
        memwrite                 = 1'b0;
        aluout                   = 32'd0;
        register_write           = 1'b0;
        register_destination     = rd;
        register_write_data      = 32'd0;

        case (opcode)
            OP_LUI: begin
                register_write      = 1'b1;
                register_write_data = immediate_u;
            end

            OP_AUIPC: begin
                register_write      = 1'b1;
                register_write_data = program_counter + immediate_u;
            end

            OP_JAL: begin
                register_write      = 1'b1;
                register_write_data = program_counter + 32'd4;
                next_pc             = program_counter + immediate_j;
            end

            OP_JALR: begin
                if (funct3 == 3'b000) begin
                    register_write      = 1'b1;
                    register_write_data = program_counter + 32'd4;
                    next_pc             = (rs1_value + immediate_i) &
                                          32'hffff_fffe;
                end
            end

            OP_BRANCH: begin
                case (funct3)
                    3'b000: if (rs1_value == rs2_value)
                                next_pc = program_counter + immediate_b; // BEQ
                    3'b001: if (rs1_value != rs2_value)
                                next_pc = program_counter + immediate_b; // BNE
                    3'b100: if ($signed(rs1_value) < $signed(rs2_value))
                                next_pc = program_counter + immediate_b; // BLT
                    3'b101: if ($signed(rs1_value) >= $signed(rs2_value))
                                next_pc = program_counter + immediate_b; // BGE
                    3'b110: if (rs1_value < rs2_value)
                                next_pc = program_counter + immediate_b; // BLTU
                    3'b111: if (rs1_value >= rs2_value)
                                next_pc = program_counter + immediate_b; // BGEU
                    default: ;
                endcase
            end

            OP_LOAD: begin
                aluout = rs1_value + immediate_i;
                if (funct3 == 3'b010) begin
                    register_write      = 1'b1; // LW
                    register_write_data = readdata;
                end
            end

            OP_STORE: begin
                aluout = rs1_value + immediate_s;
                if (funct3 == 3'b010)
                    memwrite = 1'b1; // SW
            end

            OP_IMM: begin
                register_write = 1'b1;
                case (funct3)
                    3'b000: register_write_data =
                                rs1_value + immediate_i; // ADDI
                    3'b010: register_write_data =
                                ($signed(rs1_value) < $signed(immediate_i));
                    3'b011: register_write_data =
                                (rs1_value < immediate_i);
                    3'b100: register_write_data =
                                rs1_value ^ immediate_i;
                    3'b110: register_write_data =
                                rs1_value | immediate_i;
                    3'b111: register_write_data =
                                rs1_value & immediate_i;
                    3'b001: begin
                        if (funct7 == 7'b0000000)
                            register_write_data =
                                rs1_value << instr[24:20]; // SLLI
                        else
                            register_write = 1'b0;
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000)
                            register_write_data =
                                rs1_value >> instr[24:20]; // SRLI
                        else if (funct7 == 7'b0100000)
                            register_write_data =
                                $signed(rs1_value) >>> instr[24:20]; // SRAI
                        else
                            register_write = 1'b0;
                    end
                    default: register_write = 1'b0;
                endcase
            end

            OP_REG: begin
                register_write = 1'b1;
                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000)
                            register_write_data = rs1_value + rs2_value;
                        else if (funct7 == 7'b0100000)
                            register_write_data = rs1_value - rs2_value;
                        else
                            register_write = 1'b0;
                    end
                    3'b001: begin
                        if (funct7 == 7'b0000000)
                            register_write_data =
                                rs1_value << rs2_value[4:0];
                        else
                            register_write = 1'b0;
                    end
                    3'b010: begin
                        if (funct7 == 7'b0000000)
                            register_write_data =
                                ($signed(rs1_value) < $signed(rs2_value));
                        else
                            register_write = 1'b0;
                    end
                    3'b011: begin
                        if (funct7 == 7'b0000000)
                            register_write_data =
                                (rs1_value < rs2_value);
                        else
                            register_write = 1'b0;
                    end
                    3'b100: begin
                        if (funct7 == 7'b0000000)
                            register_write_data =
                                rs1_value ^ rs2_value;
                        else
                            register_write = 1'b0;
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000)
                            register_write_data =
                                rs1_value >> rs2_value[4:0];
                        else if (funct7 == 7'b0100000)
                            register_write_data =
                                $signed(rs1_value) >>> rs2_value[4:0];
                        else
                            register_write = 1'b0;
                    end
                    3'b110: begin
                        if (funct7 == 7'b0000000)
                            register_write_data =
                                rs1_value | rs2_value;
                        else
                            register_write = 1'b0;
                    end
                    3'b111: begin
                        if (funct7 == 7'b0000000)
                            register_write_data =
                                rs1_value & rs2_value;
                        else
                            register_write = 1'b0;
                    end
                    default: register_write = 1'b0;
                endcase
            end

            default: ;
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            program_counter <= 32'd0;
        end else begin
            program_counter <= next_pc;
            if (register_write && (register_destination != 5'd0))
                registers[register_destination] <= register_write_data;
            registers[0] <= 32'd0;
        end
    end

endmodule
