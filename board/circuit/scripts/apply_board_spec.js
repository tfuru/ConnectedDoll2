return (async function() {
  const EPCB_LayerId = {
    BOARD_OUTLINE: 11,
    MULTI: 12
  };
  const EPCB_PrimitivePadShapeType = {
    ELLIPSE: "ELLIPSE"
  };
  const EPCB_PrimitivePadHoleType = {
    ROUND: "ROUND"
  };
  const EPCB_PrimitivePadType = {
    NORMAL: 0
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

    const allPolylines = await eda.pcb_PrimitivePolyline.getAll("", EPCB_LayerId.BOARD_OUTLINE, false);
    if (allPolylines && allPolylines.length > 0) {
      await eda.pcb_PrimitivePolyline.delete(allPolylines.map(p => p.getState_PrimitiveId()));
    }
    const allLines = await eda.pcb_PrimitiveLine.getAll("", EPCB_LayerId.BOARD_OUTLINE, false);
    if (allLines && allLines.length > 0) {
      await eda.pcb_PrimitiveLine.delete(allLines.map(l => l.getState_PrimitiveId()));
    }

    const allPads = await eda.pcb_PrimitivePad.getAll(EPCB_LayerId.MULTI, "", false);
    if (allPads && allPads.length > 0) {
      const targetPads = allPads.filter(p => {
        const isNonMetal = p.getState_Metallization() === false;
        const holeState = p.getState_Hole();
        const isTargetHole = holeState && (Math.abs(holeState[1] - 126) < 1 || Math.abs(holeState[1] - 86.6) < 1);
        return isNonMetal && isTargetHole;
      });
      if (targetPads.length > 0) {
        await eda.pcb_PrimitivePad.delete(targetPads.map(p => p.getState_PrimitiveId()));
      }
    }

    const polyArray = ['R', 0, 2362.2, 2362.2, 2362.2, 0, 78.74];
    const polygonObj = eda.pcb_MathPolygon.createPolygon(polyArray);
    if (!polygonObj) {
      return "Error: Failed to create board outline polygon object.";
    }
    await eda.pcb_PrimitivePolyline.create("", EPCB_LayerId.BOARD_OUTLINE, polygonObj, 10, false);

    const holeCoords = [
      { x: 157.5, y: 157.5 },
      { x: 2204.7, y: 157.5 },
      { x: 2204.7, y: 2204.7 },
      { x: 157.5, y: 2204.7 }
    ];

    for (const coord of holeCoords) {
      await eda.pcb_PrimitivePad.create(
        EPCB_LayerId.MULTI,
        "",
        coord.x,
        coord.y,
        0,
        [EPCB_PrimitivePadShapeType.ELLIPSE, 86.6, 86.6],
        "",
        [EPCB_PrimitivePadHoleType.ROUND, 86.6],
        0,
        0,
        0,
        false,
        EPCB_PrimitivePadType.NORMAL
      );
    }

    return "Success: Applied Board Outline (60x60mm, R=2mm) and 4x M2 Mounting Holes.";
  } catch (err) {
    return "Exception: " + err.message + "\n" + err.stack;
  }
})()
