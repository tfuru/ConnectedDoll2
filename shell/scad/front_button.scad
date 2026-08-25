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

btn_plunger_w  = 4.0;                              // タクトスイッチ押し込み突起
btn_plunger_h  = 4.0;
btn_plunger_l  = 5.0;                              // プランジャー長さ (5.0mm)

module button_face(w, h, d, r) {
    hull() {
        translate([-w/2 + r, -h/2 + r, 0]) cylinder(h=d, r=r);
        translate([w/2 - r, -h/2 + r, 0])  cylinder(h=d, r=r);
        translate([w/2 - r, h/2 - r, 0])   cylinder(h=d, r=r);
        translate([-w/2 + r, h/2 - r, 0])  cylinder(h=d, r=r);
    }
}

// 表面の M2 六角ナット接着用ポケット (深さ 1.6mm, 二面幅 4.4mm)
module nut_pocket() {
    // $fn=6 の外接半径 = (二面幅 / 2) / cos(30°)
    nut_radius = (btn_nut_width / 2) / cos(30);
    translate([0, 0, btn_flange_t + btn_cap_depth - btn_nut_depth])
        rotate([0, 0, 30])
            cylinder(h=btn_nut_depth + 0.1, r=nut_radius, $fn=6);
}

// ボタン中央の LED 導光スリット（貫通窓）
module light_guide_slit() {
    hull() {
        translate([-btn_light_slit_w/2 + btn_light_slit_r, -btn_light_slit_h/2 + btn_light_slit_r, -btn_plunger_l - 0.1])
            cylinder(h=btn_flange_t + btn_cap_depth + btn_plunger_l + 1.0, r=btn_light_slit_r);
        translate([btn_light_slit_w/2 - btn_light_slit_r, -btn_light_slit_h/2 + btn_light_slit_r, -btn_plunger_l - 0.1])
            cylinder(h=btn_flange_t + btn_cap_depth + btn_plunger_l + 1.0, r=btn_light_slit_r);
        translate([btn_light_slit_w/2 - btn_light_slit_r, btn_light_slit_h/2 - btn_light_slit_r, -btn_plunger_l - 0.1])
            cylinder(h=btn_flange_t + btn_cap_depth + btn_plunger_l + 1.0, r=btn_light_slit_r);
        translate([-btn_light_slit_w/2 + btn_light_slit_r, btn_light_slit_h/2 - btn_light_slit_r, -btn_plunger_l - 0.1])
            cylinder(h=btn_flange_t + btn_cap_depth + btn_plunger_l + 1.0, r=btn_light_slit_r);
    }
}

module front_button() {
    difference() {
        // 3Dプリントしやすいように操作面を上（+Z方向）に向けて配置
        union() {
            // 1. 脱落防止フランジ（最底面: 厚み 1.2mm）
            translate([0, 0, 0])
                button_face(btn_flange_w, btn_flange_h, btn_flange_t, btn_side_radius + 0.5);

            // 2. ボタンキャップ（ズレ・傾き防止ガイド部: 厚み 2.5mm）
            translate([0, 0, btn_flange_t])
                button_face(btn_cap_w, btn_cap_h, btn_cap_depth, btn_cap_r);

            // 3. スイッチ押下プランジャー（フランジ裏面：タクトスイッチEVQPUC02Kを押下）
            // 導光穴の左右または下側にプランジャー突起を配置
            translate([-btn_plunger_w / 2, -btn_cap_h / 2 + 1.0, -btn_plunger_l])
                cube([btn_plunger_w, 2.5, btn_plunger_l]);
        }

        // 4. 操作面 左右2箇所の M2 六角ナット接着ポケット（高さ中央）
        for (dx = [-btn_magnet_pitch_w / 2, btn_magnet_pitch_w / 2]) {
            translate([dx, 0, 0])
                nut_pocket();
        }

        // 5. 中央の LED 導光スリット窓（基板上の WS2812B 光をアクリル裏面へ誘導）
        translate([0, 0, 0])
            light_guide_slit();
    }
}

// 描画
front_button();
