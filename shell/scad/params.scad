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
spk_body_w     = 20.0;        // 本体幅 (20.0mm)
spk_body_h     = 13.9;        // 本体奥行き (13.9mm)
spk_thickness  = 4.5;         // 本体厚み (4.5mm)
spk_ear_w      = 28.5;        // フランジ含む全幅 (28.5mm)
spk_ear_to_front = 1.65;      // 出音口端面から取付穴中心までの距離 (1.65mm)
spk_hole_pitch = 24.7;        // フランジ取付穴ピッチ (24.7mm)
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
btn_flange_w          = btn_side_width + 3.0;   // 47.0mm (左右抜け止めツバ幅: 片側+1.5mm)
btn_flange_h          = btn_side_height + 1.0;  // 21.0mm (上下抜け止めツバ高: 片側+0.5mm, 天板天井クリアランス+0.5mm)
btn_magnet_d          = 6.0;        // ネオジム磁石直径 (φ6.0mm)
btn_magnet_t          = 3.0;        // ネオジム磁石厚み (3.0mm)
btn_magnet_pitch_w    = 34.0;       // 左右磁石・ナット位置ピッチ (2個配置)
btn_magnet_pocket_d   = 6.1;        // ボタン側磁石埋め込みポケット径 (φ6.1mm)
btn_magnet_pocket_depth = 3.0;      // ボタン側磁石埋め込みポケット深さ (3.0mm)

// --- 前面化粧パネル（アクリル等）および M2 六角ナット仕様 ---
panel_nut_width       = 4.4;        // パネル側 M2 六角ナット二面幅 (対辺 4.0mm + 余裕0.4mm)
panel_nut_depth       = 1.6;        // パネル側 M2 六角ナット厚み / ポケット深さ (1.6mm)

// --- 前面ボタン 左右押しバネ（マイクロコイルスプリング）＆M2アジャスタブル・プランジャー ---
btn_spring_d            = 3.0;        // 押しバネ外径 (φ3.0mm)
btn_spring_pocket_d     = 3.4;        // バネ収容ポケット穴径 (φ3.4mm: 余裕+0.4mm)
btn_spring_pocket_depth = 2.0;        // ボタン側バネポケット深さ (2.0mm)
btn_spring_pitch_w      = 34.0;       // 左右押しバネ配置ピッチ (34.0mm: 左右均等対称)
btn_spring_offset_y     = -5.5;       // 押しバネYオフセット (磁石ポケットとの干渉回避: 下側 -5.5mm)
btn_spring_free_l       = 7.0;        // 押しバネ自由長目安 (6.0〜8.0mm)
btn_case_boss_pocket_d  = 2.5;        // ボトムケース側受けボス深さ (2.5mm)
btn_case_boss_outer_d   = 5.4;        // ボトムケース側受けボス外径 (φ5.4mm)
btn_case_boss_y         = 9.5;        // ボトムケース側受けボス中心Y座標 (9.5mm)
btn_target_stroke       = 0.4;        // スイッチ作動ストローク目安 (約0.3〜0.5mm)
btn_m2_boss_outer_d     = 4.4;        // M2ネジ受けボス外径 (肉厚強化 φ4.4mm)
btn_m2_boss_inner_d     = 1.7;        // M2ネジ下穴径 (PLAタッピング用 φ1.7mm)
btn_m2_boss_h           = 0.6;        // ボス裏面突出高さ (0.6mm: 基板前端面との衝突を回避し安全クリアランス確保)
btn_m2_hole_depth       = 4.0;        // M2ネジ下穴深さ (4.0mm)
btn_plunger_screw_l     = 4.0;        // 推奨M2なべ小ねじ長さ (L=4〜6mm)

// --- 前面アクリル化粧パネル埋め込み用リセス（段差ポケット） ---
front_recess_depth    = btn_magnet_t; // 3.0mm (アクリル厚みに完全一致)
front_recess_margin   = 0.6;          // リセスクリアランス (周囲0.6mm)
front_recess_w        = btn_side_width + front_recess_margin * 2;   // 45.2mm
front_recess_h        = btn_side_height + front_recess_margin * 2;  // 21.2mm
front_recess_r        = btn_side_radius + front_recess_margin;      // 3.6mm

// --- ボリューム調整スリット（右側面に配置）および RK10J ダイヤル仕様 ---
vol_dial_d         = 14.0;       // ダイヤル外径 (φ14.0mm)
vol_dial_h         = 2.5;        // ダイヤル本体高さ (2.5mm)
vol_slit_width     = 16.0;       // ダイヤル操作スリット幅
vol_slit_radius    = 1.5;        // スリット下部角丸
vol_offset_y       = -5.0;       // Y軸方向オフセット（前方向へ5mm移動）
vol_slit_bottom_z  = 23.5;       // スリット下端高さ (基板表面23.8mmより0.3mm下: 内部露出を防ぎつつダイヤル全高を露出)
vol_slit_height    = 4.5;        // スリット高さ (天面28.0mmまで開放するUノッチ形状: 28.0 - 23.5 = 4.5mm)

// --- 電池ボックス (単4×3本 スイッチ付き) ---
batt_length        = 63.0;        // 横幅
batt_width         = 37.0;        // 縦幅
batt_height        = 17.0;        // 厚み
batt_clearance     = 0.6;         // 電池ボックス収容クリアランス
batt_pos_y         = 3.5;         // 電池ボックス中心Yオフセット（奥側M2支柱および手前スピーカーとの干渉回避位置）
batt_rib_t         = 1.6;         // ガイドリブ基本肉厚（剛性向上: 1.2 -> 1.6mm）
batt_rib_h         = 8.0;         // ガイドリブ高さ
batt_gusset_t      = 1.5;         // 補強三角リブ厚み
batt_gusset_rear_d = 4.0;         // 奥側三角リブ奥行き
batt_gusset_front_d= 3.0;         // 手前側三角リブ奥行き
batt_gusset_h      = 6.5;         // 三角リブ高さ
spk_pos_y          = -28.5;       // スピーカー固定ボス中心Yオフセット（出音口を手前-Y方向に向ける）

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
pcb_seat_z         = wall_thickness + (spacer_pad_h - spacer_pocket_d) + pcb_standoff_h; // 基板底面高さ = 22.2mm
pcb_top_z          = pcb_seat_z + pcb_thickness; // 基板表面高さ = 23.8mm

// ダイヤル中心座標 (RK10J)
vol_dial_center_x  = pcb_width / 2 - 4.5; // ダイヤル中心X座標 (外周φ14mmが基板端から2.5mm突出)
vol_dial_center_z  = pcb_top_z + vol_dial_h / 2; // ダイヤル中心高さ = 25.05mm

// ボタンおよびアクリルパネルの統一中心高さ (Z = 23.0mm: 天面および底面とのクリアランス調和)
btn_center_z       = wall_thickness + pcb_standoff_h + 1.0;

// タクトスイッチ (EVQPUC02K: 全高1.65mm) 中心高さおよびボタン中心からのプランジャーオフセット
tact_switch_center_z = pcb_top_z + 1.65 / 2; // Z = 24.625mm (基板20mmスペーサー上の実高さ)
btn_plunger_offset_y = tact_switch_center_z - btn_center_z; // +1.625mm (スイッチ中心に完全一致)

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
