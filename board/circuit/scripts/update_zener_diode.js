// EasyEDA Pro API: ツェナーダイオード (D1) を在庫あり代替品 (BZT52C5V1S / C2118) に置換するスクリプト
return (async function() {
  try {
    const project = await eda.dmt_Project.getCurrentProjectInfo();
    if (!project) return { success: false, error: "No project opened" };

    const allComps = await eda.sch_PrimitiveComponent.getAll();
    const oldD1 = allComps.find(c => c.getState_Designator() === "D1");
    if (!oldD1) return { success: false, error: "D1 not found in schematic" };

    const x = oldD1.getState_X();
    const y = oldD1.getState_Y();
    const rotation = oldD1.getState_Rotation();
    const mirror = oldD1.getState_Mirror();
    const oldId = oldD1.getState_PrimitiveId();

    // 1. デジグネータ競合回避のため一時リネーム
    await eda.sch_PrimitiveComponent.modify(oldId, { designator: "D1_OLD" });

    // 2. 新しいツェナーダイオード (BZT52C5V1S / C2118) を作成
    const newD1 = await eda.sch_PrimitiveComponent.create(
      {
        libraryUuid: "0819f05c4eef4c71ace90d822a990e87",
        uuid: "9d848fff4bde4d108a54913c639a862d"
      },
      x,
      y,
      undefined,
      rotation,
      mirror,
      true,
      true
    );

    if (!newD1) {
      await eda.sch_PrimitiveComponent.modify(oldId, { designator: "D1" });
      return { success: false, error: "Failed to create new Zener diode component" };
    }

    const newId = newD1.getState_PrimitiveId();
    await eda.sch_PrimitiveComponent.modify(newId, {
      designator: "D1",
      supplierId: "C2118",
      manufacturer: "CJ(江苏长电/长晶)",
      manufacturerId: "BZT52C5V1S"
    });

    // 3. 旧部品の削除
    await eda.sch_PrimitiveComponent.delete([oldId]);

    // 4. 保存
    if (eda.dmt_Project.saveCurrentProject) {
      await eda.dmt_Project.saveCurrentProject();
    }

    return {
      success: true,
      message: `D1 successfully replaced with BZT52C5V1S (C2118) at (${x}, ${y})`
    };
  } catch (err) {
    return {
      success: false,
      error: err.message || String(err),
      stack: err.stack
    };
  }
})();
