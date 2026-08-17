// EasyEDA Pro API: スピーカー接続用 JST SH 2ピンコネクタ (BM02B-SRSS-TB(LF)(SN) / C160388) を追加するスクリプト
return (async function() {
  try {
    const project = await eda.dmt_Project.getCurrentProjectInfo();
    if (!project) return { success: false, error: "No project opened" };

    const allComps = await eda.sch_PrimitiveComponent.getAll();
    const existingDes = allComps.map(c => c.getState_Designator());

    if (existingDes.includes("CN2")) {
      return { success: true, message: "CN2 already exists in schematic" };
    }

    // 1. JST SH 2ピンコネクタ (BM02B-SRSS-TB(LF)(SN)) を作成
    const cn2 = await eda.sch_PrimitiveComponent.create(
      {
        libraryUuid: "0819f05c4eef4c71ace90d822a990e87",
        uuid: "9f54ca1e50e04fb3b21db15c9513c7ac"
      },
      325,
      510,
      undefined,
      0,
      false,
      true,
      true
    );

    if (!cn2) {
      return { success: false, error: "Failed to create CN2 component" };
    }

    const cn2Id = cn2.getState_PrimitiveId();
    await eda.sch_PrimitiveComponent.modify(cn2Id, {
      designator: "CN2",
      supplierId: "C160388",
      manufacturer: "JST",
      manufacturerId: "BM02B-SRSS-TB(LF)(SN)"
    });

    // 2. ピン情報の取得とワイヤ接続
    const pins = await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(cn2Id);
    
    for (const p of pins) {
      if (p.pinNumber === "1") {
        // SPK_P
        await eda.sch_PrimitiveWire.create([p.x, p.y, p.x - 20, p.y], "SPK_P");
      } else if (p.pinNumber === "2") {
        // SPK_N
        await eda.sch_PrimitiveWire.create([p.x, p.y, p.x - 20, p.y], "SPK_N");
      } else if (p.pinNumber === "3" || p.pinNumber === "4") {
        // Shield tabs -> GND
        await eda.sch_PrimitiveWire.create([p.x, p.y, p.x - 20, p.y], "GND");
      }
    }

    // 3. プロジェクト保存
    if (eda.dmt_Project.saveCurrentProject) {
      await eda.dmt_Project.saveCurrentProject();
    }

    return {
      success: true,
      message: "CN2 (BM02B-SRSS-TB(LF)(SN) / C160388) successfully added at (325, 510) and connected to SPK_P/SPK_N/GND"
    };
  } catch (err) {
    return {
      success: false,
      error: err.message || String(err),
      stack: err.stack
    };
  }
})();
