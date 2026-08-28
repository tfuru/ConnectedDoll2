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
btn_side_height       = 20.0;       // 側面ボタン開口高さ
btn_side_radius       = 3.0;        // 側面ボタン角丸

btn_cap_depth         = 2.5;        // ボタンキャップ厚み（ズレ・傾き防止ガイド長）
btn_flange_t          = 1.2;        // 脱落防止フランジ厚み
btn_magnet_d          = 6.0;        // ネオジム磁石直径 (φ6.0mm)
btn_magnet_t          = 3.0;        // ネオジム磁石厚み (3.0mm)
btn_magnet_pitch_w    = 34.0;       // 左右磁石・ナット位置ピッチ (2個配置)
btn_magnet_pocket_d   = 6.1;        // ボタン側磁石埋め込みポケット径 (φ6.1mm)
btn_magnet_pocket_depth = 3.0;      // ボタン側磁石埋め込みポケット深さ (3.0mm)

// --- 前面化粧パネル（アクリル等）および M2 六角ナット仕様 ---
panel_nut_width       = 4.4;        // パネル側 M2 六角ナット二面幅 (対辺 4.0mm + 余裕0.4mm)
panel_nut_depth       = 1.6;        // パネル側 M2 六角ナット厚み / ポケット深さ (1.6mm)

// --- 前面ボタン バネ機構（弾性ストローク＆復帰スプリング） ---
btn_spring_arm_t        = 1.0;        // 左右復帰板バネアーム肉厚 (0.9〜1.0mm)
btn_spring_arm_l        = 9.5;        // 復帰板バネアーム展開長
btn_spring_reach        = 2.8;        // 復帰板バネ前方（ケース内壁当接）突き出し量
btn_flex_plunger_t      = 0.9;        // 弾性プランジャー板バネ肉厚
btn_target_stroke       = 1.2;        // 目標ストローク量 (1.2mm)
btn_plunger_w           = 3.5;        // プランジャー幅 (スリム形状)
btn_plunger_l           = 0.8;        // プランジャー裏面突出長 (0.8mm: 実基板内側スイッチ位置に対応)
btn_plunger_offset_y    = 1.4;        // スイッチアクチュエータ中心Yオフセット (+1.4mm)

// --- 前面アクリル化粧パネル埋め込み用リセス（段差ポケット） ---
front_recess_depth    = btn_magnet_t; // 3.0mm (アクリル厚みに完全一致)
front_recess_margin   = 0.6;          // リセスクリアランス (周囲0.6mm)
front_recess_w        = btn_side_width + front_recess_margin * 2;   // 45.2mm
front_recess_h        = btn_side_height + front_recess_margin * 2;  // 21.2mm
front_recess_r        = btn_side_radius + front_recess_margin;      // 3.6mm

// --- ボリューム調整スリット（右側面に配置） ---
vol_slit_width  = 16.0;       // ダイヤル操作スリット幅
vol_slit_height = 4.5;        // スリット高さ
vol_slit_radius = 1.5;        // スリット角丸
vol_offset_y    = -5.0;       // Y軸方向オフセット（前方向へ5mm移動）

// --- 電池ボックス (単4×3本 スイッチ付き) ---
batt_length    = 63.0;        // 横幅
batt_width     = 37.0;        // 縦幅
batt_height    = 17.0;        // 厚み
batt_clearance = 0.6;         // 電池ボックス収容クリアランス
batt_pos_y     = 3.0;         // 電池ボックス中心Yオフセット（奥側M2支柱および手前スピーカーとの干渉回避位置）
spk_pos_y      = -23.5;       // スピーカー中心Yオフセット

// --- ケース寸法計算 ---
case_inner_w   = pcb_width + clearance * 2 + 4.0; // 内部余裕 (約 64.8mm)
case_inner_h   = pcb_height + clearance * 2 + 4.0; // 内部余裕 (約 64.8mm)

top_cover_h    = 8.0;         // トップカバー高さ（薄型フタ・天板）
bottom_case_h  = 28.0;        // ボトムケース高さ（20mmスペーサー + 基板 + スイッチ開口を収容、28mm）

case_outer_w   = case_inner_w + wall_thickness * 2; // 外幅 (約 68.8mm)
case_outer_h   = case_inner_h + wall_thickness * 2; // 外高 (約 68.8mm)

// --- M2 六角オスメスネジスペーサー仕様 ---
spacer_body_h      = 20.0;           // スペーサー本体（六角部）長さ = 20.0mm
spacer_male_h      = 6.0;            // 先端おねじ部長さ = 6.0mm
spacer_hex_w       = 4.4;            // ボトム側回り止め六角ポケット二面幅 (対辺 4.0mm + 余裕0.4mm)
spacer_pocket_d    = 1.0;            // 回り止め六角ポケット深さ
spacer_pad_h       = 1.2;            // ボトム底面のスペーサー受け座パッド高さ
pcb_standoff_h     = spacer_body_h;  // 基板受け面高さ = 20.0mm

// ボタンおよびアクリルパネルの統一中心高さ (PCB表面・タクトスイッチ中心高さ: Z = 23.0mm)
btn_center_z       = wall_thickness + pcb_standoff_h + 1.0;

// --- 統合締結ボス・ネジ穴寸法 ---
joint_pitch        = pcb_hole_pitch; // 52.0mm
joint_boss_outer   = 6.0;            // トップ側ボス外径
joint_screw_pass   = 2.2;            // M2 ネジ通過穴径（ボトム底面）
joint_screw_tap    = 1.8;            // M2 おねじ受けタッピング穴径（トップ側）
joint_screw_head_d = 4.4;            // M2 ネジ頭沈め径
joint_screw_head_h = 1.8;            // ネジ頭沈め深さ
rib_thickness      = 1.2;            // 補強リブ厚み

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
