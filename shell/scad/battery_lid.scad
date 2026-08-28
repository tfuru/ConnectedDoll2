// ==========================================
// ConnectedDoll2 Battery Lid (battery_lid.scad)
// 回転ロック式 底面電池フタ
// ==========================================

include <params.scad>;

module battery_switch_cutout() {
    // スイッチ操作開口窓 (テーパー面取り付き、全層完全貫通)
    hull() {
        for (dx = [-batt_sw_w/2 + batt_sw_r, batt_sw_w/2 - batt_sw_r]) {
            for (dy = [-batt_sw_d/2 + batt_sw_r, batt_sw_d/2 - batt_sw_r]) {
                // 底面外側 (面取り広がり)
                translate([dx, dy, -0.2])
                    cylinder(h=0.01, r=batt_sw_r + 0.8, $fn=24);
                // 内部側貫通 (内側ステップも含めて抜く)
                translate([dx, dy, batt_lid_t + 1.2])
                    cylinder(h=0.01, r=batt_sw_r, $fn=24);
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

            // 2. 内側位置決めステップ (深さ0.8mm: 開口部 64x38mm 内側に嵌合して横ズレを完全拘束)
            step_w = batt_bay_w - clearance * 2;
            step_d = batt_bay_d - clearance * 2;
            translate([-step_w/2, -step_d/2, batt_lid_t - 0.01])
                rounded_cube([step_w, step_d, 0.8], 2.0);

            // 3. 手前側 差し込み係止ツメ (左右2箇所)
            for (dx = [-batt_tab_pitch/2, batt_tab_pitch/2]) {
                translate([dx - batt_tab_w/2, -batt_lid_d/2 - batt_tab_d, 0]) {
                    hull() {
                        cube([batt_tab_w, batt_tab_d, batt_tab_t]);
                        // 先端導入テーパー
                        translate([0, 0, 0]) cube([batt_tab_w, 0.01, batt_tab_t]);
                        translate([0.5, 0, 0]) cube([batt_tab_w - 1.0, 0.01, batt_tab_t - 0.4]);
                    }
                }
            }
        }

        // 4. スイッチ操作開口窓 (全層完全貫通)
        translate([batt_sw_offset_x, batt_sw_offset_y, 0])
            battery_switch_cutout();

        // 5. 奥側 回転ロック受け円弧ポケット & カム通過貫通穴
        translate([rotary_pos_x, dial_rel_y, 0]) {
            // (a) ダイヤルツバ受座シェルフ (深さ rotary_cam_shelf_z = 1.0mm: シェルフ厚み 0.6mm を保持)
            translate([0, 0, -0.2])
                cylinder(h=rotary_cam_shelf_z + 0.2, r=rotary_dial_d / 2 + 0.4, $fn=60);
            // (b) カム解錠時通過貫通穴 (半径 cam_shelf_r = 4.7mm: 全層貫通)
            translate([0, 0, -0.2])
                cylinder(h=batt_lid_t + 2.0, r=cam_shelf_r, $fn=60);
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
