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
        translate([-btn_light_slit_w/2 + btn_light_slit_r, -btn_light_slit_h/2 + btn_light_slit_r, -0.1])
            cylinder(h=btn_flange_t + btn_cap_depth + 0.2, r=btn_light_slit_r);
        translate([btn_light_slit_w/2 - btn_light_slit_r, -btn_light_slit_h/2 + btn_light_slit_r, -0.1])
            cylinder(h=btn_flange_t + btn_cap_depth + 0.2, r=btn_light_slit_r);
        translate([btn_light_slit_w/2 - btn_light_slit_r, btn_light_slit_h/2 - btn_light_slit_r, -0.1])
            cylinder(h=btn_flange_t + btn_cap_depth + 0.2, r=btn_light_slit_r);
        translate([-btn_light_slit_w/2 + btn_light_slit_r, btn_light_slit_h/2 - btn_light_slit_r, -0.1])
            cylinder(h=btn_flange_t + btn_cap_depth + 0.2, r=btn_light_slit_r);
    }
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

// 裏面のタクトスイッチ収容ポケット（EVQPUC02Kとの干渉を完全に逃げるリセス）
module switch_relief_pocket() {
    py = btn_plunger_offset_y; // +1.4mm
    pw = btn_switch_pocket_w;  // 5.6mm
    ph = btn_switch_pocket_h;  // 3.2mm
    pd = btn_switch_pocket_d;  // 1.4mm
    
    translate([-pw / 2, py - ph / 2, -0.1])
        cube([pw, ph, pd + 0.1]);
}

// ポケット内蔵 弾性押下面（カンチレバー板バネ梁機構）
// スイッチ先端(Z=1.4mm)に対してZ=1.2mm位置に押下面を配置し、0.2mmの初期隙間と1.2mmストロークを創出
module internal_flex_actuator() {
    py = btn_plunger_offset_y; // +1.4mm
    pw = 4.0;                  // 押圧パッド幅
    ph = 1.6;                  // 押圧パッド高さ
    pd = btn_switch_pocket_d;  // 1.4mm
    gap = btn_actuator_gap;    // 0.2mm
    actuator_z = pd - gap;     // 1.2mm (Global Y = 3.8mm)

    // ポケット天井からの弾性カンチレバー支持アーム
    translate([-pw / 2, py - ph / 2, actuator_z])
        cube([pw, ph, pd - actuator_z + 0.6]);
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

            // 4. ポケット内蔵 弾性押下面（スイッチ押圧カンチレバー）
            internal_flex_actuator();
        }

        // 5. 裏面のタクトスイッチ収容ポケット（干渉回避）
        // ※内蔵弾性押下面を残すため、ポケット側壁・底面を掘り込み
        difference() {
            switch_relief_pocket();
            internal_flex_actuator();
        }

        // 6. 操作面 左右2箇所の M2 六角ナット接着ポケット（高さ中央）
        for (dx = [-btn_magnet_pitch_w / 2, btn_magnet_pitch_w / 2]) {
            translate([dx, 0, 0])
                nut_pocket();
        }

        // 7. 中央の LED 導光スリット窓（基板上の WS2812B 光をアクリル裏面へ誘導）
        translate([0, 0, 0])
            light_guide_slit();
    }
}

// 描画
front_button();


