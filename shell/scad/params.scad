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

// --- スピーカー出音スリット（ボトムケース手前前面壁） ---
spk_slit_w        = 1.2;        // スリット幅 (1.2mm)
spk_slit_h        = 6.0;        // スリット高さ (6.0mm)
spk_slit_r        = 0.6;        // スリット上下端の角丸 (0.6mm: 3Dプリント時のブリッジ垂れ防止)
spk_slit_pitch    = 2.4;        // スリット間隔ピッチ (2.4mm: 肉厚1.2mmのリブ柱を形成)
spk_slit_count    = 7;          // スリット本数 (7本: 開口全幅 15.6mm)
spk_slit_center_z = 8.2;        // スリット中心高さ (Z=8.2mm: スピーカー出音口中心に完全一致)

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
btn_m2_boss_h           = 0.0;        // インセット構造により裏面突出ボスは0mm (完全フラット)
btn_inset_pocket_d      = 5.0;        // M2ネジ頭インセット収容ポケット径 (φ5.0mm)
btn_inset_pocket_depth  = 1.5;        // M2ネジ頭インセット収容ポケット深さ (1.5mm)
btn_m2_tap_depth        = 2.0;        // ポケット底面からのタッピング下穴深さ (2.0mm)
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
vol_slit_bottom_z  = 24.7;       // スリット下端高さ (基板表面25.0mmより0.3mm下: 内部露出を防ぎつつダイヤル全高を露出)
vol_slit_height    = 3.3;        // スリット高さ (天面28.0mmまで開放するUノッチ形状: 28.0 - 24.7 = 3.3mm)

// --- 電池ボックス (単4×3本 スイッチ付き) & 底面取り出しベイ ---
batt_length        = 63.0;        // 横幅
batt_width         = 37.0;        // 縦幅
batt_height        = 17.0;        // 厚み
batt_clearance     = 0.6;         // 電池ボックス収容クリアランス
batt_pos_y         = 1.5;         // 電池ボックス中心Yオフセット（手前スピーカーおよび奥側回転ロックとの最適バランス）
batt_stop_z        = wall_thickness + batt_height + 0.2; // 内部天井ストッパー高さ (Z = 19.2mm: 基板裏面22.2mmに対し3.0mmクリアランス)

// --- 底面開口ベイ (Battery Bay) ---
batt_bay_clearance = 0.5;         // 開口部クリアランス (全周0.5mm)
batt_bay_w         = batt_length + batt_bay_clearance * 2; // 64.0mm
batt_bay_d         = batt_width + batt_bay_clearance * 2;  // 38.0mm

// --- 電池フタ (Battery Lid) & 底面段差リセス座面 ---
batt_lid_t            = 1.6;         // フタ本体肉厚
batt_lid_flange       = 1.5;         // 段差受座幅 (1.5mm)
batt_lid_recess_w     = batt_bay_w + batt_lid_flange * 2; // ボトム側段差リセス外寸 幅 (67.0mm: 基準寸法固定)
batt_lid_recess_d     = batt_bay_d + batt_lid_flange * 2; // ボトム側段差リセス外寸 奥行き (41.0mm: 基準寸法固定)
batt_lid_recess_depth = batt_lid_t;  // 段差リセス深さ (1.6mm: ツライチ)
batt_lid_seat_z       = 3.6;         // 受け座補強フレーム上面高さ (底面Z=0基準: 3.6mm)
batt_lid_seat_t       = batt_lid_seat_z - batt_lid_recess_depth; // 受け座実肉厚 = 2.0mm (旧0.4mmの5倍、折損防止)

batt_lid_margin       = 0.55;        // フタ外周クリアランス (全周0.55mmの隙間を確保、3Dプリント干渉防止)
batt_lid_w            = batt_lid_recess_w - batt_lid_margin * 2; // 65.9mm (-0.5mm縮小)
batt_lid_d            = batt_lid_recess_d - batt_lid_margin * 2; // 39.9mm (-0.5mm縮小)
batt_lid_step_margin  = 0.65;        // 内側位置決めステップクリアランス (全周0.65mm隙間、開口部擦れ防止)

// --- 手前側差し込みツメ (Battery Lid Tabs) ＆ ボトム内側引っ掛けスリット ---
batt_tab_w            = 7.5;         // 手前側差し込みツメ幅 (7.5mm)
batt_tab_d            = 2.2;         // 差し込みツメ突出量 (フタベース端面から手前へ2.2mm突出)
batt_tab_t            = 1.1;         // 差し込みツメ厚み (スリット高さ1.6mmに対し上下余裕0.5mm確保)
batt_tab_z            = batt_lid_t;  // ツメ配置高さ (Z=1.6mm: フタ裏面ステップと面一から突出)
batt_tab_pitch        = 30.0;        // 左右2箇所ツメ配置ピッチ (30.0mm)

batt_slot_w           = 8.5;         // ボトム側ツメ受けスリット幅 (左右クリアランス各0.5mm確保)
batt_slot_d           = 2.6;         // ボトム側ツメ受けスリット深さ (突出量2.2mm+余裕0.4mm)
batt_slot_h           = 1.6;         // ボトム側ツメ受けスリット開口高さ (上下クリアランス0.5mm確保)
batt_slot_z           = batt_lid_recess_depth; // スリット底面高さ (Z=1.6mm: リセス座面裏側から開口)
batt_tab_roof_z       = 4.8;         // スリット天井補強フレーム高さ (スリット天井肉厚 4.8 - (1.6 + 1.6) = 1.6mm を確保)

// --- 電池ボックス スイッチアクセス開口窓 ---
batt_sw_w          = 23.0;        // スイッチ開口窓 幅 (X方向: +9.0mm拡大、右端+5.5mm/左端+3.5mm拡張)
batt_sw_d          = 14.0;        // スイッチ開口窓 奥行き (Y方向: +4.0mm拡大、指入れクリアランス確保)
batt_sw_r          = 2.5;         // スイッチ窓 角丸
batt_sw_offset_x   = 19.0;        // 電池ボックス中心からのXオフセット (スイッチ位置へ最適化)
batt_sw_offset_y   = 0.0;         // 電池ボックス中心からのYオフセット
batt_sw_chamfer    = 1.8;         // 底面外側 すり鉢状テーパー面取り量 (指先誘導・操作性向上)

// --- 回転ロック (Rotary Lock) ---
rotary_dial_d      = 13.0;        // ダイヤル外径 (φ13.0mm)
rotary_rim_t       = 1.4;         // ダイヤルツバ厚み (カム厚み 1.4mm)
rotary_rib_h       = 0.8;         // ダイヤルつまみリブ高さ (コイン溝兼用 0.8mm)
rotary_dial_t      = rotary_rim_t + rotary_rib_h; // ダイヤル全高 (2.2mm)
rotary_pocket_d    = 2.4;         // 底面沈め込みポケット深さ (全高2.2mmに対し2.4mm沈め込み、底面Z=0より0.2mm奥へ完全没入)
rotary_pocket_dia  = 14.6;        // 沈め込みポケット径 (操作用外周クリアランス0.8mm)
rotary_cam_shelf_z = rotary_pocket_d - rotary_rim_t; // カム下面高さ = 1.0mm (フタ受座シェルフ高さ)
rotary_cam_overlap = 1.8;         // ロック時のフタへの掛かり代 (1.8mm)
rotary_pivot_pass_d = 2.3;        // ダイヤル中心 M2支柱ネジ通過穴径 (M2ネジ軸φ2.0mmに対しスムーズな空転を確保)
rotary_screw_head_d = 4.2;        // ダイヤル表面 M2ネジ頭沈め穴径 (φ4.2mm: なべ頭φ3.5mmに十分なクリアランス)
rotary_screw_head_h = 1.3;        // ダイヤル表面 M2ネジ頭沈め深さ (1.3mm: なべ頭が完全に沈み込む)
rotary_tap_hole_d   = 1.7;        // ボトムケース側 M2タッピング下穴径 (PLA直接タッピング用 φ1.7mm)
rotary_tap_depth    = 5.0;        // ボトムケース側 M2タッピング有効深さ (5.0mm)
rotary_pos_x       = 0.0;         // X中心 (center_xに対称)
rotary_pos_y       = batt_pos_y + batt_bay_d / 2 + rotary_dial_d / 2 - rotary_cam_overlap; // 奥側ローカルY座標 = 25.2mm
rotary_stop_angle  = 90.0;        // 施錠〜解錠の回転角度 (90°)
rotary_pedestal_w   = rotary_pocket_dia + 2.4; // 台座ブロック幅 (17.0mm: φ14.6mmポケット真上を完全被覆)
rotary_pedestal_h   = 4.0;                     // ケース内底面からの台座高さ (4.0mm: Z=2.0〜6.0mm)
batt_rear_guide_pitch = 24.0;                  // 奥側垂直ガイドリブ配置ピッチ (左右対称 ±12.0mm)
batt_rear_guide_t   = 1.6;                     // 奥側垂直ガイドリブ厚み (1.6mm)

spk_pos_y          = -31.0;       // スピーカー固定ボス中心Yオフセット（前面方向へ2.5mm移動、電池ボックスとの間に1.75mmクリアランスを確保）


// --- ケース寸法計算 ---
case_front_extend = 3.0;         // ケース手前側壁の前方拡張量 (+3.0mm: 基板とのクリアランス確保)
case_inner_w   = pcb_width + clearance * 2 + 4.0; // 内部幅 (約 64.8mm)
case_inner_h   = pcb_height + clearance * 2 + 4.0 + case_front_extend; // 内部奥行き (64.8 + 3.0 = 67.8mm)

top_cover_h    = 8.0;         // トップカバー高さ（薄型フタ・天板）
bottom_case_h  = 28.0;        // ボトムケース高さ（20mmスペーサー + 基板 + スイッチ開口を収容、28mm）

case_outer_w   = case_inner_w + wall_thickness * 2; // 外幅 (約 68.8mm)
case_outer_h   = case_inner_h + wall_thickness * 2; // 外高 (約 71.8mm)

// 基板および内部固定部品の基準中心座標 (背面クリアランス2.4mmを維持し、前方を+3mm拡大)
center_x       = case_outer_w / 2; // 34.4mm
center_y       = (pcb_width + clearance * 2 + 4.0) / 2 + wall_thickness + case_front_extend; // 37.4mm

// --- M2 六角オスメスネジスペーサー仕様 ---
spacer_body_h      = 20.0;           // スペーサー本体（六角部）長さ = 20.0mm
spacer_male_h      = 6.0;            // 先端おねじ部長さ = 6.0mm
spacer_hex_w       = 4.4;            // ボトム側回り止め六角ポケット二面幅 (対辺 4.0mm + 余裕0.4mm)
spacer_pocket_d    = 1.0;            // 回り止め六角ポケット深さ
spacer_pad_h       = 2.4;            // ボトム底面のスペーサー受け座パッド高さ (2.4mm: 六角ポケット底面Z=3.4mm、座面肉厚2.0mm確保)
pcb_standoff_h     = spacer_body_h;  // 基板受け面高さ = 20.0mm
pcb_seat_z         = wall_thickness + (spacer_pad_h - spacer_pocket_d) + pcb_standoff_h; // 基板底面高さ = 23.4mm
pcb_top_z          = pcb_seat_z + pcb_thickness; // 基板表面高さ = 25.0mm

// ダイヤル中心座標 (RK10J)
vol_dial_center_x  = pcb_width / 2 - 4.5; // ダイヤル中心X座標 (外周φ14mmが基板端から2.5mm突出)
vol_dial_center_z  = pcb_top_z + vol_dial_h / 2; // ダイヤル中心高さ = 26.25mm

// ボタンおよびアクリルパネルの統一中心高さ (Z = 24.2mm: 天面および底面とのクリアランス調和)
btn_center_z       = pcb_seat_z + 0.8;

// タクトスイッチ (EVQPUC02K: 全高1.65mm) 中心高さおよびボタン中心からのプランジャーオフセット
tact_switch_center_z = pcb_top_z + 1.65 / 2; // Z = 25.825mm (基板20mmスペーサー上の実高さ)
btn_plunger_offset_y = tact_switch_center_z - btn_center_z; // +1.625mm (スイッチ中心に完全一致)

// --- 統合締結ボス・ネジ穴寸法 ---
joint_pitch        = pcb_hole_pitch; // 52.0mm
joint_boss_outer   = 6.0;            // 締結ボス外径 (φ6.0mm)
joint_screw_pass   = 2.2;            // M2 ネジ通過穴径 (φ2.2mm)
joint_screw_tap    = 1.8;            // M2 おねじ受けタッピング穴径 (φ1.8mm)
joint_screw_head_d = 4.4;            // M2 ネジ頭沈め径 (φ4.4mm: なべ頭φ3.5mmに対して余裕確保)
joint_screw_head_h = 1.4;            // ネジ頭沈め深さ (1.4mm: なべ頭厚み1.3mmに対し0.1mmツライチ沈め)
joint_screw_seat_t = (wall_thickness + spacer_pad_h - spacer_pocket_d) - joint_screw_head_h; // 締結座面純肉厚 = 2.0mm (旧0.4mmの5倍、破断・突き抜けを完全防止)
top_joint_boss_h   = top_cover_h - wall_thickness + (bottom_case_h - pcb_top_z); // トップ側ボス高さ = 9.0mm (基板表面Z=25.0mmまで延長して基板を挟持)
top_screw_len      = 14.0;           // トップ側推奨M2締結小ネジ長さ (L=14〜16mm)
bottom_screw_len   = 5.0;            // ボトム側推奨M2締結小ネジ長さ (L=5〜6mm)
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
