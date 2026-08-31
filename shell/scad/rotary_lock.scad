// ==========================================
// ConnectedDoll2 Rotary Lock (rotary_lock.scad)
// 電池フタ用 回転ロック（ロータリーラッチ）ダイヤル
// 完全沈め込み仕様（底面Z=0より0.2mm奥へ没入し卓上ガタつきゼロ）
// ==========================================

include <params.scad>;

module rotary_lock(angle=0) {
    rotate([0, 0, angle]) {
        difference() {
            // 1. ダイヤル本体（円盤 + 操作リブ + セレーション + リミッターピン）
            union() {
                // (a) メインダイヤル円盤 (φ13.0mm, 厚み rotary_rim_t = 1.4mm, Z = 0〜1.4mm)
                cylinder(h=rotary_rim_t, d=rotary_dial_d, $fn=60);

                // (b) 指先操作用 つまみリブ (コイン溝兼用: Z = -0.8mm〜0mm)
                // 完全にポケット内に沈み込み、外装面Z=0より0.2mm奥に収まる
                // 幅 rotary_rib_w_top = 3.0mm (スロット両側肉厚 0.85mm 以上を確保)
                translate([0, 0, -rotary_rib_h]) {
                    hull() {
                        translate([-4.5, -rotary_rib_w_base/2, 0]) cube([9.0, rotary_rib_w_base, 0.01]);
                        translate([-4.0, -rotary_rib_w_top/2, rotary_rib_h]) cube([8.0, rotary_rib_w_top, 0.01]);
                    }
                }

                // (c) ダイヤル外周滑り止めセレーション (微細ローレット: 幅1.0mm, 突出0.4mmで薄肉化を防止)
                for (a = [0 : 30 : 330]) {
                    rotate([0, 0, a])
                        translate([rotary_dial_d / 2 - 0.4, -0.5, 0])
                            cube([0.4, 1.0, rotary_rim_t]);
                }

                // (d) 裏面 90度回転リミッターピン (ケース円弧溝と嵌合し0°〜90°で制動: 高さ0.9mm)
                translate([0, 0, rotary_rim_t]) {
                    rotate([0, 0, 45])
                        translate([4.5 - 0.5, -0.5, 0])
                            cube([1.0, 1.0, 0.9]);
                }
            }

            // 2. Dカット平坦部 (OPEN位置 90°でフタ端面と完全に干渉しないようカット)
            // LOCK(0°)時は+X側、OPEN(90°)時にフタ側(-Y)を向くよう配置
            cut_r = rotary_dial_d / 2 - rotary_cam_overlap - 0.7; // 中心から 4.0mm
            rotate([0, 0, 90])
                translate([-rotary_dial_d, -rotary_dial_d, -rotary_rib_h - 0.5])
                    cube([rotary_dial_d * 2, rotary_dial_d - cut_r, rotary_dial_t + 2.0]);

            // 3. 中心 M2支柱ネジ 表面頭沈め穴 ＆ 貫通ピボット穴 (外側からの貫通締結仕様)
            // (a) ネジ頭沈めザグリ穴 (φ4.2mm x 深さ1.3mm: なべ頭がリブ内部に完全沈み込み)
            translate([0, 0, -rotary_rib_h - 0.1])
                cylinder(h=rotary_screw_head_h + 0.1, d=rotary_screw_head_d, $fn=32);
            // (b) ネジ軸通過貫通穴 (φ2.3mm: M2ネジ軸の周りをダイヤルがスムーズに空転)
            translate([0, 0, -rotary_rib_h - 0.2])
                cylinder(h=rotary_dial_t + 2.0, d=rotary_pivot_pass_d, $fn=32);

            // 4. 状態インジケーター刻印 (施錠側を示す矢印ドット: リブ先端)
            translate([0, -rotary_dial_d / 2 + 1.2, -rotary_rib_h])
                cylinder(h=0.5, d=1.0, $fn=16);

            // 5. 指先つまみ操作用 コインスロット (左右リブ上面: 幅1.3mm, 深さ0.5mm, 側壁肉厚0.85mm確保)
            translate([-5.0, -rotary_slot_w/2, -rotary_rib_h - 0.1])
                cube([10.0, rotary_slot_w, rotary_slot_d + 0.1]);
        }
    }
}

// 単体プレビュー描画 (施錠状態 angle=0)
rotary_lock(0);
