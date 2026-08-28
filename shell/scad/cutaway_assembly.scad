// ==========================================
// ConnectedDoll2 Assembly Cutaway (cutaway_assembly.scad)
// 内部構造・ネジ締結貫通経路の断面視認用
// ==========================================

include <params.scad>;
use <main_assembly.scad>;

// X軸中心およびY軸中心を通る象限カットで内部パーツ・ネジ・電池・スイッチを同時に可視化
difference() {
    main_assembly(explode_z=0, explode_btn=0, explode_screw=0);
    translate([center_x, -10, -20])
        cube([case_outer_w, center_y + 10, 80]);
}
