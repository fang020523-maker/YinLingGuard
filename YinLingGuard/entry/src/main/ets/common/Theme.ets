// 全局设计规范：适老化高对比度大字号 + 家属端常规字号
export class Theme {
  // 色彩
  static readonly COLOR_PRIMARY: string = '#E85D4A';   // 品牌暖红（警示/行动按钮）
  static readonly COLOR_BG: string = '#FFF7F2';        // 暖白背景
  static readonly COLOR_CARD: string = '#FFFFFF';      // 卡片
  static readonly COLOR_TEXT: string = '#2B2118';      // 主文字
  static readonly COLOR_TEXT_SUB: string = '#8A7A6D';  // 次文字
  static readonly COLOR_OK: string = '#3E9B6E';        // 正常/健康
  static readonly COLOR_WARN: string = '#F0A050';      // 等待/注意
  static readonly COLOR_DANGER: string = '#D93A2B';    // 告警
  static readonly COLOR_CHIP: string = '#FDEAE5';      // 快捷标签底色

  // 老人端字号（fp）：约为常规应用 1.5 倍
  static readonly FONT_ELDER_TITLE: number = 34;
  static readonly FONT_ELDER_BODY: number = 24;
  static readonly FONT_ELDER_BTN: number = 30;
  // 家属端字号
  static readonly FONT_FAMILY_TITLE: number = 24;
  static readonly FONT_FAMILY_BODY: number = 18;
}
