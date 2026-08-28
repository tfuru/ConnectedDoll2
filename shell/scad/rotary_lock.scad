// ==========================================
// ConnectedDoll2 Rotary Lock (rotary_lock.scad)
// 電池フタ用 回転ロック（ロータリーラッチ）ダイヤル
// ==========================================

include <params.scad>;

module rotary_lock(angle=0) {
    rotate([0, 0, angle]) {
        difference() {
            // 1. ダイヤル本体（円盤 + 操作リブ + セレーション + リミッターピン）
            union() {
                // (a) メインダイヤル円盤 (φ13.0mm, 厚み rotary_rim_t = 1.6mm)
                cylinder(h=rotary_rim_t, d=rotary_dial_d, $fn=60);

                // (b) 指先操作用 つまみリブ (コイン溝兼用: 高さ0.8mm)
                translate([0, 0, rotary_rim_t]) {
                    hull() {
                        translate([-4.5, -1.0, 0]) cube([9.0, 2.0, 0.01]);
                        translate([-4.0, -0.8, rotary_rib_h]) cube([8.0, 1.6, 0.01]);
                    }
                }

                // (c) ダイヤル外周滑り止めセレーション (微細ローレット)
                for (a = [0 : 30 : 330]) {
                    rotate([0, 0, a])
                        translate([rotary_dial_d / 2 - 0.3, -0.4, 0])
                            cube([0.3, 0.8, rotary_rim_t]);
                }

                // (d) 裏面 90度回転リミッターピン (ケース円弧溝と嵌合し0°〜90°で制動)
                translate([0, 0, -1.0]) {
                    rotate([0, 0, 45])
                        translate([4.5, -0.7, 0])
                            cube([1.2, 1.4, 1.01]);
                }
            }

            // 2. Dカット平坦部 (OPEN位置 90°でフタ端面と完全に干渉しないようカット)
            // LOCK(0°)時は+X側、OPEN(90°)時にフタ側(-Y)を向くよう配置
            cut_r = rotary_dial_d / 2 - rotary_cam_overlap - 0.7; // 中心から 4.0mm
            rotate([0, 0, 90])
                translate([-rotary_dial_d, -rotary_dial_d, -1.5])
                    cube([rotary_dial_d * 2, rotary_dial_d - cut_r, rotary_dial_t + 3.0]);

            // 3. 中心 M2支柱ネジ タッピング下穴 (底面側からの止まり穴: φ1.8mm, 深さ2.0mm)
            translate([0, 0, -1.1])
                cylinder(h=2.2, d=1.8, $fn=24);

            // 4. 状態インジケーター刻印 (施錠側を示す矢印ドット)
            translate([0, -rotary_dial_d / 2 + 1.2, rotary_rim_t - 0.3])
                cylinder(h=0.6, d=1.0, $fn=16);
        }
    }
}

// 単体プレビュー描画 (施錠状態 angle=0)
rotary_lock(0);
