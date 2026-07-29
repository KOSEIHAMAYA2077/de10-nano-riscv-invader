const fs = require("fs");
const path = require("path");

const WIDTH = 1400;
const HEIGHT = 1050;

const halfRows = [
  [
    ["001", "011", "111", "110", "111", "010", "101", "010"],
    ["001", "011", "111", "110", "111", "010", "010", "101"],
  ],
  [
    ["010", "101", "111", "110", "111", "011", "010", "101"],
    ["010", "101", "111", "110", "111", "011", "101", "010"],
  ],
  [
    ["011", "111", "110", "111", "011", "101", "100", "010"],
    ["011", "111", "110", "111", "011", "101", "010", "101"],
  ],
];

const types = [
  { name: "上段　squid型", rows: "1行", color: "#f59e0b" },
  { name: "中段　crab型", rows: "2行", color: "#10b981" },
  { name: "下段　octopus型", rows: "2行", color: "#8b5cf6" },
];

function esc(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function text(x, y, value, size = 28, weight = 400, color = "#17202a", anchor = "start") {
  return `<text x="${x}" y="${y}" font-family="Noto Sans JP, Yu Gothic, sans-serif" font-size="${size}" font-weight="${weight}" fill="${color}" text-anchor="${anchor}">${esc(value)}</text>`;
}

function roundedRect(x, y, width, height, fill, stroke = "#cbd5e1", radius = 18, strokeWidth = 2) {
  return `<rect x="${x}" y="${y}" width="${width}" height="${height}" rx="${radius}" fill="${fill}" stroke="${stroke}" stroke-width="${strokeWidth}"/>`;
}

function mirrorRow(half) {
  return half + [...half].reverse().join("");
}

function expandedRow(half) {
  return [...mirrorRow(half)].map((bit) => bit + bit).join("");
}

function drawBitmap(rows, x, y, cell, color, doubleWidth = false, compareRows = null) {
  const cols = doubleWidth ? 12 : rows[0].length;
  const renderedRows = doubleWidth ? rows.map(expandedRow) : rows;
  const compareRendered = compareRows
    ? (doubleWidth ? compareRows.map(expandedRow) : compareRows)
    : null;

  let out = `<g shape-rendering="crispEdges">`;
  for (let row = 0; row < renderedRows.length; row += 1) {
    for (let col = 0; col < cols; col += 1) {
      const on = renderedRows[row][col] === "1";
      const changed = compareRendered && renderedRows[row][col] !== compareRendered[row][col];
      out += `<rect x="${x + col * cell}" y="${y + row * cell}" width="${cell}" height="${cell}" fill="${on ? color : "#f8fafc"}" stroke="#d7dee7" stroke-width="1"/>`;
      if (on && changed) {
        out += `<rect x="${x + col * cell + 1.5}" y="${y + row * cell + 1.5}" width="${cell - 3}" height="${cell - 3}" fill="none" stroke="#ffffff" stroke-width="2.5"/>`;
      }
    }
  }
  out += `</g>`;
  return out;
}

const svg = [];
svg.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${WIDTH}" height="${HEIGHT}" viewBox="0 0 ${WIDTH} ${HEIGHT}">`);
svg.push(`<rect width="${WIDTH}" height="${HEIGHT}" fill="#ffffff"/>`);

svg.push(text(42, 54, "敵スプライトの構成", 34, 700, "#0f766e"));
svg.push(roundedRect(38, 78, 1324, 282, "#f8fafc", "#b8c5d1", 18, 2));
svg.push(text(68, 118, "左右対称を利用した鏡面生成", 25, 700, "#17202a"));

const sampleHalf = halfRows[1][0];
svg.push(text(145, 154, "保存する左半分", 20, 700, "#475569", "middle"));
svg.push(drawBitmap(sampleHalf, 112, 170, 21, "#10b981", false));
svg.push(text(145, 354, "3列 × 8行", 18, 600, "#475569", "middle"));

svg.push(`<path d="M210 251 H330" stroke="#64748b" stroke-width="4" marker-end="url(#arrow)"/>`);
svg.push(text(270, 234, "左右反転", 18, 600, "#475569", "middle"));

const sampleFull = sampleHalf.map(mirrorRow);
svg.push(text(435, 154, "表示時の6bit形状", 20, 700, "#475569", "middle"));
svg.push(drawBitmap(sampleFull, 372, 170, 21, "#10b981", false));
svg.push(`<line x1="435" y1="166" x2="435" y2="342" stroke="#ef4444" stroke-width="3" stroke-dasharray="8 6"/>`);
svg.push(text(435, 354, "中央線で鏡面展開", 18, 600, "#475569", "middle"));

svg.push(text(650, 166, "1行の例", 20, 700, "#0f766e"));
svg.push(text(650, 206, "保存：011", 28, 700, "#17202a"));
svg.push(text(650, 250, "表示：011｜110", 28, 700, "#17202a"));
svg.push(text(650, 302, "3種類 × 2コマ × 8行", 21, 600, "#475569"));
svg.push(text(650, 338, "288bit → 144bit（50％削減）", 23, 700, "#0f766e"));

svg.push(text(42, 408, "実際に使用した3種類 × 2コマ", 30, 700, "#0f766e"));
svg.push(text(1320, 408, "白枠：コマ間で変化する画素", 17, 600, "#64748b", "end"));

for (let typeIndex = 0; typeIndex < types.length; typeIndex += 1) {
  const top = 430 + typeIndex * 190;
  const type = types[typeIndex];
  const frameA = halfRows[typeIndex][0];
  const frameB = halfRows[typeIndex][1];

  svg.push(roundedRect(38, top, 902, 170, "#ffffff", "#d5dde5", 16, 2));
  svg.push(text(68, top + 48, type.name, 23, 700, type.color));
  svg.push(text(68, top + 83, `配置：${type.rows}`, 18, 600, "#64748b"));

  svg.push(text(390, top + 35, "コマA", 18, 700, "#475569", "middle"));
  svg.push(drawBitmap(frameA, 306, top + 45, 14, type.color, true, frameB));

  svg.push(text(558, top + 105, "↔", 34, 700, "#64748b", "middle"));

  svg.push(text(726, top + 35, "コマB", 18, 700, "#475569", "middle"));
  svg.push(drawBitmap(frameB, 642, top + 45, 14, type.color, true, frameA));
}

svg.push(roundedRect(970, 430, 392, 550, "#ecfeff", "#67b7c3", 18, 2));
svg.push(text(1166, 480, "歩行アニメーション", 24, 700, "#0e7490", "middle"));
svg.push(text(1166, 540, "敵全体の座標", 22, 600, "#17202a", "middle"));
svg.push(text(1166, 580, "enemy_base_y[0]", 25, 700, "#17202a", "middle"));
svg.push(text(1166, 628, "↓", 34, 700, "#0e7490", "middle"));
svg.push(text(1166, 674, "0 / 1 をコマ番号に使用", 20, 600, "#17202a", "middle"));
svg.push(text(1166, 724, "↓", 34, 700, "#0e7490", "middle"));
svg.push(text(1166, 770, "敵が1px移動するたび", 20, 600, "#17202a", "middle"));
svg.push(text(1166, 810, "55体を一斉に切替", 23, 700, "#0e7490", "middle"));
svg.push(`<line x1="1015" y1="850" x2="1317" y2="850" stroke="#9ccbd2" stroke-width="2"/>`);
svg.push(text(1166, 895, "形状データは共通", 20, 600, "#475569", "middle"));
svg.push(text(1166, 932, "表示色は列ごとに付与", 20, 600, "#475569", "middle"));

svg.push(`<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="#64748b"/></marker></defs>`);
svg.push(`</svg>`);

const outputPath = path.resolve(__dirname, "..", "敵スプライト説明図.svg");
fs.writeFileSync(outputPath, svg.join("\n"), "utf8");
console.log(outputPath);
