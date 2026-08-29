// ==========================================
// ConnectedDoll2 Print Plate (print_plate.scad)
// 超コンパクト垂直スタック 3Dプリントレイアウト
// （全パーツをボトムケース外寸内に集約・ニッパー切り離し薄首サポート付き）
// ==========================================

include <params.scad>;
use <bottom_case.scad>;
use <top_cover.scad>;
use <front_button.scad>;
use <battery_lid.scad>;
use <rotary_lock.scad>;

// スタック印刷パラメータ
gap_bottom_to_mid = 2.5;  // ボトムケース天端から中間パーツ下面までの隙間 (2.5mm)
gap_mid_to_top    = 5.5;  // 中間パーツからトップカバー開口端までの隙間 (5.5mm: ボス突き出し3.0mmを余裕で逃げる)
pillar_d          = 2.8;  // 主サポートピラー中間部直径
neck_d            = 1.3;  // ニッパー切り離し薄首くびれ部直径 (1.3mm: ニッパーで簡単に切断可能)
neck_h            = 0.4;  // 薄首くびれ高さ (0.4mm: 刃先が入りやすく切断面が綺麗)
include_button    = false; // 前面ボタンの一括プレート含有フラグ (デフォルトfalse)

// 四隅の外周壁リム中心座標の計算
corner_rim_r   = corner_radius - wall_thickness / 2; // コーナー壁芯半径 (3.0mm)
rim_offset_x   = case_outer_w / 2 - corner_radius + corner_rim_r * cos(45); // 約 32.52mm
rim_offset_y   = case_outer_h / 2 - corner_radius + corner_rim_r * sin(45); // 約 32.52mm

// 1. 上下両端くびれ部付き 薄首サポートピラー (ニッパー切断対応)
module breakaway_pillar(h, d=2.4) {
    union() {
        // 下部くびれ部 (ニッパー切断ゲート)
        cylinder(h=neck_h, d=neck_d, $fn=16);
        
        // テーパー下部
        translate([0, 0, neck_h])
            cylinder(h=0.5, d1=neck_d, d2=d, $fn=20);
        
        // 中間剛性円柱
        translate([0, 0, neck_h + 0.5])
            cylinder(h=max(0.1, h - (neck_h + 0.5) * 2), d=d, $fn=20);
        
        // テーパー上部
        translate([0, 0, h - neck_h - 0.5])
            cylinder(h=0.5, d1=d, d2=neck_d, $fn=20);
        
        // 上部くびれ部 (ニッパー切断ゲート)
        translate([0, 0, h - neck_h])
            cylinder(h=neck_h, d=neck_d, $fn=16);
    }
}

// 2. 水平ランナー梁 (パーツ間水平接続・薄首ゲート付き)
module horizontal_runner(length, width=1.8, thick=1.0) {
    union() {
        // 始点くびれゲート
        cylinder(h=thick, d=neck_d, $fn=16);
        // ランナー本体梁
        translate([-width/2, 0, 0])
            cube([width, length, thick]);
        // 終点くびれゲート
        translate([0, length, 0])
            cylinder(h=thick, d=neck_d, $fn=16);
    }
}

module print_plate() {
    center_x = case_outer_w / 2;
    center_y = case_outer_h / 2;

    // 垂直スタック高さ設定
    mid_stack_z  = bottom_case_h + gap_bottom_to_mid; // Z = 28.0 + 2.5 = 30.5mm
    lid_y        = -8.0;                              // 電池フタ中心Y
    lock_y       = 28.0;                              // 回転ロックダイヤル中心Y (奥端 Y=34.5mm が奥壁天端 Y=33.4mm と2.0mm重なる)
    top_stack_z  = mid_stack_z + 2.4 + gap_mid_to_top; // Z = 30.5 + 2.4 + 5.5 = 38.4mm
    top_total_h  = top_stack_z + top_cover_h;        // 全高 Z = 46.4mm

    // ==========================================
    // 1. ボトムケース (最下層: Z=0〜28.0mm, 中心原点配置, 底面接地)
    // ==========================================
    translate([-center_x, -center_y, 0])
        bottom_case();

    // ==========================================
    // 2. 電池フタ (中間層手前側: Z=30.5mm, 外面下向き)
    // ボトム天端リムの枠内(幅65.9mm < 68.8mm)に完全収容
    // ==========================================
    translate([0, lid_y, mid_stack_z])
        battery_lid();

    // 2b. 電池フタ支持ピラー (ボトム側壁天端 Z=28.0mm からフタ左右下面 Z=30.5mm へ接続: 計6本)
    // ボトム左右側壁の真上 (X=±32.4mm) に垂直配置
    for (px = [-32.4, 32.4]) {
        for (dy = [-14.0, 0, 14.0]) {
            translate([px, lid_y + dy, bottom_case_h])
                breakaway_pillar(h=gap_bottom_to_mid, d=2.0);
        }
    }

    // ==========================================
    // 3. 回転ロックダイヤル (中間層奥側: メイン円盤下面 Z=31.3mm, リブ最下面 Z=30.5mm)
    // ==========================================
    lock_dial_z = mid_stack_z + rotary_rib_h; // Z = 30.5 + 0.8 = 31.3mm (メイン円盤下面)
    translate([0, lock_y, lock_dial_z])
        rotary_lock(0);

    // 3b. 回転ロック支持ピラー (ボトム奥壁天端 Y=32.8mm, Z=28.0mm からダイヤル下面 Z=31.3mm へ確実に命中結合: 2本)
    // 中心からの距離: sqrt(2.4^2 + 4.8^2) = 5.37mm < 半径6.5mm (円盤下面の内側へ1.1mm安全マージン)
    lock_pillar_h = lock_dial_z - bottom_case_h + 0.1; // 3.4mm (0.1mmめり込み密着接合)
    for (px = [-2.4, 2.4]) {
        translate([px, 32.8, bottom_case_h])
            breakaway_pillar(h=lock_pillar_h, d=1.8);
    }

    // 3c. パーツ間水平ランナー (フタ奥側の凹みを避けた左右2本並列梁: X = ±5.0mm)
    // フタ奥端面からダイヤル円盤手前外周へ確実に直結
    runner_start_y = lid_y + batt_lid_d / 2; // 11.95mm
    rx_offset = 5.0; // 凹み(半径4.7mm)の外側
    dial_edge_y = lock_y - sqrt(pow(rotary_dial_d / 2, 2) - pow(rx_offset, 2)); // X=±5.0mmでのダイヤル手前円弧Y座標 ≈ 23.85mm
    runner_len = dial_edge_y - runner_start_y + 0.3; // 約 12.2mm (ダイヤルへ0.3mmめり込み完全結合)

    for (rx = [-rx_offset, rx_offset]) {
        translate([rx, runner_start_y, mid_stack_z + 0.4])
            horizontal_runner(length=runner_len, width=1.8, thick=1.0);
    }

    // ==========================================
    // 4. 四隅 主サポートピラー (ボトム天端 Z=28.0mm からトップカバー底面 Z=38.4mm へ直結: 4本)
    // ==========================================
    main_pillar_h = top_stack_z - bottom_case_h; // 38.4 - 28.0 = 10.4mm
    for (dx = [-rim_offset_x, rim_offset_x]) {
        for (dy = [-rim_offset_y, rim_offset_y]) {
            translate([dx, dy, bottom_case_h])
                breakaway_pillar(h=main_pillar_h, d=pillar_d);
        }
    }

    // ==========================================
    // 5. トップカバー (最上層: Z=38.4〜46.4mm, 下向きスタック配置)
    // ==========================================
    translate([center_x, -center_y, top_total_h])
        rotate([0, 180, 0])
            top_cover();

    // ==========================================
    // 6. 前面ボタン (オプション: include_button=true時のみ手前側に配置)
    // ==========================================
    if (include_button) {
        translate([0, -center_y - 14.0, btn_m2_boss_h])
            front_button();
    }
}

// 描画
print_plate();
