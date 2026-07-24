return (async function() {
  const EPCB_LayerId = {
    TOP: 1,
    BOTTOM: 2
  };
  const EPCB_PrimitivePourFillMethod = {
    SOLID: "solid"
  };

  try {
    const project = await eda.dmt_Project.getCurrentProjectInfo();
    if (!project) {
      return "Error: No project is currently opened.";
    }
    const doc = await eda.dmt_SelectControl.getCurrentDocumentInfo();
    if (!doc || doc.documentType !== 3) {
      return "Error: Please open a PCB document first.";
    }

    // 1. 既存の GND ベタ（Pour）を検索して削除
    // 第1引数に "GND" を指定して GND ネットのベタのみを対象とする
    const allPoursTop = await eda.pcb_PrimitivePour.getAll("GND", EPCB_LayerId.TOP, false);
    if (allPoursTop && allPoursTop.length > 0) {
      await eda.pcb_PrimitivePour.delete(allPoursTop.map(p => p.getState_PrimitiveId()));
    }
    const allPoursBottom = await eda.pcb_PrimitivePour.getAll("GND", EPCB_LayerId.BOTTOM, false);
    if (allPoursBottom && allPoursBottom.length > 0) {
      await eda.pcb_PrimitivePour.delete(allPoursBottom.map(p => p.getState_PrimitiveId()));
    }

    // 2. 基板外形と同じポリライン配列を用いて多角形を作成
    const polyArray = ['R', 0, 2362.2, 2362.2, 2362.2, 0, 78.74];
    const polygonObj = eda.pcb_MathPolygon.createPolygon(polyArray);
    if (!polygonObj) {
      return "Error: Failed to create polygon object for GND pour.";
    }

    // 3. Top層とBottom層に GND ベタを配置
    // create(net, layer, complexPolygon, pourFillMethod, preserveSilos, pourName, pourPriority, lineWidth, primitiveLock)
    await eda.pcb_PrimitivePour.create(
      "GND",
      EPCB_LayerId.TOP,
      polygonObj,
      EPCB_PrimitivePourFillMethod.SOLID,
      true, // preserveSilos (孤立銅箔を保留)
      "GND_TOP",
      0,
      10,
      false
    );

    await eda.pcb_PrimitivePour.create(
      "GND",
      EPCB_LayerId.BOTTOM,
      polygonObj,
      EPCB_PrimitivePourFillMethod.SOLID,
      true, // preserveSilos (孤立銅箔を保留)
      "GND_BOTTOM",
      0,
      10,
      false
    );

    return "Success: Applied GND Copper Pours (Top & Bottom, Solid, Preserve Silos).";
  } catch (err) {
    return "Exception: " + err.message + "\n" + err.stack;
  }
})()
