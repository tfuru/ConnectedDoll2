// ==========================================
// ConnectedDoll2 Top Cover (top_cover.scad)
// ==========================================

include <params.scad>;

// ボトム側の開口は Z = wall_thickness + pcb_standoff_h + 1.0 + btn_side_height/2 = 28.0mm まで達している
// bottom_case_h (26.0mm) からの超過量 = 2.0mm
btn_cutout_overflow = (wall_thickness + pcb_standoff_h - btn_side_height / 2 + 1.0 + btn_side_height) - bottom_case_h; // 約 2.0mm

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

    union() {
        difference() {
            // --- 外殻シェル（薄型天板カバー） ---
            rounded_cube([case_outer_w, case_outer_h, top_cover_h], corner_radius);

            // --- 内部くり抜き ---
            translate([wall_thickness, wall_thickness, wall_thickness])
                rounded_cube([case_inner_w, case_inner_h, top_cover_h], max(1, corner_radius - wall_thickness));
        }

        // --- 手前側エプロン壁（ボトムケースのボタン上部切り欠きを塞ぐ延長壁） ---
        // トップカバーの手前側壁（Y=0〜wall_thickness）から下向き（Z=top_cover_h）に延長して外壁と完全に一体化
        if (btn_cutout_overflow > 0) {
            translate([center_x - (btn_side_width / 2 + 1.0), 0, top_cover_h - 0.05])
                cube([btn_side_width + 2.0, wall_thickness, btn_cutout_overflow + 0.1]);
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
}

// 描画
top_cover();
