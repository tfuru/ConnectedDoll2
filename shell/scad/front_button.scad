// ==========================================
// ConnectedDoll2 Front Button (front_button.scad)
// ==========================================

include <params.scad>;

// ボタン詳細パラメータ
btn_cap_w      = btn_side_width - clearance * 2;   // 43.2mm
btn_cap_h      = btn_side_height - clearance * 2;  // 17.2mm
btn_cap_r      = btn_side_radius - clearance / 2;  // 角丸 R=2.8mm

// 抜け止めツバ（フランジ）は params.scad で定義 (btn_flange_w=47.0mm, btn_flange_h=19.2mm)

module button_face(w, h, d, r) {
    hull() {
        translate([-w/2 + r, -h/2 + r, 0]) cylinder(h=d, r=r);
        translate([w/2 - r, -h/2 + r, 0])  cylinder(h=d, r=r);
        translate([w/2 - r, h/2 - r, 0])   cylinder(h=d, r=r);
        translate([-w/2 + r, h/2 - r, 0])  cylinder(h=d, r=r);
    }
}

// 表面の ネオジム磁石埋め込みポケット (深さ 3.0mm, 直径 6.4mm, 導入テーパー付き)
module magnet_pocket() {
    pocket_z = btn_flange_t + btn_cap_depth - btn_magnet_pocket_depth;
    // メインポケット円筒
    translate([0, 0, pocket_z])
        cylinder(h=btn_magnet_pocket_depth + 0.1, d=btn_magnet_pocket_d, $fn=32);
    // 開口部 導入テーパー（バリ・引っかかり解消）
    translate([0, 0, btn_flange_t + btn_cap_depth - btn_magnet_pocket_chamfer])
        cylinder(h=btn_magnet_pocket_chamfer + 0.1, d1=btn_magnet_pocket_d, d2=btn_magnet_pocket_d + btn_magnet_pocket_chamfer * 2, $fn=32);
}

// 左右のマイクロコイルスプリング収容ポケット (φ3.4mm, 深さ 2.0mm)
module spring_pocket() {
    translate([0, 0, -0.1])
        cylinder(h=btn_spring_pocket_depth + 0.1, d=btn_spring_pocket_d, $fn=24);
}

// M2ネジ頭インセット収容ポケット (深さ 1.5mm, φ5.0mm)
// ネジ頭（φ3.5mm x 1.3mm）をボタン内部に沈め込み、突出量を無段階微調整する
module m2_inset_pocket() {
    py = btn_plunger_offset_y;
    translate([0, py, -0.1])
        cylinder(h=btn_inset_pocket_depth + 0.1, d=btn_inset_pocket_d, $fn=32);
}

// M2タッピング用下穴（φ1.7mm, ポケット底面から前方へ深さ 2.0mm）
module m2_plunger_hole() {
    py = btn_plunger_offset_y;
    d_in = btn_m2_boss_inner_d;
    translate([0, py, btn_inset_pocket_depth - 0.1])
        cylinder(h=btn_m2_tap_depth + 0.1, d=d_in, $fn=24);
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
        }

        // 3. 操作面 左右2箇所の ネオジム磁石埋め込みポケット（高さ中央 Y=0）
        for (dx = [-btn_magnet_pitch_w / 2, btn_magnet_pitch_w / 2]) {
            translate([dx, 0, 0])
                magnet_pocket();
        }

        // 4. 左右2箇所の マイクロコイルスプリング収容ポケット（裏面 Y=btn_spring_offset_y）
        for (dx = [-btn_spring_pitch_w / 2, btn_spring_pitch_w / 2]) {
            translate([dx, btn_spring_offset_y, 0])
                spring_pocket();
        }

        // 5. M2ネジ頭インセット収容ポケット（沈め込み深さ 1.5mm）
        m2_inset_pocket();

        // 6. M2アジャスタブル・プランジャー タッピング下穴
        m2_plunger_hole();
    }
}

// 描画
front_button();


