// ==========================================
// ConnectedDoll2 Bottom Case (bottom_case.scad)
// ==========================================

include <params.scad>;

module side_button_cutout() {
    hull() {
        translate([-btn_side_width/2 + btn_side_radius, 0, -btn_side_height/2 + btn_side_radius])
            rotate([90, 0, 0]) cylinder(h=wall_thickness * 4, r=btn_side_radius, center=true);
        translate([btn_side_width/2 - btn_side_radius, 0, -btn_side_height/2 + btn_side_radius])
            rotate([90, 0, 0]) cylinder(h=wall_thickness * 4, r=btn_side_radius, center=true);
        translate([btn_side_width/2 - btn_side_radius, 0, btn_side_height/2 - btn_side_radius])
            rotate([90, 0, 0]) cylinder(h=wall_thickness * 4, r=btn_side_radius, center=true);
        translate([-btn_side_width/2 + btn_side_radius, 0, btn_side_height/2 - btn_side_radius])
            rotate([90, 0, 0]) cylinder(h=wall_thickness * 4, r=btn_side_radius, center=true);
    }
}

module spacer_mount_pad(pad_d=6.8, pad_h=1.2, hex_w=4.4, pocket_d=1.0, pass_d=2.2, dir_x=0, dir_y=0) {
    difference() {
        union() {
            // スペーサー受け座パッド (φ6.8mm: 六角対辺4.4mmに対し肉厚1.2mmを確保)
            cylinder(h=pad_h, d=pad_d);
            // 根元テーパーベース (φ7.4mm)
            cylinder(h=pad_h, d1=pad_d + 0.6, d2=pad_d);
            // コーナー外壁への小型リブ（底面補強）
            if (dir_x != 0 && dir_y != 0) {
                dx_wall = dir_x * (case_inner_w / 2 - joint_pitch / 2 + 0.1);
                dy_wall = dir_y * (case_inner_h / 2 - joint_pitch / 2 + 0.1);
                hull() {
                    translate([0, -rib_thickness/2, 0]) cube([0.01, rib_thickness, pad_h]);
                    translate([dx_wall, -rib_thickness/2, 0]) cube([0.01, rib_thickness, pad_h]);
                }
                hull() {
                    translate([-rib_thickness/2, 0, 0]) cube([rib_thickness, 0.01, pad_h]);
                    translate([-rib_thickness/2, dy_wall, 0]) cube([rib_thickness, 0.01, pad_h]);
                }
            }
        }
        // 回り止め六角ポケット（六角柱の二面幅 hex_w を収容）
        translate([0, 0, pad_h - pocket_d])
            rotate([0, 0, 30])
                cylinder(h=pocket_d + 0.1, d=hex_w / cos(30), $fn=6);
        
        // M2ネジ貫通穴
        translate([0, 0, -0.1])
            cylinder(h=pad_h + 0.2, d=pass_d);
    }
}

module speaker_boss(outer_d, inner_d, height) {
    difference() {
        union() {
            // ボス円筒
            cylinder(h=height, d=outer_d);
            // 根元テーパー
            cylinder(h=2.5, d1=outer_d + 2.0, d2=outer_d);
            // 前面壁への三角リブ (前面内壁 wall_thickness - center_y に正確に接続)
            dy_front = (wall_thickness - center_y) - spk_pos_y;
            hull() {
                translate([-rib_thickness/2, 0, 0]) cube([rib_thickness, 0.01, height]);
                translate([-rib_thickness/2, dy_front, 0]) cube([rib_thickness, 0.01, 2.0]);
            }
        }
        translate([0, 0, -0.1])
            cylinder(h=height + 0.2, d=inner_d);
    }
}

module button_spring_boss(dir_x=1) {
    front_inner_wall_y = wall_thickness - center_y; // Y ≈ -35.4mm (前面内壁)
    btn_back_y = front_inner_wall_y + btn_flange_t; // Y ≈ -34.2mm (ボタンフランジ裏面)
    boss_rel_y = btn_back_y + 3.5 + btn_case_boss_outer_d / 2; // Y ≈ -28.0mm (ボタン側ポケットに対向)
    boss_z_ctr = (btn_center_z + btn_spring_offset_y) - wall_thickness; // Z ≈ 16.7mm
    boss_h_top = btn_case_boss_top_h; // Z = 20.0mm (基板下面Z=21.4mmに対し1.4mmマージン、穴上部肉厚1.6mm確保)
    front_wall_y = front_inner_wall_y; // -35.4mm

    d_front = btn_case_boss_outer_d;        // 5.4mm (前方円筒径)
    d_rear  = btn_case_boss_rear_d;         // 6.2mm (後方スパイン径: 断面係数3倍)
    rear_offset_y = btn_case_boss_rear_offset; // 2.4mm (柱奥行き8.2mmへ拡張)
    front_block_h = btn_case_boss_front_h;     // 10.5mm (ボタンツバ下端11.7mmに対し1.2mmマージン)

    difference() {
        union() {
            // (1) メインピラー本体 (D型・高剛性スタジアム長円柱: 奥行き8.2mm, 曲げ剛性3倍増)
            hull() {
                cylinder(h=boss_h_top, d=d_front, $fn=32);
                translate([0, rear_offset_y, 0])
                    cylinder(h=boss_h_top, d=d_rear, $fn=32);
            }

            // (2) 根元裾野テーパーベース (Z = 0 〜 3.5mm: 応力集中を完全排除)
            hull() {
                cylinder(h=3.5, d1=d_front + 1.6, d2=d_front, $fn=32);
                translate([0, rear_offset_y, 0])
                    cylinder(h=3.5, d1=d_rear + 1.6, d2=d_rear, $fn=32);
            }

            // (3) 前面壁直結サポートブロック (Z = 0 〜 10.5mm: 前面壁へ強固に一体化)
            // ボタンフランジ下端 (Z=11.7mm) より下側の空間を活用し、片持ち梁長さを実質半減
            hull() {
                translate([-d_front/2, -d_front/2, 0])
                    cube([d_front, 0.01, front_block_h]);
                translate([-d_front/2, front_wall_y - boss_rel_y, 0])
                    cube([d_front, 0.01, front_block_h]);
            }
            // 前面壁直結ブロック上面の45度テーパー移行部
            hull() {
                translate([-d_front/2, -d_front/2, front_block_h])
                    cube([d_front, 0.01, 0.01]);
                translate([-d_front/2, front_wall_y - boss_rel_y, front_block_h])
                    cube([d_front, 0.01, 0.01]);
                translate([-d_front/2, -d_front/2, front_block_h + 1.5])
                    cube([d_front, 0.01, 0.01]);
            }

            // (4) 後方受圧三角ブレース (+Y方向: ボタン押下・バネ圧縮荷重を100%底面へ伝達)
            rear_brace_len = btn_case_boss_rear_brace_l; // 4.5mm
            rear_brace_t = 2.0;
            hull() {
                translate([-rear_brace_t/2, rear_offset_y, 0])
                    cube([rear_brace_t, 0.01, 14.0]);
                translate([-rear_brace_t/2, rear_offset_y + rear_brace_len, 0])
                    cube([rear_brace_t, 0.01, 0.01]);
            }

            // (5) 外側横方向三角ブレース (±X外側方向: コーナー側へ展開し、X軸たわみ・印刷時振動を完全抑制)
            side_brace_len = btn_case_boss_side_brace_l; // 5.5mm
            side_brace_t = 2.0;
            hull() {
                translate([0, -side_brace_t/2, 0])
                    cube([0.01, side_brace_t, 11.0]);
                translate([dir_x * side_brace_len, -side_brace_t/2, 0])
                    cube([0.01, side_brace_t, 0.01]);
            }
        }

        // 手前方向（-Y）に開口するスプリング収容ポケット穴 (φ3.4mm, 深さ2.5mm)
        translate([0, -d_front / 2 - 0.05, boss_z_ctr])
            rotate([-90, 0, 0])
                cylinder(h=btn_case_boss_pocket_d + 0.1, d=btn_spring_pocket_d, $fn=24);
    }
}

module volume_dial_cutout() {
    // 1. 壁貫通スリット (幅 vol_slit_width = 18.0mm, 高さ vol_slit_bottom_z から天端まで)
    hull() {
        // 下端左右2隅の角丸 (R = vol_slit_radius)
        translate([0, -vol_slit_width/2 + vol_slit_radius, vol_slit_bottom_z + vol_slit_radius])
            rotate([0, 90, 0]) cylinder(h=wall_thickness * 4, r=vol_slit_radius, center=true);
        translate([0, vol_slit_width/2 - vol_slit_radius, vol_slit_bottom_z + vol_slit_radius])
            rotate([0, 90, 0]) cylinder(h=wall_thickness * 4, r=vol_slit_radius, center=true);
        // ボトムケース天端 (Z = bottom_case_h) を抜けて開放する直線エッジ (合わせ目での段差防止)
        translate([0, 0, bottom_case_h + 0.5])
            cube([wall_thickness * 4, vol_slit_width, 1.0], center=true);
    }

    // 2. 外壁側 45度すり鉢状 指掛かりスカラップ (幅 vol_scallop_w = 24.0mm, 深さ vol_scallop_chamfer = 1.4mm)
    hull() {
        // 外壁面境界 (X = +0.1, 幅24.0mm, スリット下端から vol_scallop_ext = 1.8mm 下まで展開)
        translate([0.1, -vol_scallop_w/2 + vol_scallop_r, vol_slit_bottom_z - vol_scallop_ext + vol_scallop_r])
            rotate([0, 90, 0]) cylinder(h=0.01, r=vol_scallop_r, center=true);
        translate([0.1, vol_scallop_w/2 - vol_scallop_r, vol_slit_bottom_z - vol_scallop_ext + vol_scallop_r])
            rotate([0, 90, 0]) cylinder(h=0.01, r=vol_scallop_r, center=true);
        // 天端合わせ目エッジ (外幅24.0mm)
        translate([0.1, 0, bottom_case_h + 0.5])
            cube([0.01, vol_scallop_w, 1.0], center=true);

        // 内側ザグリ底境界 (X = -vol_scallop_chamfer = -1.4mm, 幅18.0mm)
        translate([-vol_scallop_chamfer, -vol_slit_width/2 + vol_slit_radius, vol_slit_bottom_z + vol_slit_radius])
            rotate([0, 90, 0]) cylinder(h=0.01, r=vol_slit_radius, center=true);
        translate([-vol_scallop_chamfer, vol_slit_width/2 - vol_slit_radius, vol_slit_bottom_z + vol_slit_radius])
            rotate([0, 90, 0]) cylinder(h=0.01, r=vol_slit_radius, center=true);
        // 天端合わせ目エッジ (内幅18.0mm)
        translate([-vol_scallop_chamfer, 0, bottom_case_h + 0.5])
            cube([0.01, vol_slit_width, 1.0], center=true);
    }
}



module speaker_sound_slits() {
    slit_half_h = spk_slit_h / 2 - spk_slit_r;
    for (i = [0 : spk_slit_count - 1]) {
        dx = (i - (spk_slit_count - 1) / 2) * spk_slit_pitch;
        hull() {
            // 下端半円 (Z = spk_slit_center_z - slit_half_h)
            translate([center_x + dx, -wall_thickness, spk_slit_center_z - slit_half_h])
                rotate([-90, 0, 0])
                    cylinder(h=wall_thickness * 3, r=spk_slit_r, $fn=24);
            // 上端半円 (Z = spk_slit_center_z + slit_half_h)
            translate([center_x + dx, -wall_thickness, spk_slit_center_z + slit_half_h])
                rotate([-90, 0, 0])
                    cylinder(h=wall_thickness * 3, r=spk_slit_r, $fn=24);
        }
    }
}

module volume_reinforce_dam_bottom() {
    yc = center_y + vol_offset_y;
    z_bottom = 21.0;
    z_taper_bottom = 19.5;
    z_top = bottom_case_h;
    
    // スリット周辺内壁への補強土手（裏打ちフレーム）
    // 内側へ vol_dam_thick (1.3mm) 突出、総肉厚 3.3mm、スカラップ後純残存肉厚 1.9〜2.0mm 確保
    hull() {
        // 土手最内面 (X = case_outer_w - wall_thickness - vol_dam_thick = 65.5mm)
        translate([case_outer_w - wall_thickness - vol_dam_thick, yc - vol_scallop_w/2, z_bottom])
            cube([0.01, vol_scallop_w, z_top - z_bottom]);
            
        // 内壁接続面 (X = case_outer_w - wall_thickness + 0.1 = 66.9mm: 45度テーパー裾野)
        translate([case_outer_w - wall_thickness + 0.1, yc - (vol_scallop_w/2 + vol_dam_taper_w), z_taper_bottom])
            cube([0.01, vol_scallop_w + vol_dam_taper_w * 2, z_top - z_taper_bottom]);
    }
}

module bottom_case() {
    // center_x, center_y は params.scad で定義済み (center_x=34.4, center_y=37.4)

    difference() {
        union() {
            difference() {
                // --- 外殻シェル ---
                rounded_cube([case_outer_w, case_outer_h, bottom_case_h], corner_radius);

                // --- 内部くり抜き ---
                translate([wall_thickness, wall_thickness, wall_thickness])
                    rounded_cube([case_inner_w, case_inner_h, bottom_case_h], max(1, corner_radius - wall_thickness));
            }

            // --- ボリューム調整スリット内側補強土手（裏打ちフレーム） ---
            volume_reinforce_dam_bottom();
        }

        // --- 手前側面（フロント壁: Y=0側）の大型ボタン開口部 ---
        translate([center_x, wall_thickness / 2, btn_center_z])
            side_button_cutout();

        // --- 手前側面（フロント壁: Y=0側）のスピーカー出音スリット (7連バーチカルスリット) ---
        speaker_sound_slits();

        // --- 右側面（X=最大側）のボリューム調整スリット (Uノッチ開放形状 & 45度すり鉢状指掛かりスカラップ) ---
        // スリット下端 vol_slit_bottom_z (Z=24.7mm) から天端まで開口、外壁にスカラップ凹みを形成
        translate([case_outer_w, center_y + vol_offset_y, 0])
            volume_dial_cutout();

        // --- ボトム底面からのM2ネジ貫通穴 & ネジ頭沈め（ザグリ穴） ---
        translate([center_x, center_y, 0]) {
            for (dx = [-joint_pitch / 2, joint_pitch / 2]) {
                for (dy = [-joint_pitch / 2, joint_pitch / 2]) {
                    // ネジ頭沈め穴 (底面側)
                    translate([dx, dy, -0.1])
                        cylinder(h=joint_screw_head_h + 0.1, d=joint_screw_head_d);
                    // ネジ軸貫通穴
                    translate([dx, dy, -0.1])
                        cylinder(h=bottom_case_h + 0.2, d=joint_screw_pass);
                }
            }
        }

        // --- 底面 電池ボックス通過用開口 (64x38mm) ---
        translate([center_x - batt_bay_w/2, center_y + batt_pos_y - batt_bay_d/2, -0.1])
            rounded_cube([batt_bay_w, batt_bay_d, wall_thickness + 0.2], 2.0);

        // --- 底面 電池フタ用段差リセス座面 (深さ batt_lid_recess_d = 1.6mm: ツライチ) ---
        recess_w = batt_lid_recess_w;
        recess_d = batt_lid_recess_d;
        translate([center_x - recess_w/2, center_y + batt_pos_y - recess_d/2, -0.1])
            rounded_cube([recess_w, recess_d, batt_lid_recess_depth + 0.1], 2.5);

        // --- 手前側 電池フタアンダーカット差し込みスリット (2箇所: リセス座面裏側 Z=1.6〜3.2mm に配置) ---
        // 底面外側表面(Z=0〜1.6mm)は一切開口せず、ツメをボトム内側で抱え込んで浮き上がりを完全防止
        slot_y_start = center_y + batt_pos_y - recess_d / 2 - (batt_tab_d + 0.4);
        slot_y_len   = (batt_lid_flange + batt_tab_d + 0.9); // 約4.6mm (開口ベイ内壁と確実に貫通連通)
        for (dx = [-batt_tab_pitch / 2, batt_tab_pitch / 2]) {
            translate([center_x + dx - batt_slot_w / 2, slot_y_start, batt_slot_z])
                cube([batt_slot_w, slot_y_len, batt_slot_h]);
        }

        // --- 奥側 回転ロックダイヤル受座ポケット & 支柱貫通穴 ---
        translate([center_x + rotary_pos_x, center_y + rotary_pos_y, 0]) {
            // ダイヤル完全沈め込みポケット (φ14.6mm x 深さ rotary_pocket_d = 2.4mm: ダイヤル全高2.2mmが底面より0.2mm奥に完全没入)
            translate([0, 0, -0.1])
                cylinder(h=rotary_pocket_d + 0.1, d=rotary_pocket_dia, $fn=48);
            // ポケット口元の指掛かり導入面取り (すり鉢状)
            translate([0, 0, -0.1])
                cylinder(h=0.6, d1=rotary_pocket_dia + 1.4, d2=rotary_pocket_dia, $fn=48);
            // M2支柱ネジ タッピング下穴 (外側からねじ込み締結: φ1.7mm, 深さ5.0mm)
            translate([0, 0, rotary_pocket_d - 0.1])
                cylinder(h=rotary_tap_depth + 0.5, d=rotary_tap_hole_d, $fn=24);
            // 90度回転リミッター規制円弧溝 (ポケット天井 Z=2.4mm の上部に配置: 余裕径 d=2.4mm)
            for (a = [0 : 5 : 90]) {
                rotate([0, 0, a + 45])
                    translate([4.5, 0, rotary_pocket_d - 0.1])
                        cylinder(h=1.3, d=2.4, $fn=16);
            }
            // 底面状態インジケーター刻印 (LOCK / OPEN ドット)
            // LOCK位置 (手前側 -Y)
            translate([0, -rotary_pocket_dia / 2 - 1.4, -0.1])
                cylinder(h=0.5, d=1.2, $fn=16);
            // OPEN位置 (時計回り90度 +X)
            translate([rotary_pocket_dia / 2 + 1.4, 0, -0.1])
                cylinder(h=0.5, d=1.2, $fn=16);
        }
    }

    // --- 内部固定構造 (Union) ---
    translate([center_x, center_y, wall_thickness]) {
        // 1. スピーカー固定ボス (TR-WS-2014B 用 M1.8 取付穴ピッチ 24.7mm / 手前前面側)
        translate([0, spk_pos_y, 0]) {
            translate([-spk_hole_pitch / 2, 0, 0])
                speaker_boss(spk_boss_dia, spk_boss_inner, spk_boss_h);
            translate([spk_hole_pitch / 2, 0, 0])
                speaker_boss(spk_boss_dia, spk_boss_inner, spk_boss_h);
        }

        // 2. 回転ロック支柱 補強台座ブロック ＆ 外側M2タッピング受け座ボス
        rear_inner_wall_y = (case_outer_h - wall_thickness) - center_y; // +32.4mm (背面内壁ローカルY)
        pedestal_front_y = batt_pos_y + batt_lid_recess_d / 2; // +22.0mm (フタリセス奥端)
        pedestal_len = rear_inner_wall_y - pedestal_front_y + 0.5; // 背面壁までの接続長

        difference() {
            union() {
                // (a) 背面壁・底面一体の強固な補強台座ブロック (φ14.6mmポケット真上を完全被覆し、中空化を防止)
                translate([-rotary_pedestal_w / 2, pedestal_front_y, 0])
                    cube([rotary_pedestal_w, pedestal_len, rotary_pedestal_h]);
                
                // (b) ボス円筒 (外径φ6.8mm)
                translate([rotary_pos_x, rotary_pos_y, 0])
                    cylinder(h=rotary_pedestal_h, d=6.8, $fn=32);
            }
            // ポケット空間のくり抜き (ポケット天井 Z=2.4mm まで完全に開放し侵入を防止)
            translate([rotary_pos_x, rotary_pos_y, -0.1])
                cylinder(h=rotary_pocket_d - wall_thickness + 0.1, d=rotary_pocket_dia, $fn=48);

            // 外側からのM2タッピング下穴 (貫通逃げ: φ1.7mm, 内側にネジ頭が出ないソリッド設計)
            translate([rotary_pos_x, rotary_pos_y, -0.5])
                cylinder(h=rotary_pedestal_h + 1.0, d=rotary_tap_hole_d, $fn=24);

            // 90度回転リミッター規制円弧溝 (台座ブロック内でもくり抜き、ピン可動空間を完全開放)
            translate([rotary_pos_x, rotary_pos_y, 0]) {
                for (a = [0 : 5 : 90]) {
                    rotate([0, 0, a + 45])
                        translate([4.5, 0, rotary_pocket_d - wall_thickness - 0.1])
                            cylinder(h=1.4, d=2.6, $fn=16);
                }
            }
        }

        // 2b. 電池フタ受け座 補強フレーム ＆ スリット天井高剛性土手 (上面 Z = 3.6mm〜4.8mm)
        // 手前側ツメ受けスリット天井（Z=3.2mm）を Z=4.8mm まで盛り上げ、純残存肉厚1.6mmを確保（こじり折損防止）
        translate([0, batt_pos_y, 0]) {
            difference() {
                union() {
                    // 全周基本フレーム (上面 Z=3.6mm: 内側底面から1.6mm)
                    hull() {
                        translate([-(batt_lid_recess_w + 1.6)/2, -(batt_lid_recess_d + 1.6)/2, 0])
                            rounded_cube([batt_lid_recess_w + 1.6, batt_lid_recess_d + 1.6, 0.01], 3.0);
                        translate([-batt_lid_recess_w/2, -batt_lid_recess_d/2, batt_lid_seat_z - wall_thickness])
                            rounded_cube([batt_lid_recess_w, batt_lid_recess_d, 0.01], 2.5);
                    }
                    // 手前側 スリット天井強化ビーム (上面 Z=4.8mm: 内側底面から2.8mm, 天井肉厚1.6mm確保)
                    hull() {
                        translate([-batt_lid_recess_w/2, -batt_lid_recess_d/2, batt_lid_seat_z - wall_thickness])
                            cube([batt_lid_recess_w, (batt_lid_recess_d - batt_bay_d)/2 + 1.0, 0.01]);
                        translate([-(batt_lid_recess_w - 2.0)/2, -batt_lid_recess_d/2 + 0.5, batt_tab_roof_z - wall_thickness])
                            cube([batt_lid_recess_w - 2.0, (batt_lid_recess_d - batt_bay_d)/2 + 0.2, 0.01]);
                    }
                }
                // 内側くり抜き (開口ベイ 64.0x38.0mm と完全一致し、電池ボックス通過を阻害しない)
                translate([-batt_bay_w/2, -batt_bay_d/2, -0.1])
                    rounded_cube([batt_bay_w, batt_bay_d, batt_tab_roof_z - wall_thickness + 0.2], 2.0);

                // ツメ受けスリットくり抜き (内部フレームからも Z=1.6〜3.2mm を確実に抜き、スリット空間を完全開放)
                for (dx = [-batt_tab_pitch / 2, batt_tab_pitch / 2]) {
                    translate([dx - batt_slot_w / 2, -batt_lid_recess_d / 2 - (batt_tab_d + 0.5), batt_slot_z - wall_thickness - 0.01])
                        cube([batt_slot_w, batt_lid_flange + (batt_tab_d + 0.5) + 1.0, batt_slot_h + 0.02]);
                }

                // ダイヤル沈め込みポケットの逃げ (フレーム奥枠がポケット天井 Z=2.4mm に侵入するのを完全防止)
                translate([rotary_pos_x, rotary_pos_y - batt_pos_y, -0.1])
                    cylinder(h=rotary_pocket_d - wall_thickness + 0.15, d=rotary_pocket_dia + 0.4, $fn=48);
            }
        }

        // 3. 電池ボックス底面挿入ガイド & 上部天井ストッパー (Z = batt_stop_z = 19.2mm)
        translate([0, batt_pos_y, 0]) {
            eff_w = batt_bay_w; // 64.0mm
            eff_d = batt_bay_d; // 38.0mm
            stop_z_rel = batt_stop_z - wall_thickness; // 相対高さ 17.2mm
            rail_len = 20.0; // ガイドレール長さをストッパー全長20mmに拡張
            stop_t = 2.2; // リブ厚み 2.2mm (天面 Z = 21.4mm: ボリュームスリット下端23.5mmより2.1mm下、基板裏面より0.8mm下)
            overhang = 1.6; // 内側への張り出し量 (電池幅63.0mmに対し片側1.1mmのかかり代)

            for (dir = [-1, 1]) {
                // (a) 左右垂直ガイド壁 (開口ベイ端面 ±32.0mm から側壁内へ完全密着、肉厚1.2mm以上確保)
                x_inner = dir * eff_w / 2; // ±32.0mm (開口ベイ端面と完全一致)
                x_outer = dir * (case_inner_w / 2 + 0.8); // ±33.2mm (側壁へ0.8mm埋め込み)
                x_min = min(x_inner, x_outer);
                x_w = abs(x_outer - x_inner); // 1.2mm

                // 垂直ガイド壁本体
                translate([x_min, -rail_len/2, 0])
                    cube([x_w, rail_len, stop_z_rel]);

                // 根元補強 45度三角ブレース (前後 ±Y 方向: 根元の薄肉0.25mmを完全解消、最小肉厚1.2mm以上確保)
                brace_l = 3.0; // ブレース前後長 (3.0mm)
                brace_h = 4.0; // ブレース高さ (4.0mm: 補強フレーム上面Z=1.6mmを完全に超えて強固に一体化)
                // 手前側ブレース (-Y)
                hull() {
                    translate([x_min, -rail_len/2, 0]) cube([x_w, 0.01, brace_h]);
                    translate([x_min, -rail_len/2 - brace_l, 0]) cube([x_w, 0.01, 0.01]);
                }
                // 奥側ブレース (+Y)
                hull() {
                    translate([x_min, rail_len/2 - 0.01, 0]) cube([x_w, 0.01, brace_h]);
                    translate([x_min, rail_len/2 + brace_l, 0]) cube([x_w, 0.01, 0.01]);
                }

                // (b) 左右上部天井ストッパー梁 & 下面45度テーパーブレース (ボリュームスリット非干渉・折損防止)
                sx = (dir > 0) ? (eff_w / 2 - overhang) : (x_min);
                sw = overhang + x_w;
                translate([sx, -rail_len/2, stop_z_rel]) {
                    // ストッパー水平梁 (厚み 2.2mm)
                    cube([sw, rail_len, stop_t]);
                    // 下面 45度テーパーブレース (上向き突き上げ荷重を受け止め、角部応力集中を完全解消)
                    if (dir > 0) {
                        hull() {
                            translate([0, 0, 0]) cube([overhang, rail_len, 0.01]);
                            translate([overhang, 0, -overhang * 1.2]) cube([0.01, rail_len, 0.01]);
                        }
                    } else {
                        hull() {
                            translate([x_w, 0, 0]) cube([overhang, rail_len, 0.01]);
                            translate([x_w, 0, -overhang * 1.2]) cube([0.01, rail_len, 0.01]);
                        }
                    }
                }
            }
        }

        // (c) 背面壁・底面一体型 奥側電池ガイドリブ ＆ 背面直結天井ストッパー (下面ブレース付き)
        rear_guide_front_y = batt_pos_y + batt_bay_d / 2; // +20.5mm (開口ベイ奥端面と同一面)
        rear_guide_len = rear_inner_wall_y - rear_guide_front_y + 0.5; // 約 12.4mm
        stop_z_rel = batt_stop_z - wall_thickness; // 相対高さ 17.2mm
        stop_t = 2.2;

        for (gx = [-batt_rear_guide_pitch / 2, batt_rear_guide_pitch / 2 - batt_rear_guide_t]) {
            // 垂直ガイドリブ（背面内壁および健全な底面に完全接地し、電池奥端を適正クリアランス0.5mmで垂直ガイド）
            translate([gx, rear_guide_front_y, 0])
                cube([batt_rear_guide_t, rear_guide_len, stop_z_rel]);
            // 背面直結型 上部天井ストッパー梁 ＆ 下面45度三角ブレース
            translate([gx, rear_guide_front_y - 2.5, stop_z_rel]) {
                cube([batt_rear_guide_t + 1.0, 2.5 + 4.0, stop_t]);
                // 下面 45度ブレース
                hull() {
                    translate([0, 0, 0]) cube([batt_rear_guide_t + 1.0, 2.5, 0.01]);
                    translate([0, 2.5, -2.5]) cube([batt_rear_guide_t + 1.0, 0.01, 0.01]);
                }
            }
        }

        // 3. M2 六角スペーサー受け座パッド (四隅 52x52mm ピッチ、回り止め六角ポケット付き)
        for (dx = [-joint_pitch / 2, joint_pitch / 2]) {
            for (dy = [-joint_pitch / 2, joint_pitch / 2]) {
                translate([dx, dy, 0])
                    spacer_mount_pad(pad_d=6.8, pad_h=spacer_pad_h, hex_w=spacer_hex_w, pocket_d=spacer_pocket_d, pass_d=joint_screw_pass, dir_x=sign(dx), dir_y=sign(dy));
            }
        }

        // 4. 前面ボタン用 高剛性マイクロコイルスプリング受け座ボス (左右2箇所)
        front_inner_wall_y = wall_thickness - center_y; // Y ≈ -35.4mm (ケース前面内壁のローカルY座標)
        btn_back_y = front_inner_wall_y + btn_flange_t; // Y ≈ -34.2mm (ボタンフランジ裏面のローカルY座標)
        boss_rel_y = btn_back_y + 3.5 + btn_case_boss_outer_d / 2; // Y ≈ -28.0mm (ボタン側ポケットに対向)

        for (dx = [-btn_spring_pitch_w / 2, btn_spring_pitch_w / 2]) {
            translate([dx, boss_rel_y, 0])
                button_spring_boss(sign(dx));
        }
    }
}

// 描画
bottom_case();
