// ==========================================
// ConnectedDoll2 Main Assembly (main_assembly.scad)
// ==========================================

include <params.scad>;
use <top_cover.scad>;
use <bottom_case.scad>;
use <front_button.scad>;
use <acrylic_panel.scad>;

// アセンブリ表示パラメータ
explode_z       = 20.0; // 分解表示の隙間（0で完全組み立て状態）
explode_btn     = 15.0; // ボタン手前への分解距離
explode_screw   = 12.0; // M2ネジの底面引き抜き距離
show_mockup     = true; // 内部モックアップ（基板・電池・スピーカー）の表示フラグ
show_screws     = true; // 締結M2ネジの表示フラグ
show_acrylic    = true; // アクリル化粧パネルの表示フラグ

center_x = case_outer_w / 2;
center_y = case_outer_h / 2;

// --- ダミーモックアップ部品モジュール ---

// 1. スピーカーモックアップ (TR-WS-2014B)
module speaker_mockup() {
    color([0.2, 0.2, 0.2, 0.9]) {
        // スピーカー本体
        translate([-spk_width/2, -spk_height/2, 0])
            cube([spk_width, spk_height, spk_thickness]);
        // 取付耳（フランジ）
        translate([-spk_hole_pitch/2 - 2, -3.5, 0])
            cube([spk_hole_pitch + 4, 7, 1.0]);
    }
}

// 2. 電池ボックスモックアップ (単4x3本 横向き)
module battery_box_mockup() {
    color([0.15, 0.15, 0.15, 0.85]) {
        translate([-batt_length/2, -batt_width/2, 0])
            cube([batt_length, batt_width, batt_height]);
    }
}

// 3. メイン基板モックアップ (60x60mm)
module pcb_mockup() {
    color([0.1, 0.6, 0.2, 0.85]) {
        difference() {
            translate([-pcb_width/2, -pcb_height/2, 0])
                cube([pcb_width, pcb_height, pcb_thickness]);
            // 四隅の M2 ネジ穴 (52x52mm ピッチ)
            for (dx = [-pcb_hole_pitch/2, pcb_hole_pitch/2]) {
                for (dy = [-pcb_hole_pitch/2, pcb_hole_pitch/2]) {
                    translate([dx, dy, -0.1])
                        cylinder(h=pcb_thickness + 0.2, d=pcb_hole_dia);
                }
            }
        }
    }

    // 基板手前側のタクトスイッチ (EVQPUC02K: Top層実装, 基板外形の内側に配置)
    color([0.8, 0.8, 0.85, 1.0]) {
        // スイッチ本体 (Top層: 基板端より0.8mm内側)
        translate([-4.7/2, -pcb_height/2 + 0.8, pcb_thickness])
            cube([4.7, 4.5, 1.65]);
        // 水平アクチュエータ突起 (押しボタン: 基板端の内側に位置)
        translate([-1.5/2, -pcb_height/2 + 0.2, pcb_thickness + 0.3])
            cube([1.5, 0.6, 1.0]);
    }

    // 基板右端のボリュームダイヤル (RK10J11R0A0H モックアップ)
    color([0.3, 0.3, 0.3, 1.0]) {
        translate([pcb_width/2 - 2.0, vol_offset_y, pcb_thickness])
            cylinder(h=2.2, d=11.0);
    }
}

// 4. M2 六角オスメススペーサーモックアップ (20mm + 6mm)
module hex_spacer_mockup(body_h=20.0, male_h=6.0, hex_w=4.0) {
    color([0.2, 0.2, 0.2, 0.95]) { // ブラック/ナイロンまたは真鍮色
        // 六角柱本体
        rotate([0, 0, 30])
            cylinder(h=body_h, d=hex_w / cos(30), $fn=6);
        // 先端おねじ
        translate([0, 0, body_h])
            cylinder(h=male_h, d=2.0);
    }
}

// 5. M2 ボトム締結小ネジモックアップ (M2 x 5mm)
module m2_screw_mockup(length=5.0) {
    color([0.85, 0.85, 0.9, 1.0]) {
        // ネジ頭 (鍋頭 / 皿頭)
        cylinder(h=1.4, d=joint_screw_head_d);
        // ネジ軸
        translate([0, 0, 1.4])
            cylinder(h=length, d=2.0);
    }
}

// ==========================================
// 全体アセンブリ配置
// ==========================================

module main_assembly() {
    // 1. ボトムケース (Base)
    color([0.95, 0.75, 0.2, 0.85])
        bottom_case();

    // 2. 内部部品（ボトムケース内）
    if (show_mockup) {
        // スピーカー (手前前面側 Y=spk_pos_y)
        translate([center_x, center_y + spk_pos_y, wall_thickness + spk_boss_h])
            speaker_mockup();

        // 電池ボックス (横向き配置 / Y=batt_pos_y)
        translate([center_x, center_y + batt_pos_y, wall_thickness])
            battery_box_mockup();

        // M2 六角スペーサー (四隅 52x52mm ピッチ、底面から直立)
        translate([center_x, center_y, wall_thickness]) {
            for (dx = [-joint_pitch / 2, joint_pitch / 2]) {
                for (dy = [-joint_pitch / 2, joint_pitch / 2]) {
                    translate([dx, dy, 0])
                        hex_spacer_mockup(spacer_body_h, spacer_male_h, 4.0);
                }
            }
        }

        // メイン基板 (スペーサー高さ pcb_standoff_h の上)
        translate([center_x, center_y, wall_thickness + pcb_standoff_h])
            pcb_mockup();
    }

    // 3. 前面ボタン (フロント手前側面の3.0mmリセス奥壁に配置)
    btn_z_pos = btn_center_z;
    btn_y_pos = front_recess_depth + wall_thickness; // Y = 5.0mm (ケース外壁Y=0から3mm奥)
    color([0.2, 0.6, 0.9, 0.9])
        translate([center_x, btn_y_pos - explode_btn, btn_z_pos])
            rotate([90, 0, 0])
                front_button();

    // 3b. アクリル化粧パネル (実パーツモジュール acrylic_panel_3d() を使用して配置)
    if (show_acrylic) {
        // ボタン操作面（フランジ厚み1.2mm + キャップ深さ2.5mm = 3.7mm手前）に密着配置
        btn_front_face_y = btn_y_pos - (btn_flange_t + btn_cap_depth);
        acrylic_y_pos = btn_front_face_y - (explode_btn > 0 ? (explode_btn + 10.0) : 0.0);
        
        // アクリルプレート
        color([0.9, 0.9, 0.9, 0.65])
            translate([center_x, acrylic_y_pos, btn_z_pos])
                rotate([90, 0, 0])
                    acrylic_panel_3d();

        // 左右2箇所のネオジム磁石 (金/ニッケルメッキ色: 磁石穴内に配置、ボタン側M2ナットに吸着)
        color([0.85, 0.75, 0.4, 1.0])
            translate([center_x, acrylic_y_pos, btn_z_pos]) {
                for (dx = [-btn_magnet_pitch_w/2, btn_magnet_pitch_w/2]) {
                    translate([dx, 0, 0])
                        rotate([90, 0, 0])
                            cylinder(h=btn_magnet_t, d=btn_magnet_d);
                }
            }
    }

    // 4. トップカバー (天板リッド: 開口部をボトムケースに向けて被せる)
    color([0.9, 0.7, 0.2, 0.75])
        translate([case_outer_w, 0, bottom_case_h + top_cover_h + explode_z])
            rotate([0, 180, 0])
                top_cover();

    // 5. ボトム底面からのM2締結短ネジ (4隅 52x52mm ピッチ、L=5mm)
    if (show_screws) {
        translate([center_x, center_y, -explode_screw]) {
            for (dx = [-joint_pitch / 2, joint_pitch / 2]) {
                for (dy = [-joint_pitch / 2, joint_pitch / 2]) {
                    translate([dx, dy, 0])
                        m2_screw_mockup(5.0);
                }
            }
        }
    }
}

// 描画
main_assembly();
