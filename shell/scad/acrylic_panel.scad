// ==========================================
// ConnectedDoll2 Acrylic Panel (acrylic_panel.scad)
// ==========================================

include <params.scad>;

// 描画モード: "3d" または "2d" (DXF/SVG出力時はコマンドラインから -D mode=\"2d\" で指定)
mode = "3d";

// アクリルパネル寸法
panel_w      = btn_side_width - clearance * 2;   // 43.2mm
panel_h      = btn_side_height - clearance * 2;  // 13.2mm
panel_r      = btn_side_radius - clearance / 2;  // 角丸 R=2.8mm
panel_t      = btn_magnet_t;                     // 3.0mm (アクリル厚み)

nut_radius   = (panel_nut_width / 2) / cos(30);  // M2 六角ナット外接円半径 ($fn=6 で二面幅 4.4mm)

// 2D 外形プロファイル (DXF / SVG レーザー加工用)
module acrylic_panel_2d() {
    difference() {
        // 外形プレート (角丸長方形)
        hull() {
            translate([-panel_w/2 + panel_r, -panel_h/2 + panel_r]) circle(r=panel_r);
            translate([panel_w/2 - panel_r, -panel_h/2 + panel_r])  circle(r=panel_r);
            translate([panel_w/2 - panel_r, panel_h/2 - panel_r])   circle(r=panel_r);
            translate([-panel_w/2 + panel_r, panel_h/2 - panel_r])  circle(r=panel_r);
        }

        // 左右 2 箇所の M2 六角ナット埋め込み穴（高さ中央: 二面幅 4.4mm）
        for (dx = [-btn_magnet_pitch_w/2, btn_magnet_pitch_w/2]) {
            translate([dx, 0])
                rotate([0, 0, 30])
                    circle(r=nut_radius, $fn=6);
        }
    }
}

// 3D モデル (STL / プレビュー用)
module acrylic_panel_3d() {
    linear_extrude(height=panel_t)
        acrylic_panel_2d();
}

// モードに応じた描画
if (mode == "2d") {
    acrylic_panel_2d();
} else {
    acrylic_panel_3d();
}
