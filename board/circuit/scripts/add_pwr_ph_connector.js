// EasyEDA Pro API: 電源入力用 JST PH 2ピンコネクタ (B2B-PH-K-S(LF)(SN) / C131337) を追加するスクリプト
return (async function() {
  try {
    const project = await eda.dmt_Project.getCurrentProjectInfo();
    if (!project) return { success: false, error: "No project opened" };

    const allComps = await eda.sch_PrimitiveComponent.getAll();
    const existingDes = allComps.map(c => c.getState_Designator());

    if (existingDes.includes("CN3")) {
      return { success: true, message: "CN3 already exists in schematic" };
    }

    // 1. JST PH 2ピンコネクタ (B2B-PH-K-S(LF)(SN) / C131337) を作成
    const cn3 = await eda.sch_PrimitiveComponent.create(
      {
        libraryUuid: "0819f05c4eef4c71ace90d822a990e87",
        uuid: "30e4e60376dc4414ba151b7f1f4fbd96"
      },
      -10,
      210,
      undefined,
      0,
      false,
      true,
      true
    );

    if (!cn3) {
      return { success: false, error: "Failed to create CN3 component" };
    }

    const cn3Id = cn3.getState_PrimitiveId();
    await eda.sch_PrimitiveComponent.modify(cn3Id, {
      designator: "CN3",
      supplierId: "C131337",
      manufacturer: "JST",
      manufacturerId: "B2B-PH-K-S(LF)(SN)"
    });

    // 2. ピン情報の取得とワイヤ接続
    const pins = await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(cn3Id);
    
    for (const p of pins) {
      if (p.pinNumber === "1") {
        // Pin 1: +5V (VIN_5V)
        await eda.sch_PrimitiveWire.create([p.x, p.y, p.x + 20, p.y], "VIN_5V");
      } else if (p.pinNumber === "2") {
        // Pin 2: GND
        await eda.sch_PrimitiveWire.create([p.x, p.y, p.x + 20, p.y], "GND");
      }
    }

    // 3. プロジェクト保存
    if (eda.dmt_Project.saveCurrentProject) {
      await eda.dmt_Project.saveCurrentProject();
    }

    return {
      success: true,
      message: "CN3 (B2B-PH-K-S(LF)(SN) / C131337) successfully added at (-10, 210) and connected to VIN_5V/GND"
    };
  } catch (err) {
    return {
      success: false,
      error: err.message || String(err),
      stack: err.stack
    };
  }
})();
