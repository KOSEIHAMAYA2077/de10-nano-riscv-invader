#!/usr/bin/env python3
"""Assemble the small RV32I subset used by memfile.s.

This project-specific assembler is written from the public RISC-V ISA
encoding tables.  It intentionally supports only the instructions used by the
game firmware and emits one 32-bit hexadecimal word per line.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path


R_OPS = {
    "add": (0x00, 0x0),
    "sub": (0x20, 0x0),
    "sll": (0x00, 0x1),
    "slt": (0x00, 0x2),
    "sltu": (0x00, 0x3),
    "xor": (0x00, 0x4),
    "srl": (0x00, 0x5),
    "sra": (0x20, 0x5),
    "or": (0x00, 0x6),
    "and": (0x00, 0x7),
}

I_OPS = {
    "addi": 0x0,
    "slti": 0x2,
    "sltiu": 0x3,
    "xori": 0x4,
    "ori": 0x6,
    "andi": 0x7,
}

BRANCH_OPS = {
    "beq": 0x0,
    "bne": 0x1,
    "blt": 0x4,
    "bge": 0x5,
    "bltu": 0x6,
    "bgeu": 0x7,
}


def register(token: str) -> int:
    match = re.fullmatch(r"x(\d+)", token.strip(), re.IGNORECASE)
    if not match or not 0 <= int(match.group(1)) <= 31:
        raise ValueError(f"invalid register: {token}")
    return int(match.group(1))


def number(token: str) -> int:
    return int(token.strip(), 0)


def signed_field(value: int, width: int, description: str) -> int:
    minimum = -(1 << (width - 1))
    maximum = (1 << (width - 1)) - 1
    if not minimum <= value <= maximum:
        raise ValueError(
            f"{description} {value} does not fit signed {width}-bit field"
        )
    return value & ((1 << width) - 1)


def split_operands(text: str) -> list[str]:
    return [item.strip() for item in text.split(",") if item.strip()]


def encode_r(mnemonic: str, operands: list[str]) -> int:
    if len(operands) != 3:
        raise ValueError(f"{mnemonic} expects rd, rs1, rs2")
    rd, rs1, rs2 = map(register, operands)
    funct7, funct3 = R_OPS[mnemonic]
    return (
        (funct7 << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (rd << 7)
        | 0x33
    )


def encode_i(mnemonic: str, operands: list[str]) -> int:
    if len(operands) != 3:
        raise ValueError(f"{mnemonic} expects rd, rs1, immediate")
    rd = register(operands[0])
    rs1 = register(operands[1])
    immediate = signed_field(number(operands[2]), 12, f"{mnemonic} immediate")
    return (
        (immediate << 20)
        | (rs1 << 15)
        | (I_OPS[mnemonic] << 12)
        | (rd << 7)
        | 0x13
    )


def encode_shift(mnemonic: str, operands: list[str]) -> int:
    if len(operands) != 3:
        raise ValueError(f"{mnemonic} expects rd, rs1, shift amount")
    rd = register(operands[0])
    rs1 = register(operands[1])
    shamt = number(operands[2])
    if not 0 <= shamt <= 31:
        raise ValueError(f"shift amount out of range: {shamt}")
    funct3 = 0x1 if mnemonic == "slli" else 0x5
    funct7 = 0x20 if mnemonic == "srai" else 0x00
    return (
        (funct7 << 25)
        | (shamt << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (rd << 7)
        | 0x13
    )


def encode_memory(
    mnemonic: str, operands: list[str], store: bool
) -> int:
    if len(operands) != 2:
        raise ValueError(f"{mnemonic} expects register, offset(base)")
    match = re.fullmatch(r"(.+)\((x\d+)\)", operands[1].replace(" ", ""))
    if not match:
        raise ValueError(f"invalid memory operand: {operands[1]}")
    data_reg = register(operands[0])
    immediate = signed_field(number(match.group(1)), 12, f"{mnemonic} offset")
    base_reg = register(match.group(2))
    if store:
        return (
            ((immediate >> 5) << 25)
            | (data_reg << 20)
            | (base_reg << 15)
            | (0x2 << 12)
            | ((immediate & 0x1F) << 7)
            | 0x23
        )
    return (
        (immediate << 20)
        | (base_reg << 15)
        | (0x2 << 12)
        | (data_reg << 7)
        | 0x03
    )


def encode_branch(
    mnemonic: str, operands: list[str], pc: int, labels: dict[str, int]
) -> int:
    if len(operands) != 3:
        raise ValueError(f"{mnemonic} expects rs1, rs2, label")
    rs1 = register(operands[0])
    rs2 = register(operands[1])
    if operands[2] not in labels:
        raise ValueError(f"unknown label: {operands[2]}")
    offset = labels[operands[2]] - pc
    if offset & 1:
        raise ValueError(f"unaligned branch target: {operands[2]}")
    immediate = signed_field(offset, 13, f"{mnemonic} offset")
    return (
        (((immediate >> 12) & 1) << 31)
        | (((immediate >> 5) & 0x3F) << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (BRANCH_OPS[mnemonic] << 12)
        | (((immediate >> 1) & 0xF) << 8)
        | (((immediate >> 11) & 1) << 7)
        | 0x63
    )


def encode_jal(
    operands: list[str], pc: int, labels: dict[str, int], pseudo: bool
) -> int:
    if pseudo:
        if len(operands) != 1:
            raise ValueError("j expects one label")
        rd = 0
        label = operands[0]
    else:
        if len(operands) != 2:
            raise ValueError("jal expects rd, label")
        rd = register(operands[0])
        label = operands[1]
    if label not in labels:
        raise ValueError(f"unknown label: {label}")
    offset = labels[label] - pc
    if offset & 1:
        raise ValueError(f"unaligned jump target: {label}")
    immediate = signed_field(offset, 21, "jump offset")
    return (
        (((immediate >> 20) & 1) << 31)
        | (((immediate >> 1) & 0x3FF) << 21)
        | (((immediate >> 11) & 1) << 20)
        | (((immediate >> 12) & 0xFF) << 12)
        | (rd << 7)
        | 0x6F
    )


def read_program(path: Path) -> tuple[list[tuple[int, str]], dict[str, int]]:
    statements: list[tuple[int, str]] = []
    labels: dict[str, int] = {}
    pc = 0
    for line_number, raw_line in enumerate(
        path.read_text(encoding="utf-8-sig").splitlines(), start=1
    ):
        line = raw_line.split(";", 1)[0].split("#", 1)[0].strip()
        if not line:
            continue
        if line.endswith(":"):
            label = line[:-1].strip()
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", label):
                raise ValueError(f"line {line_number}: invalid label {label}")
            if label in labels:
                raise ValueError(f"line {line_number}: duplicate label {label}")
            labels[label] = pc
            continue
        statements.append((line_number, line))
        pc += 4
    return statements, labels


def assemble(source: Path) -> list[int]:
    statements, labels = read_program(source)
    words: list[int] = []
    for index, (line_number, statement) in enumerate(statements):
        parts = statement.split(None, 1)
        mnemonic = parts[0].lower()
        operands = split_operands(parts[1] if len(parts) == 2 else "")
        pc = index * 4
        try:
            if mnemonic in R_OPS:
                word = encode_r(mnemonic, operands)
            elif mnemonic in I_OPS:
                word = encode_i(mnemonic, operands)
            elif mnemonic in {"slli", "srli", "srai"}:
                word = encode_shift(mnemonic, operands)
            elif mnemonic == "lw":
                word = encode_memory(mnemonic, operands, store=False)
            elif mnemonic == "sw":
                word = encode_memory(mnemonic, operands, store=True)
            elif mnemonic in BRANCH_OPS:
                word = encode_branch(mnemonic, operands, pc, labels)
            elif mnemonic == "lui":
                if len(operands) != 2:
                    raise ValueError("lui expects rd, immediate")
                immediate = number(operands[1])
                if not 0 <= immediate <= 0xFFFFF:
                    raise ValueError("lui immediate must fit 20 bits")
                word = (immediate << 12) | (register(operands[0]) << 7) | 0x37
            elif mnemonic == "jal":
                word = encode_jal(operands, pc, labels, pseudo=False)
            elif mnemonic == "j":
                word = encode_jal(operands, pc, labels, pseudo=True)
            else:
                raise ValueError(f"unsupported instruction: {mnemonic}")
        except ValueError as error:
            raise ValueError(f"line {line_number}: {error}") from error
        words.append(word)
    return words


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument(
        "-o", "--output", type=Path, help="default: source path with .dat suffix"
    )
    args = parser.parse_args()
    output = args.output or args.source.with_suffix(".dat")
    words = assemble(args.source)
    output.write_text(
        "".join(f"{word:08x}\n" for word in words), encoding="ascii"
    )
    print(f"Wrote {len(words)} words to {output}")


if __name__ == "__main__":
    main()
