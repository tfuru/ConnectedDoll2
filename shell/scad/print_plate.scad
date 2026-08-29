// ==========================================
// ConnectedDoll2 Print Plate (print_plate.scad)
// Stacked 3D Print Layout with Breakaway Support Pillars
// ==========================================

include <params.scad>;
use <bottom_case.scad>;
use <top_cover.scad>;
use <front_button.scad>;
use <battery_lid.scad>;
use <rotary_lock.scad>;

// スタック印刷パラメータ
stack_gap_z    = 3.0; // ボトムとトップの間の隙間 (3.0mm)
pillar_d       = 2.8; // サポートピラー中間部直径
neck_d         = 1.4; // 切り離し薄首くびれ部直径 (手で簡単に折れる寸法)
neck_h         = 0.4; // 薄首くびれ高さ
include_button = false; // 前面ボタンの一括プレート含有フラグ (デフォルトfalse: 前面ボタンを取り除いたデータを出力)

// 四隅の外周壁リム中心座標の計算
corner_rim_r   = corner_radius - wall_thickness / 2; // コーナー壁芯半径 (3.0mm)
rim_offset_x   = case_outer_w / 2 - corner_radius + corner_rim_r * cos(45); // 約 32.52mm
rim_offset_y   = case_outer_h / 2 - corner_radius + corner_rim_r * sin(45); // 約 32.52mm

// 薄首ブレークアウェイ・サポートピラー
module breakaway_support_pillar(h=3.0) {
    union() {
        // 下部くびれ（ボトムケース天面リムとの接点）
        cylinder(h=neck_h, d=neck_d, $fn=16);
        
        // テーパー下部
        translate([0, 0, neck_h])
            cylinder(h=0.5, d1=neck_d, d2=pillar_d, $fn=24);
        
        // 中間剛性円柱
        translate([0, 0, neck_h + 0.5])
            cylinder(h=h - (neck_h + 0.5) * 2, d=pillar_d, $fn=24);
        
        // テーパー上部
        translate([0, 0, h - neck_h - 0.5])
            cylinder(h=0.5, d1=pillar_d, d2=neck_d, $fn=24);
        
        // 上部くびれ（トップカバー底面リムとの接点）
        translate([0, 0, h - neck_h])
            cylinder(h=neck_h, d=neck_d, $fn=16);
    }
}

module print_plate() {
    center_x = case_outer_w / 2;
    center_y = case_outer_h / 2;

    // 1. ボトムケース (Z=0〜28.0mm: 中心原点配置、底面接地)
    translate([-center_x, -center_y, 0])
        bottom_case();

    // 2. 切り離しサポートピラー (4隅の外周リム直上に配置: Z=28.0〜31.0mm)
    for (dx = [-rim_offset_x, rim_offset_x]) {
        for (dy = [-rim_offset_y, rim_offset_y]) {
            translate([dx, dy, bottom_case_h])
                breakaway_support_pillar(h=stack_gap_z);
        }
    }

    // 3. トップカバー (完成形と同軸・同向きで真上にスタック配置: Z=31.0〜39.0mm)
    translate([center_x, -center_y, bottom_case_h + stack_gap_z + top_cover_h])
        rotate([0, 180, 0])
            top_cover();

    // 4. 前面ボタン (オプション: デフォルト除外、別色印刷や単体印刷対応)
    if (include_button) {
        translate([0, -center_y - 14.0, btn_m2_boss_h])
            front_button();
    }

    // 5. 電池フタ (ボトムケース奥側のベッド上に配置: 外面接地 Z=0)
    translate([0, center_y + batt_lid_d / 2 + 6.0, 0])
        battery_lid();

    // 6. 回転ロックダイヤル (フタ脇のベッド上に配置: 天面接地 Z=0)
    translate([batt_lid_w / 2 + 10.0, center_y + batt_lid_d / 2 + 6.0, rotary_dial_t])
        rotate([180, 0, 0])
            rotary_lock(0);
}

// 描画
print_plate();
