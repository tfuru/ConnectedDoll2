// EasyEDA Pro APIを通じて実行する JavaScript コード
(async () => {
  // 1. プロジェクトおよびアクティブドキュメントのステータスチェック
  const project = await eda.dmt_Project.getCurrentProjectInfo();
  if (!project) {
    return { success: false, message: "プロジェクトが開かれていません。" };
  }
  
  const doc = await eda.dmt_SelectControl.getCurrentDocumentInfo();
  if (!doc || doc.documentType !== 3) { // 3: PCB
    return { success: false, message: "アクティブなPCBドキュメントが見つかりません。PCBを開いてください。" };
  }

  // 2. 現在のDRC設計ルール構成の取得
  const config = await eda.pcb_Drc.getCurrentRuleConfiguration();
  if (!config) {
    return { success: false, message: "設計ルールの取得に失敗しました。" };
  }

  // 3. "Power" トラックルールが登録されていなければ新規登録
  // ※ EasyEDA Pro の内部単位は mm (ミリメートル)
  if (!config.config.Physics.Track.copperThickness1oz.form.data["Power"]) {
    config.config.Physics.Track.copperThickness1oz.form.data["Power"] = {
      minValue: 0.5,
      defaultValue: 0.6,
      maxValue: 2.54
    };
    await eda.pcb_Drc.overwriteCurrentRuleConfiguration(config);
  }

  // 4. 主要電源ネットに対して "Power" ルールをマッピング
  const netRules = await eda.pcb_Drc.getNetRules();
  const targetNets = ["VIN_5V", "V_BATT", "V3V3"];
  let updated = false;

  for (const rule of netRules) {
    if (rule.type === "net" && targetNets.includes(rule.name)) {
      rule["Track"] = "Power";
      updated = true;
    }
  }

  // 5. ルールを上書き適用
  if (updated) {
    const success = await eda.pcb_Drc.overwriteNetRules(netRules);
    return {
      success: success,
      message: success ? "1A電源配線ルールを直接適用しました。" : "ルールの適用に失敗しました。"
    };
  }

  return { success: false, message: "対象の電源ネットが見つかりませんでした。" };
})();
