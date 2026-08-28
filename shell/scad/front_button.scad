// ==========================================
// ConnectedDoll2 Front Button (front_button.scad)
// ==========================================

include <params.scad>;

// ボタン詳細パラメータ
btn_cap_w      = btn_side_width - clearance * 2;   // 43.2mm
btn_cap_h      = btn_side_height - clearance * 2;  // 19.2mm
btn_cap_r      = btn_side_radius - clearance / 2;  // 角丸 R=2.8mm

// 抜け止めツバ（フランジ）は params.scad で定義 (btn_flange_w=47.0mm, btn_flange_h=21.0mm)

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

// 左右のマイクロコイルスプリング収容ポケット (φ3.4mm, 深さ 2.0mm)
module spring_pocket() {
    translate([0, 0, -0.1])
        cylinder(h=btn_spring_pocket_depth + 0.1, d=btn_spring_pocket_d, $fn=24);
}

// M2ネジ式アジャスタブル・プランジャーボス（基板上のタクトスイッチ押下用）
// スイッチ中心高さ Y = +btn_plunger_offset_y (+1.625mm) にM2タッピング下穴ボスを配置し、
// M2なべ小ねじ（L=4〜6mm）をねじ込んで突出量を無段階微調整する
module m2_plunger_boss() {
    py = btn_plunger_offset_y;
    d_out = btn_m2_boss_outer_d;
    h_boss = btn_m2_boss_h;
    // 基板上面（Y=pcb_top_z - btn_center_z = 0.8mm）より下側を逃げるDカット
    pcb_clearance_y = pcb_top_z - btn_center_z; // Y = 0.8mm
    difference() {
        translate([0, py, -h_boss]) {
            // ボス本体（付け根に緩やかなテーパーを設けてPLAの層間せん断強度を向上）
            cylinder(h=h_boss + 0.01, d1=d_out, d2=d_out + 0.8, $fn=32);
        }
        // 基板前端面（FR4エッジ）との干渉を完全に防ぐDカット (PCB上面Z=23.8mmに対し+0.1mm上まで逃げ)
        translate([-d_out, -d_out, -h_boss - 0.1])
            cube([d_out * 2, pcb_clearance_y + d_out + 0.1, h_boss + 0.2]);
    }
}

// M2タッピング用下穴（φ1.7mm, 深さ4.0mm）
module m2_plunger_hole() {
    py = btn_plunger_offset_y;
    d_in = btn_m2_boss_inner_d;
    h_boss = btn_m2_boss_h;
    h_hole = btn_m2_hole_depth;
    translate([0, py, -h_boss - 0.1])
        cylinder(h=h_hole + 0.1, d=d_in, $fn=24);
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

            // 3. M2ネジ式アジャスタブル・プランジャーボス
            m2_plunger_boss();
        }

        // 4. 操作面 左右2箇所の ネオジム磁石埋め込みポケット（高さ中央 Y=0）
        for (dx = [-btn_magnet_pitch_w / 2, btn_magnet_pitch_w / 2]) {
            translate([dx, 0, 0])
                magnet_pocket();
        }

        // 5. 左右2箇所の マイクロコイルスプリング収容ポケット（裏面 Y=btn_spring_offset_y）
        for (dx = [-btn_spring_pitch_w / 2, btn_spring_pitch_w / 2]) {
            translate([dx, btn_spring_offset_y, 0])
                spring_pocket();
        }

        // 6. M2アジャスタブル・プランジャー タッピング下穴
        m2_plunger_hole();
    }
}

// 描画
front_button();


