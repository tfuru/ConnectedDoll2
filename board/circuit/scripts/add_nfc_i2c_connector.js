// EasyEDA Pro API: NFC I2C 接続用 2.0mm 1x4P DIP ピンヘッダ (CN4: HC-PZ200-8.7L-1x4PZ / C27985153)
// および電源デカップリングコンデンサ (C12: CL10B104KO8NNNC / C14663 / 0.1uF) を追加するスクリプト
return (async function() {
  try {
    const project = await eda.dmt_Project.getCurrentProjectInfo();
    if (!project) return { success: false, error: "No project opened" };

    const doc = await eda.dmt_SelectControl.getCurrentDocumentInfo();
    if (!doc || doc.documentType !== 1) {
      return { success: false, error: "Active document is not a schematic (documentType !== 1)" };
    }

    const LIB_UUID = "0819f05c4eef4c71ace90d822a990e87";
    const CN4_UUID = "c46c18efdb6e48288fca43947ef672cf"; // C27985153: HC-PZ200-8.7L-1x4PZ (2.0mm 1x4P DIP)
    const C12_UUID = "a299e4f29fd2469688f76621c3d59c4d"; // C14663: CL10B104KO8NNNC (0.1uF 0603)

    const allComps = await eda.sch_PrimitiveComponent.getAll();
    const existingDes = allComps.map(c => c.getState_Designator());
    const results = { added: [], skipped: [], wires: [] };

    const addOutwardStub = async (pin, cx, cy, netName, stubLen) => {
      const dx = pin.x - cx;
      const dy = pin.y - cy;
      let tx = pin.x;
      let ty = pin.y;
      if (Math.abs(dx) >= Math.abs(dy)) {
        tx = pin.x + (dx >= 0 ? stubLen : -stubLen);
      } else {
        ty = pin.y + (dy >= 0 ? stubLen : -stubLen);
      }
      await eda.sch_PrimitiveWire.create([pin.x, pin.y, tx, ty], netName);
      results.wires.push({ pin: pin.pinNumber, from: [pin.x, pin.y], to: [tx, ty], net: netName });
    };

    // 1. CN4 (2.0mm 1x4P DIP ピンヘッダ) を RTC ブロック直下の空き領域 (540, 560) へ配置
    if (existingDes.includes("CN4")) {
      results.skipped.push("CN4");
    } else {
      const cn4X = 540;
      const cn4Y = 560;
      const cn4 = await eda.sch_PrimitiveComponent.create(
        { libraryUuid: LIB_UUID, uuid: CN4_UUID },
        cn4X,
        cn4Y,
        undefined,
        0,
        false,
        true,
        true
      );
      if (!cn4) return { success: false, error: "Failed to create CN4 component" };

      const cn4Id = cn4.getState_PrimitiveId();
      await eda.sch_PrimitiveComponent.modify(cn4Id, {
        designator: "CN4",
        supplierId: "C27985153",
        manufacturer: "HC",
        manufacturerId: "HC-PZ200-8.7L-1x4PZ"
      });

      const cn4Pins = await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(cn4Id);
      const pinNetMap = {
        "1": "GND",
        "2": "V_BATT",
        "3": "I2C_SDA",
        "4": "I2C_SCL"
      };
      for (const p of cn4Pins) {
        const net = pinNetMap[String(p.pinNumber)];
        if (net) {
          await addOutwardStub(p, cn4X, cn4Y, net, 25);
        }
      }
      results.added.push({ designator: "CN4", id: cn4Id, x: cn4X, y: cn4Y, pinCount: cn4Pins.length });
    }

    // 2. C12 (0.1uF デカップリングコンデンサ) を CN4 右隣 (660, 560) へ配置 (C7/R6/R7/B1 と X=660 揃え・水平 rot=0)
    if (existingDes.includes("C12")) {
      results.skipped.push("C12");
    } else {
      const c12X = 660;
      const c12Y = 560;
      const c12 = await eda.sch_PrimitiveComponent.create(
        { libraryUuid: LIB_UUID, uuid: C12_UUID },
        c12X,
        c12Y,
        undefined,
        0,
        false,
        true,
        true
      );
      if (!c12) return { success: false, error: "Failed to create C12 component" };

      const c12Id = c12.getState_PrimitiveId();
      await eda.sch_PrimitiveComponent.modify(c12Id, {
        designator: "C12",
        supplierId: "C14663"
      });

      const c12Pins = await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(c12Id);
      for (const p of c12Pins) {
        if (String(p.pinNumber) === "1") {
          await addOutwardStub(p, c12X, c12Y, "V_BATT", 25);
        } else if (String(p.pinNumber) === "2") {
          await addOutwardStub(p, c12X, c12Y, "GND", 25);
        }
      }
      results.added.push({ designator: "C12", id: c12Id, x: c12X, y: c12Y, pinCount: c12Pins.length });
    }

    // 3. プロジェクト保存
    if (eda.dmt_Project.saveCurrentProject) {
      await eda.dmt_Project.saveCurrentProject();
    }

    return { success: true, results };
  } catch (err) {
    return {
      success: false,
      error: err.message || String(err),
      stack: err.stack
    };
  }
})();
