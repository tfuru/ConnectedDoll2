// ==========================================
// ConnectedDoll2 Shell Parameters (params.scad)
// ==========================================

$fn = 40; // 円・フィレットの分割精度

// --- 基本ケース外形 ---
wall_thickness = 2.0;         // ケース肉厚
corner_radius  = 4.0;         // 外装の角丸半径
clearance      = 0.4;         // 嵌合・可動クリアランス

// --- メイン基板 (PCB) ---
pcb_width      = 60.0;
pcb_height     = 60.0;
pcb_thickness  = 1.6;
pcb_hole_pitch = 52.0;        // 取付穴ピッチ (四隅 52x52mm)
pcb_hole_dia   = 2.0;         // M2 穴

// --- スピーカー (TR-WS-2014B) ---
spk_width      = 20.0;
spk_height     = 14.0;
spk_thickness  = 4.5;
spk_hole_pitch = 24.7;        // フランジ取付穴ピッチ
spk_hole_dia   = 1.8;         // M1.8 穴
spk_boss_dia   = 4.2;
spk_boss_inner = 1.4;         // M1.8 タッピング穴径
spk_boss_h     = 4.0;

// --- 前面ボタン（ボトムケース手前側面に配置） ---
btn_side_width        = 44.0;       // 側面ボタン開口幅
btn_side_height       = 14.0;       // 側面ボタン開口高さ
btn_side_radius       = 3.0;        // 側面ボタン角丸

btn_cap_depth         = 2.5;        // ボタンキャップ厚み（ズレ・傾き防止ガイド長）
btn_flange_t          = 1.2;        // 脱落防止フランジ厚み
btn_magnet_d          = 6.0;        // ネオジム磁石直径 (0.6cm)
btn_magnet_t          = 3.0;        // ネオジム磁石厚み (0.3cm)
btn_magnet_pitch_w    = 34.0;       // 左右ナット・磁石位置ピッチ (2個配置)
btn_nut_width         = 4.4;        // M2 六角ナット二面幅 (対辺)
btn_nut_depth         = 1.6;        // M2 六角ナット接着ポケット深さ

// --- 前面アクリル化粧パネル埋め込み用リセス（段差ポケット） ---
front_recess_depth    = btn_magnet_t; // 3.0mm (アクリル厚みに完全一致)
front_recess_margin   = 0.6;          // リセスクリアランス (周囲0.6mm)
front_recess_w        = btn_side_width + front_recess_margin * 2;   // 45.2mm
front_recess_h        = btn_side_height + front_recess_margin * 2;  // 15.2mm
front_recess_r        = btn_side_radius + front_recess_margin;      // 3.6mm

// --- ボリューム調整スリット（右側面に配置） ---
vol_slit_width  = 16.0;       // ダイヤル操作スリット幅
vol_slit_height = 4.5;        // スリット高さ
vol_slit_radius = 1.5;        // スリット角丸
vol_offset_y    = 0.0;        // Y軸方向オフセット（中央）

// --- 電池ボックス ---
batt_length    = 62.7;
batt_width     = 37.3;
batt_height    = 16.0;

// --- ケース寸法計算 ---
case_inner_w   = pcb_width + clearance * 2 + 4.0; // 内部余裕 (約 64.8mm)
case_inner_h   = pcb_height + clearance * 2 + 4.0; // 内部余裕 (約 64.8mm)

top_cover_h    = 8.0;         // トップカバー高さ（薄型フタ・天板）
bottom_case_h  = 26.0;        // ボトムケース高さ（電池ボックス 16mm + 基板 + スイッチ開口を収容）

case_outer_w   = case_inner_w + wall_thickness * 2; // 外幅 (約 68.8mm)
case_outer_h   = case_inner_h + wall_thickness * 2; // 外高 (約 68.8mm)

// --- 統合締結ボス (基板 52x52mm ピッチに完全統合) ---
joint_pitch        = pcb_hole_pitch; // 52.0mm
joint_boss_outer   = 5.5;            // ボス外径
joint_screw_pass   = 2.2;            // M2 ネジ通過穴径（ボトム側）
joint_screw_tap    = 1.8;            // M2 タッピング穴径（トップ側）
joint_screw_head_d = 4.2;            // M2 ネジ頭沈め径
joint_screw_head_h = 1.8;            // ネジ頭沈め深さ
pcb_standoff_h     = 18.0;           // ボトム底面から基板受け面までの支柱高さ

// --- 共通ユーティリティモジュール ---
module rounded_cube(size, r) {
    x = size[0];
    y = size[1];
    z = size[2];
    hull() {
        translate([r, r, 0]) cylinder(h=z, r=r);
        translate([x - r, r, 0]) cylinder(h=z, r=r);
        translate([x - r, y - r, 0]) cylinder(h=z, r=r);
        translate([r, y - r, 0]) cylinder(h=z, r=r);
    }
}
