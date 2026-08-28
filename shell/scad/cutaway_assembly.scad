// ==========================================
// ConnectedDoll2 Assembly Cutaway (cutaway_assembly.scad)
// 内部構造・ネジ締結貫通経路の断面視認用
// ==========================================

include <params.scad>;
use <main_assembly.scad>;

// ネジ穴中心（X = center_x - joint_pitch / 2 = 8.4mm）を通る断面でカット
difference() {
    main_assembly(explode_z=0, explode_btn=0, explode_screw=0);
    translate([center_x - joint_pitch / 2, -10, -20])
        cube([case_outer_w, case_outer_h + 20, 80]);
}
