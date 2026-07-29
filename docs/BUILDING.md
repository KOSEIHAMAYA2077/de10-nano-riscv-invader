# Quartusでの再構築

## 必要な環境

- Terasic DE10-Nano
- Quartus Prime Lite 25.1std
- Python 3

## 手順

1. リポジトリのルートでゲームプログラムを生成します。

```console
python tools/assemble_rv32i.py memfile.s
```

2. Quartusで `DE10_Nano_HDMI_TX.qpf` を開きます。
3. `DE10_Nano_HDMI_TX` をAnalysis & Synthesisします。
4. エラーがないことを確認後、Fitter／Assemblerを実行します。
5. 生成されたSOFをDE10-Nanoへ書き込みます。

## 映像合成順

```text
framebuffer
  -> sprite_overlay_rect
  -> sprite_overlay_enemy
  -> sprite_overlay_bullet
  -> sprite_overlay_score
  -> HDMI output register
```

## メモリマップ

```text
0x0000_0000 - 0x0003_83FF : framebuffer
0x0004_0000 -             : data memory
0x0008_0000 - 0x0008_000F : performance counter
0x0008_0010                : KEY state
0x0008_0020 - 0x0008_003B : player / player bullet
0x0008_0040 - 0x0008_0054 : enemy grid / score
0x0008_0058 - 0x0008_0060 : enemy bullet
```

詳しいレジスタ一覧は
[MMIO一覧画像](images/mmio-map.png)を参照してください。

## 第三者由来ファイル

Terasic公式デモおよびAltera／Intel FPGA生成IP由来ファイルは、
ファイル内の著作権表示・利用条件を保持した状態で収録しています。
