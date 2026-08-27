// ==========================================
// ConnectedDoll2 Bottom Case (bottom_case.scad)
// ==========================================

include <params.scad>;

module side_button_cutout() {
    hull() {
        translate([-btn_side_width/2 + btn_side_radius, 0, btn_side_radius])
            rotate([90, 0, 0]) cylinder(h=wall_thickness * 3, r=btn_side_radius, center=true);
        translate([btn_side_width/2 - btn_side_radius, 0, btn_side_radius])
            rotate([90, 0, 0]) cylinder(h=wall_thickness * 3, r=btn_side_radius, center=true);
        translate([btn_side_width/2 - btn_side_radius, 0, btn_side_height - btn_side_radius])
            rotate([90, 0, 0]) cylinder(h=wall_thickness * 3, r=btn_side_radius, center=true);
        translate([-btn_side_width/2 + btn_side_radius, 0, btn_side_height - btn_side_radius])
            rotate([90, 0, 0]) cylinder(h=wall_thickness * 3, r=btn_side_radius, center=true);
    }
}

module screw_pass_boss(outer_d, pass_d, height) {
    difference() {
        cylinder(h=height, d=outer_d);
        translate([0, 0, -0.1])
            cylinder(h=height + 0.2, d=pass_d);
    }
}

module speaker_boss(outer_d, inner_d, height) {
    difference() {
        cylinder(h=height, d=outer_d);
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
        translate([-front_recess_w/2 + front_recess_r, 0, front_recess_r])
            rotate([90, 0, 0]) cylinder(h=front_recess_depth * 2, r=front_recess_r, center=true);
        translate([front_recess_w/2 - front_recess_r, 0, front_recess_r])
            rotate([90, 0, 0]) cylinder(h=front_recess_depth * 2, r=front_recess_r, center=true);
        translate([front_recess_w/2 - front_recess_r, 0, front_recess_h - front_recess_r])
            rotate([90, 0, 0]) cylinder(h=front_recess_depth * 2, r=front_recess_r, center=true);
        translate([-front_recess_w/2 + front_recess_r, 0, front_recess_h - front_recess_r])
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
        translate([center_x, front_recess_depth + wall_thickness / 2, wall_thickness + pcb_standoff_h - btn_side_height / 2 + 1.0])
            side_button_cutout();

        // --- 手前側面のアクリル化粧パネル用リセス（段差ポケット: 深さ3.0mm） ---
        translate([center_x, front_recess_depth / 2 - 0.01, wall_thickness + pcb_standoff_h - front_recess_h / 2 + 1.0])
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

        // 2. 電池ボックス位置決めガイドリブ (横向き配置 / 中央〜奥側)
        translate([0, batt_pos_y, 0]) {
            eff_w = batt_width + batt_clearance;
            // 奥側ガイドリブ
            translate([-batt_length / 4, eff_w / 2, 0])
                cube([batt_length / 2, 1.2, 8.0]);
            // 手前側ガイドリブ
            translate([-batt_length / 4, -eff_w / 2 - 1.2, 0])
                cube([batt_length / 2, 1.2, 8.0]);
            // 左右位置決めストッパー (左右振れ止め)
            translate([-(batt_length + batt_clearance) / 2 - 1.0, -eff_w / 4, 0])
                cube([1.0, eff_w / 2, 5.0]);
            translate([(batt_length + batt_clearance) / 2, -eff_w / 4, 0])
                cube([1.0, eff_w / 2, 5.0]);
        }

        // 3. 統合基板・ケース締結支柱ボス (四隅 52x52mm ピッチ、底面から基板を支えネジを通す)
        for (dx = [-joint_pitch / 2, joint_pitch / 2]) {
            for (dy = [-joint_pitch / 2, joint_pitch / 2]) {
                translate([dx, dy, 0])
                    screw_pass_boss(joint_boss_outer, joint_screw_pass, pcb_standoff_h);
            }
        }
    }
}

// 描画
bottom_case();
