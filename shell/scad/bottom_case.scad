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

module volume_dial_cutout(h_cut=vol_slit_height + 1.0) {
    hull() {
        // 底面左右2隅の角丸 (R = vol_slit_radius)
        translate([0, -vol_slit_width/2 + vol_slit_radius, vol_slit_radius])
            rotate([0, 90, 0]) cylinder(h=wall_thickness * 4, r=vol_slit_radius, center=true);
        translate([0, vol_slit_width/2 - vol_slit_radius, vol_slit_radius])
            rotate([0, 90, 0]) cylinder(h=wall_thickness * 4, r=vol_slit_radius, center=true);
        // 上端（ボトムケース天端を抜けて開放する直線エッジ）
        translate([-wall_thickness * 2, -vol_slit_width/2, h_cut])
            cube([wall_thickness * 4, vol_slit_width, 0.01]);
    }
}

module front_recess_cutout() {
    hull() {
        translate([-front_recess_w/2 + front_recess_r, 0, -front_recess_h/2 + front_recess_r])
            rotate([90, 0, 0]) cylinder(h=front_recess_depth * 2, r=front_recess_r, center=true);
        translate([front_recess_w/2 - front_recess_r, 0, -front_recess_h/2 + front_recess_r])
            rotate([90, 0, 0]) cylinder(h=front_recess_depth * 2, r=front_recess_r, center=true);
        translate([front_recess_w/2 - front_recess_r, 0, front_recess_h/2 - front_recess_r])
            rotate([90, 0, 0]) cylinder(h=front_recess_depth * 2, r=front_recess_r, center=true);
        translate([-front_recess_w/2 + front_recess_r, 0, front_recess_h/2 - front_recess_r])
            rotate([90, 0, 0]) cylinder(h=front_recess_depth * 2, r=front_recess_r, center=true);
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

module bottom_case() {
    // center_x, center_y は params.scad で定義済み (center_x=34.4, center_y=37.4)

    difference() {
        // --- 外殻シェル ---
        rounded_cube([case_outer_w, case_outer_h, bottom_case_h], corner_radius);

        // --- 内部くり抜き ---
        translate([wall_thickness, wall_thickness, wall_thickness])
            rounded_cube([case_inner_w, case_inner_h, bottom_case_h], max(1, corner_radius - wall_thickness));

        // --- 手前側面（フロント壁: Y=0側）の大型ボタン開口部 ---
        // リセス（深さ front_recess_depth = 3.0mm）の奥壁から開口
        translate([center_x, front_recess_depth + wall_thickness / 2, btn_center_z])
            side_button_cutout();

        // --- 手前側面のアクリル化粧パネル用リセス（段差ポケット: 深さ3.0mm） ---
        translate([center_x, front_recess_depth / 2 - 0.01, btn_center_z])
            front_recess_cutout();

        // --- 手前側面（フロント壁: Y=0側）のスピーカー出音スリット (7連バーチカルスリット) ---
        speaker_sound_slits();

        // --- 右側面（X=最大側）のボリューム調整スリット (Uノッチ開放形状) ---
        // スリット下端 vol_slit_bottom_z (Z=23.5mm) から天端まで開口
        translate([case_outer_w - wall_thickness / 2, center_y + vol_offset_y, vol_slit_bottom_z])
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

        // --- 手前側 電池フタ差し込みツメ受けスリット (2箇所) ---
        for (dx = [-batt_tab_pitch / 2, batt_tab_pitch / 2]) {
            translate([center_x + dx - (batt_tab_w + 1.0) / 2, center_y + batt_pos_y - recess_d / 2 - batt_tab_d - 0.2, -0.1])
                cube([batt_tab_w + 1.0, batt_tab_d + 0.5, batt_tab_t + 0.4]);
        }

        // --- 奥側 回転ロックダイヤル受座ポケット & 支柱貫通穴 ---
        translate([center_x + rotary_pos_x, center_y + rotary_pos_y, 0]) {
            // ダイヤル完全沈め込みポケット (φ14.6mm x 深さ rotary_pocket_d = 2.4mm: ダイヤル全高2.2mmが底面より0.2mm奥に完全没入)
            translate([0, 0, -0.1])
                cylinder(h=rotary_pocket_d + 0.1, d=rotary_pocket_dia, $fn=48);
            // ポケット口元の指掛かり導入面取り (すり鉢状)
            translate([0, 0, -0.1])
                cylinder(h=0.6, d1=rotary_pocket_dia + 1.4, d2=rotary_pocket_dia, $fn=48);
            // M2支柱ネジ通過穴
            translate([0, 0, -0.1])
                cylinder(h=bottom_case_h, d=rotary_pivot_dia, $fn=24);
            // 90度回転リミッター規制円弧溝 (ポケット天井 Z=2.4mm の上部に配置)
            for (a = [0 : 10 : 90]) {
                rotate([0, 0, a + 45])
                    translate([4.5, 0, rotary_pocket_d - 0.1])
                        cylinder(h=1.2, d=1.8, $fn=16);
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

        // 2. 回転ロック支柱 補強台座ブロック ＆ 内側M2ネジ頭受け座ボス
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
            // 内側M2ネジ頭沈め (Z=1.8mm〜上部へ沈め込み)
            translate([rotary_pos_x, rotary_pos_y, 1.8])
                cylinder(h=5.0, d=rotary_pivot_head_d, $fn=24);
            // M2ネジ貫通穴
            translate([rotary_pos_x, rotary_pos_y, -0.5])
                cylinder(h=6.0, d=rotary_pivot_dia, $fn=24);
        }

        // 3. 電池ボックス底面挿入ガイド & 上部天井ストッパー (Z = batt_stop_z = 19.2mm)
        translate([0, batt_pos_y, 0]) {
            eff_w = batt_bay_w;
            eff_d = batt_bay_d;
            stop_z_rel = batt_stop_z - wall_thickness; // 相対高さ 17.2mm
            rail_len = 20.0; // ガイドレール長さをストッパー全長20mmに拡張
            rail_thick = case_inner_w / 2 - eff_w / 2 + 0.7; // 1.1mm (ケース側壁に0.5mm埋め込み)
            stop_t = 2.2; // リブ厚み 2.2mm (天面 Z = 21.4mm: ボリュームスリット下端23.5mmより2.1mm下、基板裏面より0.8mm下)
            overhang = 1.6; // 内側への張り出し量 (電池幅63.0mmに対し片側1.1mmのかかり代)

            for (dir = [-1, 1]) {
                // (a) 左右垂直ガイド壁 (底面から直立、全長20mmで真下からストッパーを100%全面支持)
                x_base = (dir > 0) ? (eff_w / 2 - 0.2) : (-case_inner_w / 2 - 0.5);
                translate([x_base, -rail_len/2, 0])
                    cube([rail_thick, rail_len, stop_z_rel]);

                // (b) 左右上部天井ストッパー梁 & 下面45度テーパーブレース (ボリュームスリット非干渉・折損防止)
                sx = (dir > 0) ? (eff_w / 2 - overhang) : (-eff_w / 2 - rail_thick);
                translate([sx, -rail_len/2, stop_z_rel]) {
                    // ストッパー水平梁 (厚み 2.2mm: スリット下端23.5mmより遥か下のZ=21.4mmで完結)
                    cube([overhang + rail_thick, rail_len, stop_t]);
                    // 下面 45度テーパーブレース (上向き突き上げ荷重を受け止め、角部応力集中を完全解消)
                    if (dir > 0) {
                        hull() {
                            translate([0, 0, 0]) cube([overhang, rail_len, 0.01]);
                            translate([overhang, 0, -overhang * 1.2]) cube([0.01, rail_len, 0.01]);
                        }
                    } else {
                        hull() {
                            translate([overhang, 0, 0]) cube([overhang, rail_len, 0.01]);
                            translate([0, 0, -overhang * 1.2]) cube([0.01, rail_len, 0.01]);
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

        // 4. 前面ボタン用 マイクロコイルスプリング受け座ボス (左右2箇所)
        front_inner_wall_y = wall_thickness - center_y; // Y ≈ -35.4mm (ケース前面内壁のローカルY座標)
        btn_back_y = front_inner_wall_y + btn_flange_t; // Y ≈ -34.2mm (ボタンフランジ裏面のローカルY座標)
        boss_rel_y = btn_back_y + 3.5 + btn_case_boss_outer_d / 2; // Y ≈ -28.0mm (ボタン側ポケットに対向)
        boss_z_ctr = (btn_center_z + btn_spring_offset_y) - wall_thickness; // Z ≈ 15.5mm
        boss_h_top = boss_z_ctr + btn_case_boss_outer_d / 2; // Z ≈ 18.2mm
        front_wall_y = front_inner_wall_y; // リブを接続する前面内壁座標

        for (dx = [-btn_spring_pitch_w / 2, btn_spring_pitch_w / 2]) {
            translate([dx, boss_rel_y, 0]) {
                difference() {
                    union() {
                        // 支持円柱ボス
                        cylinder(h=boss_h_top, d=btn_case_boss_outer_d);
                        // 根元補強テーパー
                        cylinder(h=2.5, d1=btn_case_boss_outer_d + 2.0, d2=btn_case_boss_outer_d);
                        // 前面内壁への一体補強リブ
                        hull() {
                            translate([-rib_thickness / 2, 0, 0])
                                cube([rib_thickness, 0.01, boss_h_top]);
                            translate([-rib_thickness / 2, front_wall_y - boss_rel_y, 0])
                                cube([rib_thickness, 0.01, 2.0]);
                        }
                    }
                    // 手前方向（-Y）に開口するスプリング収容ポケット穴 (φ3.4mm, 深さ2.5mm)
                    translate([0, -btn_case_boss_outer_d / 2 - 0.05, boss_z_ctr])
                        rotate([-90, 0, 0])
                            cylinder(h=btn_case_boss_pocket_d + 0.1, d=btn_spring_pocket_d, $fn=24);
                }
            }
        }
    }
}

// 描画
bottom_case();
