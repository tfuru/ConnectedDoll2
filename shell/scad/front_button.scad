// ==========================================
// ConnectedDoll2 Front Button (front_button.scad)
// ==========================================

include <params.scad>;

// ボタン詳細パラメータ
btn_cap_w      = btn_side_width - clearance * 2;   // 43.2mm
btn_cap_h      = btn_side_height - clearance * 2;  // 13.2mm
btn_cap_r      = btn_side_radius - clearance / 2;  // 角丸 R=2.8mm

btn_flange_w   = btn_side_width + 3.0;             // 47.0mm (抜け止めツバ幅)
btn_flange_h   = btn_side_height + 3.0;            // 17.0mm (抜け止めツバ高)

module button_face(w, h, d, r) {
    hull() {
        translate([-w/2 + r, -h/2 + r, 0]) cylinder(h=d, r=r);
        translate([w/2 - r, -h/2 + r, 0])  cylinder(h=d, r=r);
        translate([w/2 - r, h/2 - r, 0])   cylinder(h=d, r=r);
        translate([-w/2 + r, h/2 - r, 0])  cylinder(h=d, r=r);
    }
}

// 表面の ネオジム磁石埋め込みポケット (深さ 3.0mm, 直径 6.1mm)
module magnet_pocket() {
    translate([0, 0, btn_flange_t + btn_cap_depth - btn_magnet_pocket_depth])
        cylinder(h=btn_magnet_pocket_depth + 0.1, d=btn_magnet_pocket_d, $fn=32);
}

// 左右の復帰板バネ（サイド・スプリングウィング）
// ケース前面内壁に押し当てられ、ボタンのガタつき防止と安定した復帰力を生み出す
module side_return_springs() {
    arm_h = 7.0; // 上下幅
    for (side = [-1, 1]) {
        translate([side * (btn_flange_w / 2 - 0.6), 0, 0]) {
            // フランジ外縁から前方（+Z方向）へ湾曲して伸びる板バネアーム
            hull() {
                translate([0, -arm_h / 2, 0])
                    cube([btn_spring_arm_t, arm_h, btn_flange_t]);
                translate([-side * 1.8, -arm_h / 2, btn_flange_t + btn_spring_reach])
                    cube([btn_spring_arm_t, arm_h, 0.4]);
            }
            // 先端の滑らかな当接パッド（ケース内壁との摺動抵抗を低減）
            translate([-side * 1.8 + btn_spring_arm_t / 2, -arm_h / 2, btn_flange_t + btn_spring_reach])
                cylinder(h=0.5, r=btn_spring_arm_t, $fn=16);
        }
    }
}

module front_button() {
    difference() {
        union() {
            // 1. 脱落防止フランジ（最底面: 厚み 1.2mm）
            translate([0, 0, 0])
                button_face(btn_flange_w, btn_flange_h, btn_flange_t, btn_side_radius + 0.5);

            // 2. ボタンキャップ（ズレ・傾き防止ガイド部: 厚み 2.5mm）
            translate([0, 0, btn_flange_t])
                button_face(btn_cap_w, btn_cap_h, btn_cap_depth, btn_cap_r);

            // 3. 左右の復帰板バネアーム（ケース内壁当接スプリング）
            side_return_springs();
        }

        // 4. 操作面 左右2箇所の ネオジム磁石埋め込みポケット（高さ中央）
        for (dx = [-btn_magnet_pitch_w / 2, btn_magnet_pitch_w / 2]) {
            translate([dx, 0, 0])
                magnet_pocket();
        }
    }
}

// 描画
front_button();


