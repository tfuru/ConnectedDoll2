// ==========================================
// ConnectedDoll2 Main Assembly (main_assembly.scad)
// ==========================================

include <params.scad>;
use <top_cover.scad>;
use <bottom_case.scad>;
use <front_button.scad>;
use <acrylic_panel.scad>;
use <battery_lid.scad>;
use <rotary_lock.scad>;

// アセンブリ表示パラメータ
explode_z       = 20.0; // 分解表示の隙間（0で完全組み立て状態）
explode_btn     = 15.0; // ボタン手前への分解距離
explode_screw   = 12.0; // M2ネジの底面引き抜き距離
show_mockup     = true; // 内部モックアップ（基板・電池・スピーカー）の表示フラグ
show_screws     = true; // 締結M2ネジの表示フラグ
show_acrylic    = true; // アクリル化粧パネルの表示フラグ

center_x = case_outer_w / 2;
// center_y は params.scad で定義済み (center_y=37.4)

// --- ダミーモックアップ部品モジュール ---

// 1. スピーカーモックアップ (TR-WS-2014B: 出音口・取付耳を手前-Y方向に向ける)
module speaker_mockup() {
    color([0.2, 0.2, 0.2, 0.9]) {
        // スピーカー本体 (奥行き 13.9mm, 取付穴中心から手前 1.65mm, 奥へ 12.25mm)
        translate([-spk_body_w/2, -spk_ear_to_front, 0])
            cube([spk_body_w, spk_body_h, spk_thickness]);

        // 取付耳（フランジ: 厚み 1.0mm, ネジ穴位置 Y=0）
        translate([-spk_ear_w/2, -spk_ear_to_front, 0])
            difference() {
                cube([spk_ear_w, 3.5, 1.0]);
                // M1.8 ネジ穴 (ピッチ 24.7mm)
                for (dx = [-spk_hole_pitch/2, spk_hole_pitch/2]) {
                    translate([dx + spk_ear_w/2, spk_ear_to_front, -0.1])
                        cylinder(h=1.2, d=spk_hole_dia);
                }
            }
    }
    // 出音口の視覚化 (レッドアクセント: 手前側面スロット & 前面開口)
    color([0.9, 0.2, 0.2, 1.0]) {
        // 手前側面出音スロット
        translate([-12.0/2, -spk_ear_to_front - 0.1, 1.2])
            cube([12.0, 0.2, 2.0]);
        // 前面開口インジケータ
        translate([-12.0/2, -spk_ear_to_front + 0.5, spk_thickness - 0.1])
            cube([12.0, 3.0, 0.2]);
    }
}

// 2. 電池ボックスモックアップ (単4x3本 横向き・底面向き電源スイッチ付き)
module battery_box_mockup() {
    color([0.15, 0.15, 0.15, 0.85]) {
        difference() {
            translate([-batt_length/2, -batt_width/2, 0])
                cube([batt_length, batt_width, batt_height]);
            // 底面向きスイッチ埋め込みリセス (実寸忠実: X = +14.0mm 〜 +29.0mm, Y = batt_sw_offset_y基準)
            translate([14.0, batt_sw_offset_y - 5.0, -0.1])
                cube([15.0, 10.0, 2.0]);
        }
    }
    // スイッチ突起 (レッドアクセント: ON/OFFスライダ, X = +23.5mm: 実機写真と完全一致)
    color([0.9, 0.2, 0.2, 1.0]) {
        translate([23.5, batt_sw_offset_y - 1.8, 0.2])
            cube([3.2, 3.6, 1.8]);
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

    // 基板右端のボリュームダイヤル (RK10J11R0A0H モックアップ: φ14.0mm x 2.5mm)
    color([0.25, 0.25, 0.25, 1.0]) {
        translate([vol_dial_center_x, vol_offset_y, pcb_thickness]) {
            cylinder(h=vol_dial_h, d=vol_dial_d);
            // ダイヤルローレット外周
            cylinder(h=1.0, d=vol_dial_d + 0.3);
        }
    }
}

// 4. M2 六角両メススペーサーモックアップ (20mm, 二面幅4.0mm)
module hex_spacer_mockup(body_h=20.0, hex_w=4.0) {
    color([0.2, 0.2, 0.2, 0.95]) { // ブラック/ナイロンまたは真鍮色
        difference() {
            // 六角柱本体
            rotate([0, 0, 30])
                cylinder(h=body_h, d=hex_w / cos(30), $fn=6);
            // 上下 M2 めねじ穴
            translate([0, 0, -0.1])
                cylinder(h=body_h + 0.2, d=2.0);
        }
    }
}

// 5. M2 締結小ネジモックアップ (なべ小ねじ)
module m2_screw_mockup(length=5.0) {
    color([0.85, 0.85, 0.9, 1.0]) {
        // ネジ頭 (なべ頭)
        cylinder(h=1.3, d=3.5);
        // ネジ軸
        translate([0, 0, 1.3])
            cylinder(h=length, d=2.0);
    }
}

// ==========================================
// 全体アセンブリ配置
// ==========================================

module main_assembly(explode_z=explode_z, explode_btn=explode_btn, explode_screw=explode_screw) {
    // 1. ボトムケース (Base)
    color([0.95, 0.75, 0.2, 0.85])
        bottom_case();

    // 2. 内部部品（ボトムケース内）
    if (show_mockup) {
        // スピーカー (手前前面側 Y=spk_pos_y)
        translate([center_x, center_y + spk_pos_y, wall_thickness + spk_boss_h])
            speaker_mockup();

        // 電池ボックス (横向き配置 / 底面引き抜き分解アニメーション連動)
        batt_z_pos = (explode_z > 0) ? (-explode_z * 0.6) : wall_thickness;
        translate([center_x, center_y + batt_pos_y, batt_z_pos])
            battery_box_mockup();

        // M2 六角スペーサー (四隅 52x52mm ピッチ、底面座面ポケットから直立)
        translate([center_x, center_y, wall_thickness + (spacer_pad_h - spacer_pocket_d)]) {
            for (dx = [-joint_pitch / 2, joint_pitch / 2]) {
                for (dy = [-joint_pitch / 2, joint_pitch / 2]) {
                    translate([dx, dy, 0])
                        hex_spacer_mockup(spacer_body_h, 4.0);
                }
            }
        }

        // メイン基板 (スペーサー座面高さ pcb_seat_z の上)
        translate([center_x, center_y, pcb_seat_z])
            pcb_mockup();

        // 基板上 M2 六角スペーサー (5mm, 四隅 52x52mm ピッチ、基板を独立固定)
        translate([center_x, center_y, pcb_top_z]) {
            for (dx = [-joint_pitch / 2, joint_pitch / 2]) {
                for (dy = [-joint_pitch / 2, joint_pitch / 2]) {
                    translate([dx, dy, 0])
                        hex_spacer_mockup(top_spacer_h, 4.0);
                }
            }
        }
    }

    // 1b. 底面電池フタ (Battery Lid: -Z方向へ引き抜き分解表示)
    lid_z_pos = (explode_z > 0) ? (-explode_z * 1.2) : 0;
    color([0.90, 0.70, 0.20, 0.95])
        translate([center_x, center_y + batt_pos_y, lid_z_pos])
            battery_lid();

    // 1c. 回転ロックダイヤル (Rotary Lock: 分解時は解錠90°、組立時は施錠0°、底面Z=0より0.2mm奥へ完全没入)
    rotary_angle = (explode_z > 0) ? 90 : 0;
    rotary_z_pos = (explode_z > 0) ? (-explode_z * 1.2) : rotary_cam_shelf_z;
    color([0.85, 0.85, 0.90, 1.0])
        translate([center_x + rotary_pos_x, center_y + rotary_pos_y, rotary_z_pos])
            rotary_lock(angle=rotary_angle);

    // 1d. 回転ロック用 M2支柱ネジ (底面外側からダイヤルを貫通してボトムボスへ締結: M2x5mm)
    if (show_screws) {
        screw_rotary_z = (explode_screw > 0) ? (-explode_screw * 1.5) : (rotary_z_pos - rotary_rib_h);
        color([0.8, 0.8, 0.85, 1.0])
            translate([center_x + rotary_pos_x, center_y + rotary_pos_y, screw_rotary_z])
                m2_screw_mockup(5.0);
    }

    btn_z_pos = btn_center_z;
    // ボタンフランジ前面がケース前面内壁 (Y = wall_thickness = 2.0mm) に当接
    // フランジ裏面 (ローカルZ=0) のグローバルY座標 = 2.0 + btn_flange_t = 3.2mm
    btn_y_pos = wall_thickness + btn_flange_t;
    btn_explode_y = btn_y_pos - explode_btn;
    color([0.2, 0.6, 0.9, 0.9])
        translate([center_x, btn_explode_y, btn_z_pos])
            rotate([90, 0, 0])
                front_button();

    // ボタン内蔵 ネオジム磁石 (金/ニッケルメッキ色: ボタン操作面ポケット内に配置)
    color([0.85, 0.75, 0.4, 1.0])
        translate([center_x, btn_explode_y - (btn_flange_t + btn_cap_depth - btn_magnet_t), btn_z_pos]) {
            for (dx = [-btn_magnet_pitch_w/2, btn_magnet_pitch_w/2]) {
                translate([dx, 0, 0])
                    rotate([90, 0, 0])
                        cylinder(h=btn_magnet_t, d=btn_magnet_d);
            }
        }

    // ボタン裏面 M2アジャスタブル・プランジャーネジ (スチールシルバー色: インセットポケットからスイッチ押下調整用 M2x4mm)
    // スイッチ先端 (Y ≈ 7.6mm) に対して初期隙間0.3mmを残して調整配置
    screw_reach_y = (explode_btn > 0) ? (btn_explode_y + 0.5) : (center_y - pcb_height / 2 + 0.2 - 0.3 - 1.3);
    color([0.85, 0.85, 0.9, 1.0])
        translate([center_x, screw_reach_y, btn_z_pos + btn_plunger_offset_y])
            rotate([-90, 0, 0]) {
                // ネジ頭 (φ3.5mm x 1.3mm: タクトスイッチを押下)
                cylinder(h=1.3, d=3.5, $fn=24);
                // ネジ軸 (M2 x 4mm: ボタン内部のタッピング穴へねじ込み)
                translate([0, 0, -btn_plunger_screw_l])
                    cylinder(h=btn_plunger_screw_l, d=2.0, $fn=20);
            }

    // 左右2箇所の マイクロコイルスプリング (押しバネ: φ3.0mm x 7.0mm, ゴールド色)
    color([0.85, 0.75, 0.3, 0.95]) {
        for (dx = [-btn_spring_pitch_w / 2, btn_spring_pitch_w / 2]) {
            translate([center_x + dx, btn_explode_y, btn_z_pos + btn_spring_offset_y])
                rotate([-90, 0, 0])
                    cylinder(h=btn_spring_free_l, d=btn_spring_d, $fn=20);
        }
    }

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

        // 左右2箇所の M2 六角ナット (スチールシルバー色: パネル穴内に配置、ボタン側磁石に吸着)
        color([0.8, 0.8, 0.85, 1.0])
            translate([center_x, acrylic_y_pos, btn_z_pos]) {
                for (dx = [-btn_magnet_pitch_w/2, btn_magnet_pitch_w/2]) {
                    translate([dx, 0, 0])
                        rotate([90, 0, 0])
                            rotate([0, 0, 30])
                                cylinder(h=panel_nut_depth, d=4.0 / cos(30), $fn=6);
                }
            }
    }

    // 4. トップカバー (天板リッド: 開口部をボトムケースに向けて被せる)
    top_cover_z = bottom_case_h + top_cover_h + explode_z;
    color([0.9, 0.7, 0.2, 0.75])
        translate([case_outer_w, 0, top_cover_z])
            rotate([0, 180, 0])
                top_cover();

    // 5. ネジ締結部品
    if (show_screws) {
        // 5a. ボトム底面からのM2締結小ネジ (4隅 52x52mm ピッチ、L=5mm)
        translate([center_x, center_y, -explode_screw]) {
            for (dx = [-joint_pitch / 2, joint_pitch / 2]) {
                for (dy = [-joint_pitch / 2, joint_pitch / 2]) {
                    translate([dx, dy, 0])
                        m2_screw_mockup(bottom_screw_len);
                }
            }
        }

        // 5b. トップ天面ザグリからのM2締結小ネジ (4隅 52x52mm ピッチ、L=14mm)
        top_screw_z = top_cover_z + (explode_screw > 0 ? (explode_screw + 5.0) : 0);
        translate([center_x, center_y, top_screw_z]) {
            for (dx = [-joint_pitch / 2, joint_pitch / 2]) {
                for (dy = [-joint_pitch / 2, joint_pitch / 2]) {
                    translate([dx, dy, 0])
                        rotate([180, 0, 0])
                            m2_screw_mockup(top_screw_len);
                }
            }
        }
    }
}

// 描画
main_assembly();
