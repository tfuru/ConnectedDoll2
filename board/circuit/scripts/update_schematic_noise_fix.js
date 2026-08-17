// EasyEDA Pro API: WS2812B ノイズ対策部品（C9, C10, R12）の回路図反映スクリプト
return (async function() {
  try {
    const project = await eda.dmt_Project.getCurrentProjectInfo();
    if (!project) return "Error: No project opened";

    const allComps = await eda.sch_PrimitiveComponent.getAll();
    const existingDes = allComps.map(c => c.getState_Designator());

    const results = [];

    // 1. C9 (47μF 1206 MLCC, C96123) の追加
    if (!existingDes.includes("C9")) {
      const c9 = await eda.sch_PrimitiveComponent.create(
        {
          libraryUuid: "0819f05c4eef4c71ace90d822a990e87",
          uuid: "e2b83b74e6594adc95f5ed0233068d84"
        },
        205,
        65,
        undefined,
        0,
        false,
        true,
        true
      );
      if (c9) {
        const c9Id = c9.getState_PrimitiveId();
        await eda.sch_PrimitiveComponent.modify(c9Id, {
          designator: "C9",
          supplierId: "C96123",
          manufacturer: "SAMSUNG(三星)",
          manufacturerId: "CL31A476MPHNNNE"
        });
        // Pins for C9
        const pins = await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(c9Id);
        // Add wires: Pin 1 -> V_BATT, Pin 2 -> GND
        const p1 = pins.find(p => p.pinNumber === "1") || pins[0];
        const p2 = pins.find(p => p.pinNumber === "2") || pins[1];
        if (p1) {
          await eda.sch_PrimitiveWire.create([p1.x, p1.y, p1.x - 20, p1.y], "V_BATT");
        }
        if (p2) {
          await eda.sch_PrimitiveWire.create([p2.x, p2.y, p2.x + 20, p2.y], "GND");
        }
        results.push("C9 (47uF 1206 MLCC) added at (205, 65)");
      }
    } else {
      results.push("C9 already exists");
    }

    // 2. C10 (10μF 0805 MLCC, C19702) の追加
    if (!existingDes.includes("C10")) {
      const c10 = await eda.sch_PrimitiveComponent.create(
        {
          libraryUuid: "0819f05c4eef4c71ace90d822a990e87",
          uuid: "9f83e90cf78c4f3396a8045b3e521dd5"
        },
        780,
        50,
        undefined,
        0,
        false,
        true,
        true
      );
      if (c10) {
        const c10Id = c10.getState_PrimitiveId();
        await eda.sch_PrimitiveComponent.modify(c10Id, {
          designator: "C10",
          supplierId: "C19702",
          manufacturer: "SAMSUNG(三星)",
          manufacturerId: "CL21A106KOFNNNE"
        });
        const pins = await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(c10Id);
        const p1 = pins.find(p => p.pinNumber === "1") || pins[0];
        const p2 = pins.find(p => p.pinNumber === "2") || pins[1];
        if (p1) {
          await eda.sch_PrimitiveWire.create([p1.x, p1.y, p1.x - 20, p1.y], "V_BATT");
        }
        if (p2) {
          await eda.sch_PrimitiveWire.create([p2.x, p2.y, p2.x + 20, p2.y], "GND");
        }
        results.push("C10 (10uF 0805 MLCC) added at (780, 50)");
      }
    } else {
      results.push("C10 already exists");
    }

    // 3. R12 (10kΩ 0603, C98220 / C25804) の追加
    if (!existingDes.includes("R12")) {
      const r12 = await eda.sch_PrimitiveComponent.create(
        {
          libraryUuid: "0819f05c4eef4c71ace90d822a990e87",
          uuid: "b0602c6e20fc41faa226d9f001a9bead"
        },
        550,
        160,
        undefined,
        0,
        false,
        true,
        true
      );
      if (r12) {
        const r12Id = r12.getState_PrimitiveId();
        await eda.sch_PrimitiveComponent.modify(r12Id, {
          designator: "R12",
          supplierId: "C98220",
          manufacturer: "YAGEO(国巨)",
          manufacturerId: "RC0603FR-0710KL"
        });
        const pins = await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(r12Id);
        const p1 = pins.find(p => p.pinNumber === "1") || pins[0];
        const p2 = pins.find(p => p.pinNumber === "2") || pins[1];
        if (p1) {
          await eda.sch_PrimitiveWire.create([p1.x, p1.y, p1.x - 20, p1.y], "WS_DATA_3V3");
        }
        if (p2) {
          await eda.sch_PrimitiveWire.create([p2.x, p2.y, p2.x + 20, p2.y], "GND");
        }
        results.push("R12 (10k pulldown) added at (550, 160)");
      }
    } else {
      results.push("R12 already exists");
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
