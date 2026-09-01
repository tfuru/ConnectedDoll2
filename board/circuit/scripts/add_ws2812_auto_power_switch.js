// EasyEDA Pro API: WS2812B 自動電源ON/OFF回路（Q2: AO3401A, Q3: AO3400A, D2: 1N4148WS, C11: 0.1uF, R13: 100k, R14: 100k）の回路図反映スクリプト
return (async function() {
  try {
    const project = await eda.dmt_Project.getCurrentProjectInfo();
    if (!project) return { success: false, error: "Error: No project opened" };

    const allComps = await eda.sch_PrimitiveComponent.getAll();
    const existingDes = allComps.map(c => c.getState_Designator());

    const results = [];

    // 1. D2: 1N4148WS (SOD-323, C2128, UUID: 24f1572ddddb42c2abec3b14b1aeb99f)
    if (!existingDes.includes("D2")) {
      const d2 = await eda.sch_PrimitiveComponent.create(
        { libraryUuid: "0819f05c4eef4c71ace90d822a990e87", uuid: "24f1572ddddb42c2abec3b14b1aeb99f" },
        550, 240, undefined, 0, false, true, true
      );
      if (d2) {
        const id = d2.getState_PrimitiveId();
        await eda.sch_PrimitiveComponent.modify(id, {
          designator: "D2",
          supplierId: "C2128",
          manufacturer: "CJ(江苏长电/长晶)",
          manufacturerId: "1N4148WS"
        });
        results.push("D2 (1N4148WS) added at (550, 240)");
      }
    } else {
      results.push("D2 already exists");
    }

    // 2. Q3: AO3400A N-ch MOSFET (SOT-23, C20917, UUID: 1c95a10b7c4a4095b426799cbca7b1b2)
    if (!existingDes.includes("Q3")) {
      const q3 = await eda.sch_PrimitiveComponent.create(
        { libraryUuid: "0819f05c4eef4c71ace90d822a990e87", uuid: "1c95a10b7c4a4095b426799cbca7b1b2" },
        630, 280, undefined, 0, false, true, true
      );
      if (q3) {
        const id = q3.getState_PrimitiveId();
        await eda.sch_PrimitiveComponent.modify(id, {
          designator: "Q3",
          supplierId: "C20917",
          manufacturer: "AOS",
          manufacturerId: "AO3400A"
        });
        results.push("Q3 (AO3400A N-MOS) added at (630, 280)");
      }
    } else {
      results.push("Q3 already exists");
    }

    // 3. Q2: AO3401A P-ch MOSFET (SOT-23, C15127, UUID: f58385f66b144586baef3753ba84f65d)
    if (!existingDes.includes("Q2")) {
      const q2 = await eda.sch_PrimitiveComponent.create(
        { libraryUuid: "0819f05c4eef4c71ace90d822a990e87", uuid: "f58385f66b144586baef3753ba84f65d" },
        710, 240, undefined, 0, false, true, true
      );
      if (q2) {
        const id = q2.getState_PrimitiveId();
        await eda.sch_PrimitiveComponent.modify(id, {
          designator: "Q2",
          supplierId: "C15127",
          manufacturer: "AOS",
          manufacturerId: "AO3401A"
        });
        results.push("Q2 (AO3401A P-MOS) added at (710, 240)");
      }
    } else {
      results.push("Q2 already exists");
    }

    // 4. C11: 0.1μF MLCC (0603, C14663, UUID: a299e4f29fd2469688f76621c3d59c4d)
    if (!existingDes.includes("C11")) {
      const c11 = await eda.sch_PrimitiveComponent.create(
        { libraryUuid: "0819f05c4eef4c71ace90d822a990e87", uuid: "a299e4f29fd2469688f76621c3d59c4d" },
        570, 320, undefined, 0, false, true, true
      );
      if (c11) {
        const id = c11.getState_PrimitiveId();
        await eda.sch_PrimitiveComponent.modify(id, {
          designator: "C11",
          supplierId: "C14663",
          manufacturer: "SAMSUNG(三星)",
          manufacturerId: "CL10B104KO8NNNC"
        });
        results.push("C11 (0.1uF) added at (570, 320)");
      }
    } else {
      results.push("C11 already exists");
    }

    // 5. R13: 100kΩ (0603, C25803, UUID: c728373c421046ff8f40bf82a79ee519) - Bleed resistor
    if (!existingDes.includes("R13")) {
      const r13 = await eda.sch_PrimitiveComponent.create(
        { libraryUuid: "0819f05c4eef4c71ace90d822a990e87", uuid: "c728373c421046ff8f40bf82a79ee519" },
        590, 320, undefined, 0, false, true, true
      );
      if (r13) {
        const id = r13.getState_PrimitiveId();
        await eda.sch_PrimitiveComponent.modify(id, {
          designator: "R13",
          supplierId: "C25803",
          manufacturer: "UNI-ROYAL(台湾厚声)",
          manufacturerId: "0603WAF1003T5E"
        });
        results.push("R13 (100k bleed) added at (590, 320)");
      }
    } else {
      results.push("R13 already exists");
    }

    // 6. R14: 100kΩ (0603, C25803, UUID: c728373c421046ff8f40bf82a79ee519) - Pullup resistor for P-MOS Gate
    if (!existingDes.includes("R14")) {
      const r14 = await eda.sch_PrimitiveComponent.create(
        { libraryUuid: "0819f05c4eef4c71ace90d822a990e87", uuid: "c728373c421046ff8f40bf82a79ee519" },
        680, 290, undefined, 0, false, true, true
      );
      if (r14) {
        const id = r14.getState_PrimitiveId();
        await eda.sch_PrimitiveComponent.modify(id, {
          designator: "R14",
          supplierId: "C25803",
          manufacturer: "UNI-ROYAL(台湾厚声)",
          manufacturerId: "0603WAF1003T5E"
        });
        results.push("R14 (100k pullup) added at (680, 290)");
      }
    } else {
      results.push("R14 already exists");
    }

    // ネット配線（Wires）
    const updatedComps = await eda.sch_PrimitiveComponent.getAll();
    for (const comp of updatedComps) {
      const des = comp.getState_Designator();
      const id = comp.getState_PrimitiveId();
      const pins = await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(id);

      if (des === "D2") {
        const pA = pins.find(p => p.pinNumber === "1" || p.name === "A") || pins[0];
        const pK = pins.find(p => p.pinNumber === "2" || p.name === "K") || pins[1];
        if (pA) await eda.sch_PrimitiveWire.create([pA.x, pA.y, pA.x - 20, pA.y], "WS_DATA_3V3");
        if (pK) await eda.sch_PrimitiveWire.create([pK.x, pK.y, pK.x + 20, pK.y], "LED_GATE_DRV");
      } else if (des === "Q3") {
        const pG = pins.find(p => p.pinNumber === "1" || p.name === "G") || pins[0];
        const pS = pins.find(p => p.pinNumber === "2" || p.name === "S") || pins[1];
        const pD = pins.find(p => p.pinNumber === "3" || p.name === "D") || pins[2];
        if (pG) await eda.sch_PrimitiveWire.create([pG.x, pG.y, pG.x - 20, pG.y], "LED_GATE_DRV");
        if (pS) await eda.sch_PrimitiveWire.create([pS.x, pS.y, pS.x, pS.y + 20], "GND");
        if (pD) await eda.sch_PrimitiveWire.create([pD.x, pD.y, pD.x, pD.y - 20], "LED_PMOS_GATE");
      } else if (des === "Q2") {
        const pG = pins.find(p => p.pinNumber === "1" || p.name === "G") || pins[0];
        const pS = pins.find(p => p.pinNumber === "2" || p.name === "S") || pins[1];
        const pD = pins.find(p => p.pinNumber === "3" || p.name === "D") || pins[2];
        if (pG) await eda.sch_PrimitiveWire.create([pG.x, pG.y, pG.x - 20, pG.y], "LED_PMOS_GATE");
        if (pS) await eda.sch_PrimitiveWire.create([pS.x, pS.y, pS.x, pS.y - 20], "V_BATT");
        if (pD) await eda.sch_PrimitiveWire.create([pD.x, pD.y, pD.x + 20, pD.y], "V_LED");
      } else if (des === "C11") {
        const p1 = pins[0];
        const p2 = pins[1];
        if (p1) await eda.sch_PrimitiveWire.create([p1.x, p1.y, p1.x, p1.y - 20], "LED_GATE_DRV");
        if (p2) await eda.sch_PrimitiveWire.create([p2.x, p2.y, p2.x, p2.y + 20], "GND");
      } else if (des === "R13") {
        const p1 = pins[0];
        const p2 = pins[1];
        if (p1) await eda.sch_PrimitiveWire.create([p1.x, p1.y, p1.x, p1.y - 20], "LED_GATE_DRV");
        if (p2) await eda.sch_PrimitiveWire.create([p2.x, p2.y, p2.x, p2.y + 20], "GND");
      } else if (des === "R14") {
        const p1 = pins[0];
        const p2 = pins[1];
        if (p1) await eda.sch_PrimitiveWire.create([p1.x, p1.y, p1.x, p1.y - 20], "V_BATT");
        if (p2) await eda.sch_PrimitiveWire.create([p2.x, p2.y, p2.x, p2.y + 20], "LED_PMOS_GATE");
      }
    }

    return {
      success: true,
      results: results
    };
  } catch (err) {
    return {
      success: false,
      error: err.message || String(err),
      stack: err.stack
    };
  }
})();
