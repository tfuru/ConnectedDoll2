// EasyEDA Pro APIを通じて実行する JavaScript コード
(async () => {
  // 1. 回路図のコンポーネント一覧を取得
  const ids = await eda.sch_PrimitiveComponent.getAllPrimitiveId();
  const components = await eda.sch_PrimitiveComponent.get(ids);
  
  let updatedCount = 0;
  const updates = [];

  for (const c of components) {
    const refDes = c.designator;
    
    // 2. インダクタ L1 の更新
    if (refDes === "L1") {
      await eda.sch_PrimitiveComponent.modify(c.primitiveId, {
        supplierId: "C467130",
        manufacturerId: "SMNR5040-1R5MT"
      });
      updates.push(`L1 -> C467130 (SMNR5040-1R5MT)`);
      updatedCount++;
    }
    
    // 3. 10kΩ抵抗 (R3, R5, R8, R9, R10) の更新
    const targetResistors = ["R3", "R5", "R8", "R9", "R10"];
    if (targetResistors.includes(refDes)) {
      await eda.sch_PrimitiveComponent.modify(c.primitiveId, {
        supplierId: "C98220",
        manufacturerId: "RC0603FR-0710KL"
      });
      updates.push(`${refDes} -> C98220 (RC0603FR-0710KL)`);
      updatedCount++;
    }
  }

  return {
    success: true,
    message: `${updatedCount} 個の回路図コンポーネントを更新しました。`,
    updates: updates
  };
})();
