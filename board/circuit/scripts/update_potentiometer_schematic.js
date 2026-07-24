return (async function() {
  try {
    const project = await eda.dmt_Project.getCurrentProjectInfo();
    if (!project) {
      return "Error: No project is currently opened.";
    }
    const doc = await eda.dmt_SelectControl.getCurrentDocumentInfo();
    if (!doc || doc.documentType !== 1) {
      return "Error: Please open the schematic document first.";
    }

    // 1. 回路図上のコンポーネントを取得
    const allComps = await eda.sch_PrimitiveComponent.getAll();
    if (!allComps || allComps.length === 0) {
      return "Error: No components found in schematic.";
    }

    // 2. 旧可変抵抗 (C115341 または C18213432) を検索
    const oldPot = allComps.find(c => 
      c.getState_SupplierId() === "C115341" || 
      c.getState_SupplierId() === "C18213432" || 
      c.getState_ManufacturerId() === "RDC506002A" || 
      c.getState_ManufacturerId() === "R09711NS-FB15S7.0-A103-00G"
    );
    if (!oldPot) {
      return "Error: Old potentiometer not found in schematic.";
    }

    // 配置情報を記録
    const x = oldPot.getState_X();
    const y = oldPot.getState_Y();
    const rotation = oldPot.getState_Rotation();
    const mirror = oldPot.getState_Mirror();
    const oldId = oldPot.getState_PrimitiveId();
    const oldDesignator = oldPot.getState_Designator() || "R11";

    // 3. 重複警告を防ぐため、旧部品のデジグネータを一時的に変更
    await eda.sch_PrimitiveComponent.modify(oldId, { designator: oldDesignator + "_TEMP" });

    // 4. 新しい可変抵抗 (C470766) を同じ位置に作成
    const newComp = await eda.sch_PrimitiveComponent.create(
      {
        libraryUuid: "0819f05c4eef4c71ace90d822a990e87",
        uuid: "f95d5a7adad64263ad8220cf299a2808"
      },
      x,
      y,
      undefined,
      rotation,
      mirror,
      true, // addIntoBom
      true  // addIntoPcb
    );

    if (!newComp) {
      // 失敗した場合はデジグネータを元に戻す
      await eda.sch_PrimitiveComponent.modify(oldId, { designator: oldDesignator });
      return "Error: Failed to create new potentiometer component.";
    }

    // 5. 新部品に元のデジグネータ (R11) および LCSC ID を割り当てる
    const newId = newComp.getState_PrimitiveId();
    await eda.sch_PrimitiveComponent.modify(newId, {
      designator: oldDesignator,
      supplierId: "C470766",
      manufacturer: "ALPSALPINE(阿尔卑斯阿尔派)",
      manufacturerId: "RK10J11R0A0H"
    });

    // 6. 旧部品の削除
    await eda.sch_PrimitiveComponent.delete([oldId]);

    return `Success: Replaced potentiometer ${oldDesignator} with RK10J11R0A0H (C470766) at coordinates (${x}, ${y}).`;
  } catch (err) {
    return "Exception: " + err.message + "\n" + err.stack;
  }
})()
