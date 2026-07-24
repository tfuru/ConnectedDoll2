return (async function() {
  try {
    const project = await eda.dmt_Project.getCurrentProjectInfo();
    if (!project) {
      return "Error: No project is currently opened.";
    }
    const doc = await eda.dmt_SelectControl.getCurrentDocumentInfo();
    if (!doc || doc.documentType !== 3) {
      return "Error: Please open a PCB document first.";
    }

    // 1. デザインルール設定の取得
    const fullConfig = await eda.pcb_Drc.getCurrentRuleConfiguration();
    if (!fullConfig) {
      return "Error: Failed to get current rule configuration.";
    }

    // 2. デフォルト線幅設定 (信号線用 0.2mm / 最小 0.15mm)
    const trackConfig = fullConfig.config.Physics.Track;
    if (trackConfig.copperThickness1oz && trackConfig.copperThickness1oz.form && trackConfig.copperThickness1oz.form.data) {
      trackConfig.copperThickness1oz.form.data["1"].defaultValue = 0.2;
      trackConfig.copperThickness1oz.form.data["1"].minValue = 0.15;
    }

    // デフォルトルール設定の上書き保存 (注: 引数は fullConfig.config)
    const saveConfigResult = await eda.pcb_Drc.overwriteCurrentRuleConfiguration(fullConfig.config);
    if (!saveConfigResult) {
      return "Error: Failed to overwrite current rule configuration.";
    }

    // 3. ネットごとの個別線幅割り当て (電源: 0.6mm, GND: 0.8mm)
    const netRules = await eda.pcb_Drc.getNetRules();
    if (netRules && netRules.length > 0) {
      const powerNets = ["VCC", "3.3V", "5V", "V_BATT", "VIN_5V", "V3V3", "VBAT_RTC"];
      const gndNets = ["GND"];

      for (const rule of netRules) {
        if (gndNets.includes(rule.name)) {
          rule.Track = "0.8";
        } else if (powerNets.includes(rule.name)) {
          rule.Track = "0.6";
        } else {
          rule.Track = "default";
        }
      }

      const saveNetRulesResult = await eda.pcb_Drc.overwriteNetRules(netRules);
      if (!saveNetRulesResult) {
        return "Error: Failed to overwrite net rules.";
      }
    }

    return "Success: Applied track width rules (Signal: 0.2mm, Power: 0.6mm, GND: 0.8mm).";
  } catch (err) {
    return "Exception: " + err.message + "\n" + err.stack;
  }
})()
