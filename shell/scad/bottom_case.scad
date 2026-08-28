// ==========================================
// ConnectedDoll2 Bottom Case (bottom_case.scad)
// ==========================================

include <params.scad>;

module side_button_cutout() {
    hull() {
        translate([-btn_side_width/2 + btn_side_radius, 0, -btn_side_height/2 + btn_side_radius])
            rotate([90, 0, 0]) cylinder(h=wall_thickness * 4, r=btn_side_radius, center=true);
        translate([btn_side_width/2 - btn_side_radius, 0, -btn_side_height/2 + btn_side_radius])
            rotate([90, 0, 0]) cylinder(h=wall_thickness * 4, r=btn_side_radius, center=true);
        translate([btn_side_width/2 - btn_side_radius, 0, btn_side_height/2 - btn_side_radius])
            rotate([90, 0, 0]) cylinder(h=wall_thickness * 4, r=btn_side_radius, center=true);
        translate([-btn_side_width/2 + btn_side_radius, 0, btn_side_height/2 - btn_side_radius])
            rotate([90, 0, 0]) cylinder(h=wall_thickness * 4, r=btn_side_radius, center=true);
    }
}

module spacer_mount_pad(pad_d=6.8, pad_h=1.2, hex_w=4.4, pocket_d=1.0, pass_d=2.2, dir_x=0, dir_y=0) {
    difference() {
        union() {
            // スペーサー受け座パッド (φ6.8mm: 六角対辺4.4mmに対し肉厚1.2mmを確保)
            cylinder(h=pad_h, d=pad_d);
            // 根元テーパーベース (φ7.4mm)
            cylinder(h=pad_h, d1=pad_d + 0.6, d2=pad_d);
            // コーナー外壁への小型リブ（底面補強）
            if (dir_x != 0 && dir_y != 0) {
                dx_wall = dir_x * (case_inner_w / 2 - joint_pitch / 2 + 0.1);
                dy_wall = dir_y * (case_inner_h / 2 - joint_pitch / 2 + 0.1);
                hull() {
                    translate([0, -rib_thickness/2, 0]) cube([0.01, rib_thickness, pad_h]);
                    translate([dx_wall, -rib_thickness/2, 0]) cube([0.01, rib_thickness, pad_h]);
                }
                hull() {
                    translate([-rib_thickness/2, 0, 0]) cube([rib_thickness, 0.01, pad_h]);
                    translate([-rib_thickness/2, dy_wall, 0]) cube([rib_thickness, 0.01, pad_h]);
                }
            }
        }
        // 回り止め六角ポケット（六角柱の二面幅 hex_w を収容）
        translate([0, 0, pad_h - pocket_d])
            rotate([0, 0, 30])
                cylinder(h=pocket_d + 0.1, d=hex_w / cos(30), $fn=6);
        
        // M2ネジ貫通穴
        translate([0, 0, -0.1])
            cylinder(h=pad_h + 0.2, d=pass_d);
    }
}

module speaker_boss(outer_d, inner_d, height) {
    difference() {
        union() {
            // ボス円筒
            cylinder(h=height, d=outer_d);
            // 根元テーパー
            cylinder(h=2.5, d1=outer_d + 2.0, d2=outer_d);
            // 前面壁への三角リブ
            dy_front = -(case_inner_h / 2 + spk_pos_y);
            hull() {
                translate([-rib_thickness/2, 0, 0]) cube([rib_thickness, 0.01, height]);
                translate([-rib_thickness/2, dy_front, 0]) cube([rib_thickness, 0.01, 2.0]);
            }
        }
        translate([0, 0, -0.1])
            cylinder(h=height + 0.2, d=inner_d);
    }
}

module volume_dial_cutout() {
    hull() {
        translate([0, -vol_slit_width/2 + vol_slit_radius, vol_slit_radius])
            rotate([0, 90, 0]) cylinder(h=wall_thickness * 3, r=vol_slit_radius, center=true);
        translate([0, vol_slit_width/2 - vol_slit_radius, vol_slit_radius])
            rotate([0, 90, 0]) cylinder(h=wall_thickness * 3, r=vol_slit_radius, center=true);
        translate([0, vol_slit_width/2 - vol_slit_radius, vol_slit_height - vol_slit_radius])
            rotate([0, 90, 0]) cylinder(h=wall_thickness * 3, r=vol_slit_radius, center=true);
        translate([0, -vol_slit_width/2 + vol_slit_radius, vol_slit_height - vol_slit_radius])
            rotate([0, 90, 0]) cylinder(h=wall_thickness * 3, r=vol_slit_radius, center=true);
    }
}

module front_recess_cutout() {
    hull() {
        translate([-front_recess_w/2 + front_recess_r, 0, -front_recess_h/2 + front_recess_r])
            rotate([90, 0, 0]) cylinder(h=front_recess_depth * 2, r=front_recess_r, center=true);
        translate([front_recess_w/2 - front_recess_r, 0, -front_recess_h/2 + front_recess_r])
            rotate([90, 0, 0]) cylinder(h=front_recess_depth * 2, r=front_recess_r, center=true);
        translate([front_recess_w/2 - front_recess_r, 0, front_recess_h/2 - front_recess_r])
            rotate([90, 0, 0]) cylinder(h=front_recess_depth * 2, r=front_recess_r, center=true);
        translate([-front_recess_w/2 + front_recess_r, 0, front_recess_h/2 - front_recess_r])
            rotate([90, 0, 0]) cylinder(h=front_recess_depth * 2, r=front_recess_r, center=true);
    }
}

module bottom_case() {
    center_x = case_outer_w / 2;
    center_y = case_outer_h / 2;

    difference() {
        // --- 外殻シェル ---
        rounded_cube([case_outer_w, case_outer_h, bottom_case_h], corner_radius);

        // --- 内部くり抜き ---
        translate([wall_thickness, wall_thickness, wall_thickness])
            rounded_cube([case_inner_w, case_inner_h, bottom_case_h], max(1, corner_radius - wall_thickness));

        // --- 手前側面（フロント壁: Y=0側）の大型ボタン開口部 ---
        // リセス（深さ front_recess_depth = 3.0mm）の奥壁から開口
        translate([center_x, front_recess_depth + wall_thickness / 2, btn_center_z])
            side_button_cutout();

        // --- 手前側面のアクリル化粧パネル用リセス（段差ポケット: 深さ3.0mm） ---
        translate([center_x, front_recess_depth / 2 - 0.01, btn_center_z])
            front_recess_cutout();

        // --- 右側面（X=最大側）のボリューム調整スリット ---
        // 基板表面高さ (wall_thickness + pcb_standoff_h) に合わせて配置
        translate([case_outer_w - wall_thickness / 2, center_y + vol_offset_y, wall_thickness + pcb_standoff_h - 1.0])
            volume_dial_cutout();

        // --- ボトム底面からのM2ネジ貫通穴 & ネジ頭沈め（ザグリ穴） ---
        translate([center_x, center_y, 0]) {
            for (dx = [-joint_pitch / 2, joint_pitch / 2]) {
                for (dy = [-joint_pitch / 2, joint_pitch / 2]) {
                    // ネジ頭沈め穴 (底面側)
                    translate([dx, dy, -0.1])
                        cylinder(h=joint_screw_head_h + 0.1, d=joint_screw_head_d);
                    // ネジ軸貫通穴
                    translate([dx, dy, -0.1])
                        cylinder(h=bottom_case_h + 0.2, d=joint_screw_pass);
                }
            }
        }
    }

    // --- 内部固定構造 (Union) ---
    translate([center_x, center_y, wall_thickness]) {
        // 1. スピーカー固定ボス (TR-WS-2014B 用 M1.8 取付穴ピッチ 24.7mm / 手前前面側)
        translate([0, spk_pos_y, 0]) {
            translate([-spk_hole_pitch / 2, 0, 0])
                speaker_boss(spk_boss_dia, spk_boss_inner, spk_boss_h);
            translate([spk_hole_pitch / 2, 0, 0])
                speaker_boss(spk_boss_dia, spk_boss_inner, spk_boss_h);
        }

        // 2. 電池ボックス位置決めガイドリブ (高剛性補強リブ・三角バットレス・側壁一体化)
        translate([0, batt_pos_y, 0]) {
            eff_w = batt_width + batt_clearance;

            // --- 奥側ガイドリブ (背面三角バットレスリブ & 根元テーパー付き) ---
            // メインリブ壁 (幅 31.5mm, 肉厚 batt_rib_t = 1.6mm, 高さ 8.0mm)
            translate([-batt_length / 4, eff_w / 2, 0])
                cube([batt_length / 2, batt_rib_t, batt_rib_h]);
            // 根元テーパー補強
            hull() {
                translate([-batt_length / 4, eff_w / 2, 0])
                    cube([batt_length / 2, batt_rib_t + 1.0, 0.01]);
                translate([-batt_length / 4, eff_w / 2, 1.2])
                    cube([batt_length / 2, batt_rib_t, 0.01]);
            }
            // 背面三角バットレスリブ (3箇所: X = 0, ±10mm)
            for (gx = [-10, 0, 10]) {
                translate([gx - batt_gusset_t / 2, eff_w / 2 + batt_rib_t, 0])
                    hull() {
                        cube([batt_gusset_t, 0.01, batt_gusset_h]);
                        cube([batt_gusset_t, batt_gusset_rear_d, 0.01]);
                    }
            }

            // --- 手前側ガイドリブ (左右2箇所: 前面三角バットレスリブ & 根元テーパー付き) ---
            for (tab_x = [-batt_length / 2 + 3, batt_length / 2 - 13]) {
                // ガイドリブ片 (幅 10.0mm, 肉厚 1.6mm, 高さ 8.0mm)
                translate([tab_x, -eff_w / 2 - batt_rib_t, 0])
                    cube([10.0, batt_rib_t, batt_rib_h]);
                // 根元テーパー補強
                hull() {
                    translate([tab_x, -eff_w / 2 - batt_rib_t - 1.0, 0])
                        cube([10.0, batt_rib_t + 1.0, 0.01]);
                    translate([tab_x, -eff_w / 2 - batt_rib_t, 1.2])
                        cube([10.0, batt_rib_t, 0.01]);
                }
            }
            // 手前側三角バットレスリブ (左右各1箇所: スピーカー外側の安全領域)
            for (gx = [-batt_length / 2 + 8, batt_length / 2 - 8]) {
                translate([gx - batt_gusset_t / 2, -eff_w / 2 - batt_rib_t, 0])
                    hull() {
                        cube([batt_gusset_t, 0.01, batt_gusset_h]);
                        translate([0, -batt_gusset_front_d, 0])
                            cube([batt_gusset_t, 0.01, 0.01]);
                    }
            }

            // --- 左右位置決めストッパー (ケース側壁直結・一体成型 & 導入テーパー付き) ---
            stop_len_y = 12.0;
            stop_h     = 6.0;
            step_w     = case_inner_w / 2 - (batt_length + batt_clearance) / 2; // 約 0.6mm 突出

            // 左側側壁一体ストッパー
            translate([-case_inner_w / 2, -stop_len_y / 2, 0])
                hull() {
                    cube([step_w, stop_len_y, stop_h - 1.5]);
                    cube([0.01, stop_len_y, stop_h]);
                }

            // 右側側壁一体ストッパー
            translate([(batt_length + batt_clearance) / 2, -stop_len_y / 2, 0])
                hull() {
                    cube([step_w, stop_len_y, stop_h - 1.5]);
                    translate([step_w - 0.01, 0, 0])
                        cube([0.01, stop_len_y, stop_h]);
                }
        }

        // 3. M2 六角スペーサー受け座パッド (四隅 52x52mm ピッチ、回り止め六角ポケット付き)
        for (dx = [-joint_pitch / 2, joint_pitch / 2]) {
            for (dy = [-joint_pitch / 2, joint_pitch / 2]) {
                translate([dx, dy, 0])
                    spacer_mount_pad(pad_d=6.8, pad_h=spacer_pad_h, hex_w=spacer_hex_w, pocket_d=spacer_pocket_d, pass_d=joint_screw_pass, dir_x=sign(dx), dir_y=sign(dy));
            }
        }

        // 4. 前面ボタン用 マイクロコイルスプリング受け座ボス (左右2箇所)
        boss_rel_y = -(case_inner_h / 2 - front_recess_depth - 3.5 - btn_case_boss_outer_d / 2); // Y ≈ -23.2mm
        boss_z_ctr = (btn_center_z + btn_spring_offset_y) - wall_thickness; // Z ≈ 15.5mm
        boss_h_top = boss_z_ctr + btn_case_boss_outer_d / 2; // Z ≈ 18.2mm
        front_wall_y = -(case_inner_h / 2 - front_recess_depth); // Y ≈ -29.4mm

        for (dx = [-btn_spring_pitch_w / 2, btn_spring_pitch_w / 2]) {
            translate([dx, boss_rel_y, 0]) {
                difference() {
                    union() {
                        // 支持円柱ボス
                        cylinder(h=boss_h_top, d=btn_case_boss_outer_d);
                        // 根元補強テーパー
                        cylinder(h=2.5, d1=btn_case_boss_outer_d + 2.0, d2=btn_case_boss_outer_d);
                        // 前面内壁への一体補強リブ
                        hull() {
                            translate([-rib_thickness / 2, 0, 0])
                                cube([rib_thickness, 0.01, boss_h_top]);
                            translate([-rib_thickness / 2, front_wall_y - boss_rel_y, 0])
                                cube([rib_thickness, 0.01, 2.0]);
                        }
                    }
                    // 手前方向（-Y）に開口するスプリング収容ポケット穴 (φ3.4mm, 深さ2.5mm)
                    translate([0, -btn_case_boss_outer_d / 2 - 0.05, boss_z_ctr])
                        rotate([-90, 0, 0])
                            cylinder(h=btn_case_boss_pocket_d + 0.1, d=btn_spring_pocket_d, $fn=24);
                }
            }
        }
    }
}

// 描画
bottom_case();
