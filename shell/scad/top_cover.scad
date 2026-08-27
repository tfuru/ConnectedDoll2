// ==========================================
// ConnectedDoll2 Top Cover (top_cover.scad)
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

module screw_tap_boss(outer_d, tap_d, height, dir_x=0, dir_y=0) {
    difference() {
        union() {
            // メインボス円筒
            cylinder(h=height, d=outer_d);
            // 天板根元テーパーベース
            cylinder(h=min(height, 3.0), d1=outer_d + 2.5, d2=outer_d);
            
            // 外壁接続補強リブ
            if (dir_x != 0 && dir_y != 0) {
                dx_wall = dir_x * (case_inner_w / 2 - joint_pitch / 2 + 0.1);
                dy_wall = dir_y * (case_inner_h / 2 - joint_pitch / 2 + 0.1);
                
                // X方向外壁への補強リブ
                hull() {
                    translate([0, -rib_thickness/2, 0]) cube([0.01, rib_thickness, height]);
                    translate([dx_wall, -rib_thickness/2, 0]) cube([0.01, rib_thickness, height]);
                }
                // Y方向外壁への補強リブ
                hull() {
                    translate([-rib_thickness/2, 0, 0]) cube([rib_thickness, 0.01, height]);
                    translate([-rib_thickness/2, dy_wall, 0]) cube([rib_thickness, 0.01, height]);
                }
            }
        }
        // タッピング穴
        translate([0, 0, -0.1])
            cylinder(h=height + 0.2, d=tap_d);
    }
}

module top_cover() {
    center_x = case_outer_w / 2;
    center_y = case_outer_h / 2;
    // top_coverローカル座標におけるボタン中心Z
    top_btn_z = bottom_case_h + top_cover_h - btn_center_z;

    difference() {
        union() {
            difference() {
                // --- 外殻シェル（薄型天板カバー） ---
                rounded_cube([case_outer_w, case_outer_h, top_cover_h], corner_radius);

                // --- 内部くり抜き ---
                translate([wall_thickness, wall_thickness, wall_thickness])
                    rounded_cube([case_inner_w, case_inner_h, top_cover_h], max(1, corner_radius - wall_thickness));
            }

            // --- 内部ボス構造 (Union: ボトム底面からのM2ネジを受けるタッピングボス) ---
            translate([center_x, center_y, wall_thickness]) {
                for (dx = [-joint_pitch / 2, joint_pitch / 2]) {
                    for (dy = [-joint_pitch / 2, joint_pitch / 2]) {
                        translate([dx, dy, 0])
                            screw_tap_boss(joint_boss_outer, joint_screw_tap, top_cover_h - wall_thickness, sign(dx), sign(dy));
                    }
                }
            }
        }

        // --- 手前側面（フロント壁: Y=0側）のボタン上部切り欠き ---
        translate([center_x, front_recess_depth + wall_thickness / 2, top_btn_z])
            side_button_cutout();

        // --- 手前側面のアクリル化粧パネル用リセス上部切り欠き ---
        translate([center_x, front_recess_depth / 2 - 0.01, top_btn_z])
            front_recess_cutout();
    }
}

// 描画
top_cover();
