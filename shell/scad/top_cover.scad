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



module screw_pass_boss(outer_d, pass_d, height, dir_x=0, dir_y=0) {
    rib_h = min(height, top_cover_h - wall_thickness);
    difference() {
        union() {
            // メインボス円筒
            cylinder(h=height, d=outer_d);
            // 天板根元テーパーベース
            cylinder(h=min(height, 3.0), d1=outer_d + 2.5, d2=outer_d);
            
            // 外壁接続補強リブ (トップカバー内壁深さ rib_h 以内に収容)
            if (dir_x != 0 && dir_y != 0) {
                dx_wall = dir_x * (case_inner_w / 2 - joint_pitch / 2 + 0.1);
                dy_wall = dir_y * (case_inner_h / 2 - joint_pitch / 2 + 0.1);
                
                // X方向外壁への補強リブ
                hull() {
                    translate([0, -rib_thickness/2, 0]) cube([0.01, rib_thickness, rib_h]);
                    translate([dx_wall, -rib_thickness/2, 0]) cube([0.01, rib_thickness, rib_h]);
                }
                // Y方向外壁への補強リブ
                hull() {
                    translate([-rib_thickness/2, 0, 0]) cube([rib_thickness, 0.01, rib_h]);
                    translate([-rib_thickness/2, dy_wall, 0]) cube([rib_thickness, 0.01, rib_h]);
                }
            }
        }
        // ネジ軸貫通穴
        translate([0, 0, -0.1])
            cylinder(h=height + 0.2, d=pass_d);
    }
}

module top_volume_cutout() {
    // 1. 壁貫通スリット (幅 vol_slit_width = 18.0mm, 高さ top_cover_h - vol_slit_top_h から合わせ目天端まで)
    hull() {
        // 上端左右2隅の角丸 (R = vol_slit_radius)
        translate([0, -vol_slit_width/2 + vol_slit_radius, top_cover_h - vol_slit_top_h + vol_slit_radius])
            rotate([0, 90, 0]) cylinder(h=wall_thickness * 4, r=vol_slit_radius, center=true);
        translate([0, vol_slit_width/2 - vol_slit_radius, top_cover_h - vol_slit_top_h + vol_slit_radius])
            rotate([0, 90, 0]) cylinder(h=wall_thickness * 4, r=vol_slit_radius, center=true);
        // トップカバー合わせ目開口端 (Z = top_cover_h) を抜けて開放する直線エッジ (合わせ目での段差防止)
        translate([0, 0, top_cover_h + 0.5])
            cube([wall_thickness * 4, vol_slit_width, 1.0], center=true);
    }

    // 2. 外壁側 45度すり鉢状 指掛かりスカラップ (幅 vol_scallop_w = 24.0mm, 深さ vol_scallop_chamfer = 1.4mm)
    hull() {
        // 外壁面境界 (local X = -0.1, 幅24.0mm, スリット上端から vol_scallop_ext = 1.8mm 上まで展開)
        translate([-0.1, -vol_scallop_w/2 + vol_scallop_r, top_cover_h - (vol_slit_top_h + vol_scallop_ext) + vol_scallop_r])
            rotate([0, 90, 0]) cylinder(h=0.01, r=vol_scallop_r, center=true);
        translate([-0.1, vol_scallop_w/2 - vol_scallop_r, top_cover_h - (vol_slit_top_h + vol_scallop_ext) + vol_scallop_r])
            rotate([0, 90, 0]) cylinder(h=0.01, r=vol_scallop_r, center=true);
        // 合わせ目エッジ (外幅24.0mm)
        translate([-0.1, 0, top_cover_h + 0.5])
            cube([0.01, vol_scallop_w, 1.0], center=true);

        // 内側ザグリ底境界 (local X = +vol_scallop_chamfer = +1.4mm, 幅18.0mm)
        translate([vol_scallop_chamfer, -vol_slit_width/2 + vol_slit_radius, top_cover_h - vol_slit_top_h + vol_slit_radius])
            rotate([0, 90, 0]) cylinder(h=0.01, r=vol_slit_radius, center=true);
        translate([vol_scallop_chamfer, vol_slit_width/2 - vol_slit_radius, top_cover_h - vol_slit_top_h + vol_slit_radius])
            rotate([0, 90, 0]) cylinder(h=0.01, r=vol_slit_radius, center=true);
        // 合わせ目エッジ (内幅18.0mm)
        translate([vol_scallop_chamfer, 0, top_cover_h + 0.5])
            cube([0.01, vol_slit_width, 1.0], center=true);
    }
}

module volume_reinforce_dam_top() {
    yc = center_y + vol_offset_y;
    z_ceiling = wall_thickness - 0.1;
    z_rim = top_cover_h;
    
    // スリット周辺内壁への補強土手（裏打ちフレーム: トップカバー側）
    // ローカル座標で内側(+X方向)へ vol_dam_thick (1.3mm) 突出、総肉厚 3.3mm、スカラップ後純残存肉厚 1.9〜2.0mm 確保
    hull() {
        // 土手最内面 (local X = wall_thickness + vol_dam_thick = 3.3mm)
        translate([wall_thickness + vol_dam_thick - 0.01, yc - vol_scallop_w/2, z_ceiling])
            cube([0.01, vol_scallop_w, z_rim - z_ceiling]);
            
        // 内壁接続面 (local X = wall_thickness - 0.1 = 1.9mm: 45度テーパー裾野)
        translate([wall_thickness - 0.1, yc - (vol_scallop_w/2 + vol_dam_taper_w), z_ceiling])
            cube([0.01, vol_scallop_w + vol_dam_taper_w * 2, z_rim - z_ceiling]);
    }
}

module top_cover() {
    // center_x, center_y は params.scad で定義済み (center_x=34.4, center_y=37.4)
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

            // --- ボリューム調整スリット内側補強土手（裏打ちフレーム） ---
            volume_reinforce_dam_top();

            // --- 内部ボス構造 (Union: 基板上面まで届く支柱ボス) ---
            translate([center_x, center_y, wall_thickness]) {
                for (dx = [-joint_pitch / 2, joint_pitch / 2]) {
                    for (dy = [-joint_pitch / 2, joint_pitch / 2]) {
                        translate([dx, dy, 0])
                            screw_pass_boss(joint_boss_outer, joint_screw_pass, top_joint_boss_h, sign(dx), sign(dy));
                    }
                }
            }
        }

        // --- 天面側からのM2ネジ貫通穴 & ネジ頭沈め（ザグリ穴） ---
        translate([center_x, center_y, 0]) {
            for (dx = [-joint_pitch / 2, joint_pitch / 2]) {
                for (dy = [-joint_pitch / 2, joint_pitch / 2]) {
                    // ネジ頭沈め穴 (天面外側: Z=0 から深さ joint_screw_head_h)
                    translate([dx, dy, -0.1])
                        cylinder(h=joint_screw_head_h + 0.1, d=joint_screw_head_d);
                    // ネジ軸貫通穴 (天面からボス先端まで全通)
                    translate([dx, dy, -0.1])
                        cylinder(h=wall_thickness + top_joint_boss_h + 0.2, d=joint_screw_pass);
                }
            }
        }

        // --- 手前側面（フロント壁: Y=0側）のボタン上部切り欠き ---
        translate([center_x, wall_thickness / 2, top_btn_z])
            side_button_cutout();

        // --- 右側面（X=0側: アセンブリ回転時X=case_outer_w）のボリューム調整スリット上部切り欠き＆45度指掛かりスカラップ ---
        translate([0, center_y + vol_offset_y, 0])
            top_volume_cutout();
    }
}

// 描画
top_cover();
