#!/bin/bash
set -e

# スクリプトのディレクトリへ移動
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ディレクトリ設定
SCAD_DIR="scad"
OUTPUT_STL_DIR="stl"
OUTPUT_IMG_DIR="image/dist"
OUTPUT_CUT_DIR="acrylic"

mkdir -p "$OUTPUT_STL_DIR"
mkdir -p "$OUTPUT_IMG_DIR"
mkdir -p "$OUTPUT_CUT_DIR"

# OpenSCAD 実行可能コマンドの検出
if command -v openscad >/dev/null 2>&1; then
    OPENSCAD_BIN="openscad"
elif [ -f "/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD" ]; then
    OPENSCAD_BIN="/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD"
else
    echo "Error: OpenSCAD is not installed or not found in PATH." >&2
    exit 1
fi

echo "Using OpenSCAD: $OPENSCAD_BIN"
echo "SCAD Source Directory: $SCAD_DIR"
echo "STL Output Directory: $OUTPUT_STL_DIR"
echo "Image Output Directory: $OUTPUT_IMG_DIR"
echo "Acrylic Cut Output Directory: $OUTPUT_CUT_DIR"

# 1. トップカバーの出力
if [ -f "$SCAD_DIR/top_cover.scad" ]; then
    echo "Rendering top_cover.stl and preview..."
    "$OPENSCAD_BIN" -o "$OUTPUT_STL_DIR/top_cover.stl" "$SCAD_DIR/top_cover.scad"
    "$OPENSCAD_BIN" -o "$OUTPUT_IMG_DIR/top_cover_preview.png" --camera=0,0,0,55,0,25,200 --imgsize=800,600 --autocenter --viewall "$SCAD_DIR/top_cover.scad"
    echo "✓ top_cover (STL & PNG) generated."
fi

# 2. 前面ボタンの出力
if [ -f "$SCAD_DIR/front_button.scad" ]; then
    echo "Rendering front_button.stl and preview..."
    "$OPENSCAD_BIN" -o "$OUTPUT_STL_DIR/front_button.stl" "$SCAD_DIR/front_button.scad"
    "$OPENSCAD_BIN" -o "$OUTPUT_IMG_DIR/front_button_preview.png" --camera=0,0,0,55,0,25,80 --imgsize=800,600 --autocenter --viewall "$SCAD_DIR/front_button.scad"
    echo "✓ front_button (STL & PNG) generated."
fi

# 3. ボトムケースの出力
if [ -f "$SCAD_DIR/bottom_case.scad" ]; then
    echo "Rendering bottom_case.stl and preview..."
    "$OPENSCAD_BIN" -o "$OUTPUT_STL_DIR/bottom_case.stl" "$SCAD_DIR/bottom_case.scad"
    "$OPENSCAD_BIN" -o "$OUTPUT_IMG_DIR/bottom_case_preview.png" --camera=20,0,0,65,0,70,220 --imgsize=800,600 --autocenter --viewall "$SCAD_DIR/bottom_case.scad"
    echo "✓ bottom_case (STL & PNG) generated."
fi

# 4. アクリル化粧パネルの出力 (STL, 2D DXF, 2D SVG)
if [ -f "$SCAD_DIR/acrylic_panel.scad" ]; then
    echo "Rendering acrylic_panel (STL, DXF, SVG, PNG)..."
    "$OPENSCAD_BIN" -o "$OUTPUT_STL_DIR/acrylic_panel.stl" "$SCAD_DIR/acrylic_panel.scad"
    "$OPENSCAD_BIN" -D 'mode="2d"' -o "$OUTPUT_CUT_DIR/acrylic_panel.dxf" "$SCAD_DIR/acrylic_panel.scad"
    "$OPENSCAD_BIN" -D 'mode="2d"' -o "$OUTPUT_CUT_DIR/acrylic_panel.svg" "$SCAD_DIR/acrylic_panel.scad"
    "$OPENSCAD_BIN" -o "$OUTPUT_IMG_DIR/acrylic_panel_preview.png" --camera=0,0,0,55,0,25,80 --imgsize=800,600 --autocenter --viewall "$SCAD_DIR/acrylic_panel.scad"
    echo "✓ acrylic_panel (STL, DXF, SVG, PNG) generated."
fi

# 5. 一括3Dプリントプレートの出力 (All-in-One: Top, Bottom, Button)
if [ -f "$SCAD_DIR/print_plate.scad" ]; then
    echo "Rendering print_plate_all.stl and preview..."
    "$OPENSCAD_BIN" -o "$OUTPUT_STL_DIR/print_plate_all.stl" "$SCAD_DIR/print_plate.scad"
    "$OPENSCAD_BIN" -o "$OUTPUT_IMG_DIR/print_plate_preview.png" --camera=0,-30,20,70,0,320,180 --imgsize=1000,750 --autocenter --viewall "$SCAD_DIR/print_plate.scad"
    echo "✓ print_plate_all (STL & PNG) generated."
fi

# 6. 全体アセンブリプレビュー画像の出力
if [ -f "$SCAD_DIR/main_assembly.scad" ]; then
    echo "Rendering assembly preview images..."
    # 分解図
    "$OPENSCAD_BIN" -o "$OUTPUT_IMG_DIR/assembly_exploded.png" --camera=0,-50,0,60,0,325,280 --imgsize=1000,750 --autocenter --viewall "$SCAD_DIR/main_assembly.scad"
    # 組立図
    "$OPENSCAD_BIN" -D "explode_z=0;explode_btn=0;explode_screw=0" -o "$OUTPUT_IMG_DIR/assembly_closed.png" --camera=20,0,0,65,0,70,220 --imgsize=1000,750 --autocenter --viewall "$SCAD_DIR/main_assembly.scad"
    # 内部断面図 (Cutaway)
    if [ -f "$SCAD_DIR/cutaway_assembly.scad" ]; then
        "$OPENSCAD_BIN" -o "$OUTPUT_IMG_DIR/assembly_cutaway.png" --camera=10,-10,20,65,0,50,200 --imgsize=1000,750 --autocenter --viewall "$SCAD_DIR/cutaway_assembly.scad"
    fi
    echo "✓ main_assembly previews generated."
fi

echo "All STL, 2D Vector (DXF/SVG), and PNG generation complete!"
