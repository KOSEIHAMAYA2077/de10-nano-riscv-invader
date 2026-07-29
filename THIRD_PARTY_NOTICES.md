# Third-party notices

## Terasic DE10-Nano HDMI reference design

この制作のローカルQuartusプロジェクトには、Terasic Technologiesの
DE10-Nano HDMIリファレンスデザイン由来ファイルが含まれています。

公式デモ由来部分については、授業での確認に基づいて成果物へ含めています。
各ファイル冒頭に記載されたTerasicの著作権表示、利用条件、免責事項は
変更せず保持しています。

主な該当ファイルは次のとおりです。

- `DE10_Nano_HDMI_TX.*`
- `AUDIO_IF.v`
- `I2C_*.v`
- `vpg_source/vpg.v`
- `vpg_source/vga_generator.v`

## Altera / Intel FPGA generated IP

PLL等のMegaWizard／Quartus生成ファイルにはAlteraまたはIntel FPGAの
条件が適用されます。生成ファイル内の著作権表示と利用条件を保持して
います。

## Course-provided materials

授業配布のTiny RISC-V CPU実装および `tas.py` は公開対象に含めて
いません。CPUは `cpu_source/riscv.v`、アセンブラは
`tools/assemble_rv32i.py` の新規実装へ置き換えています。

## Presentation references

成果発表資料内で参照した画像・動画・技術資料については、スライド上の
出典URL表示を保持しています。PowerPoint／PDFの再利用時には、各出典の
利用条件を別途確認してください。
