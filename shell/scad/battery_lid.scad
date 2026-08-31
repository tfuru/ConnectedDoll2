// ==========================================
// ConnectedDoll2 Battery Lid (battery_lid.scad)
// 回転ロック式 底面電池フタ
// ==========================================

include <params.scad>;

module battery_switch_cutout() {
    // スイッチ操作開口窓 (深さ0.8mmまでの面取り + 垂直壁0.8mm以上を保持し薄刃化・ナイフエッジを完全防止)
    chamfer_depth = 0.8;
    // 1. 表面すり鉢状面取り部 (Z = -0.2 〜 chamfer_depth)
    hull() {
        for (dx = [-batt_sw_w/2 + batt_sw_r, batt_sw_w/2 - batt_sw_r]) {
            for (dy = [-batt_sw_d/2 + batt_sw_r, batt_sw_d/2 - batt_sw_r]) {
                translate([dx, dy, -0.2])
                    cylinder(h=0.01, r=batt_sw_r + batt_sw_chamfer, $fn=32);
                translate([dx, dy, chamfer_depth])
                    cylinder(h=0.01, r=batt_sw_r, $fn=32);
            }
        }
    }
    // 2. 内部ストレート貫通部 (Z = chamfer_depth 〜 全層貫通: 垂直壁厚み0.8mm以上を確保)
    hull() {
        for (dx = [-batt_sw_w/2 + batt_sw_r, batt_sw_w/2 - batt_sw_r]) {
            for (dy = [-batt_sw_d/2 + batt_sw_r, batt_sw_d/2 - batt_sw_r]) {
                translate([dx, dy, chamfer_depth - 0.01])
                    cylinder(h=batt_lid_t + 1.5, r=batt_sw_r, $fn=32);
            }
        }
    }
}

module battery_lid() {
    dial_rel_y = rotary_pos_y - batt_pos_y; // ダイヤル中心のフタ中心からの相対Y座標 (23.7mm)
    cam_shelf_r = rotary_dial_d / 2 - rotary_cam_overlap; // 4.7mm (Dカット逃げ半径)

    difference() {
        union() {
            // 1. フタ本体ベースプレート (厚み batt_lid_t = 1.6mm, 角丸 R=2.5mm)
            translate([-batt_lid_w/2, -batt_lid_d/2, 0])
                rounded_cube([batt_lid_w, batt_lid_d, batt_lid_t], 2.5);

            // 2. 内側位置決めステップ (深さ0.8mm: 開口部 64x38mm 内側に全周0.65mm隙間で嵌合、干渉防止)
            step_w = batt_bay_w - batt_lid_step_margin * 2;
            step_d = batt_bay_d - batt_lid_step_margin * 2;
            translate([-step_w/2, -step_d/2, batt_lid_t - 0.01])
                rounded_cube([step_w, step_d, 0.8], 2.0);

            // 3. 手前側 アンダーカット差し込み係止ツメ (左右2箇所: 裏面ステップ Z=1.6mm〜2.7mmから手前へ突出)
            step_front_y = -step_d / 2; // 内側ステップ手前端面 (-18.35mm)
            tab_tip_y = -batt_lid_d / 2 - batt_tab_d; // ツメ先端Y座標 (-22.15mm: ベース手前端より手前へ2.2mm突出)
            tab_total_d = step_front_y - tab_tip_y;   // ツメ総前後長 (約3.8mm: ステップと強固に一体化)

            for (dx = [-batt_tab_pitch / 2, batt_tab_pitch / 2]) {
                translate([dx - batt_tab_w / 2, tab_tip_y, batt_tab_z]) {
                    hull() {
                        // 根元側（ステップ手前壁と完全一体化）
                        translate([0, tab_total_d - 0.01, 0])
                            cube([batt_tab_w, 0.01, batt_tab_t]);
                        // 先端側（上下・左右に斜め差し込み用スムーズ導入テーパー付き）
                        translate([0.5, 0, 0.2])
                            cube([batt_tab_w - 1.0, 0.01, batt_tab_t - 0.4]);
                        // 中間部
                        translate([0, 0.8, 0])
                            cube([batt_tab_w, 0.01, batt_tab_t]);
                    }
                }
            }
        }

        // 4. スイッチ操作開口窓 (全層完全貫通)
        translate([batt_sw_offset_x, batt_sw_offset_y, 0])
            battery_switch_cutout();

        // 5. 奥側 回転ロック受け円弧ポケット & カム通過貫通穴
        translate([rotary_pos_x, dial_rel_y, 0]) {
            // (a) ダイヤルツバ受座シェルフ (深さ rotary_cam_shelf_z = 0.75mm: シェルフ残存肉厚 0.85mm を保持、外周クリアランス+0.6mmへ拡大)
            translate([0, 0, -0.2])
                cylinder(h=rotary_cam_shelf_z + 0.2, r=rotary_dial_d / 2 + 0.6, $fn=60);
            // (b) カム解錠時通過貫通穴 (半径 cam_shelf_r = 5.0mm: 全層貫通、通過クリアランス拡大)
            translate([0, 0, -0.2])
                cylinder(h=batt_lid_t + 2.0, r=cam_shelf_r + 0.3, $fn=60);
        }

        // 6. 指掛けネイルノッチ (奥側フタ端面: 爪でフタを持ち上げやすくする凹み)
        translate([-16.0, batt_lid_d/2 - 1.0, -0.1])
            hull() {
                translate([-4.0, 0, 0]) cylinder(h=batt_lid_t + 1.0, r=2.0, $fn=20);
                translate([4.0, 0, 0]) cylinder(h=batt_lid_t + 1.0, r=2.0, $fn=20);
            }
    }
}

// 単体プレビュー描画
battery_lid();
