// EasyEDA Pro API: タクトスイッチ (SW1) を横向きSMD (EVQPUC02K / C79174) に置換するスクリプト
return (async function() {
  try {
    const project = await eda.dmt_Project.getCurrentProjectInfo();
    if (!project) return { success: false, error: "No project opened" };

    const allComps = await eda.sch_PrimitiveComponent.getAll();
    const oldSw = allComps.find(c => c.getState_Designator() === "SW1");
    if (!oldSw) return { success: false, error: "SW1 not found in schematic" };

    const x = oldSw.getState_X();
    const y = oldSw.getState_Y();
    const rotation = oldSw.getState_Rotation();
    const mirror = oldSw.getState_Mirror();
    const oldId = oldSw.getState_PrimitiveId();

    // 1. デジグネータ競合回避のため一時リネーム
    await eda.sch_PrimitiveComponent.modify(oldId, { designator: "SW1_OLD" });

    // 2. 新しい横向きSMDスイッチ (EVQPUC02K / C79174) を作成
    const newSw = await eda.sch_PrimitiveComponent.create(
      {
        libraryUuid: "0819f05c4eef4c71ace90d822a990e87",
        uuid: "5d9bb2e524e049cb9f8752d9ab99a0af"
      },
      x,
      y,
      undefined,
      rotation,
      mirror,
      true,
      true
    );

    if (!newSw) {
      await eda.sch_PrimitiveComponent.modify(oldId, { designator: "SW1" });
      return { success: false, error: "Failed to create new switch component" };
    }

    const newId = newSw.getState_PrimitiveId();
    await eda.sch_PrimitiveComponent.modify(newId, {
      designator: "SW1",
      supplierId: "C79174",
      manufacturer: "PANASONIC(松下)",
      manufacturerId: "EVQPUC02K"
    });

    // 3. 旧部品の削除
    await eda.sch_PrimitiveComponent.delete([oldId]);

    // 4. 保存
    if (eda.dmt_Project.saveCurrentProject) {
      await eda.dmt_Project.saveCurrentProject();
    }

    return {
      success: true,
      message: `SW1 successfully replaced with EVQPUC02K (C79174) at (${x}, ${y})`
    };
  } catch (err) {
    return {
      success: false,
      error: err.message || String(err),
      stack: err.stack
    };
  }
})();
