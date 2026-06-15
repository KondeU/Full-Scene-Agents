/**
 * Design tokens —— 来自 chat-ux Docs/01-ui-design-spec.md §2（oklch → 近似 HEX）。
 */
export class FlowColors {
  static readonly AGENT_BLUE: string = '#2563EB';
  static readonly AGENT_BLUE_LIGHT: string = '#DBEAFE'; // 阶段徽章背景
  static readonly AGENT_BLUE_MUTED: string = '#EFF4FF'; // 选中选项背景
  static readonly AGENT_BLUE_FG: string = '#1E3FA8'; // 徽章文字
  static readonly STEP_DONE: string = '#16A34A';
  static readonly STEP_ERROR: string = '#DC2626';
  static readonly BACKGROUND: string = '#F7F8FA';
  static readonly CARD: string = '#FFFFFF';
  static readonly BORDER: string = '#E2E5EA';
  static readonly BORDER_SOFT: string = '#EDEFF3';
  static readonly FOREGROUND: string = '#14181C';
  static readonly MUTED: string = '#EFF2F5';
  static readonly MUTED_FG: string = '#6B7280';
  static readonly TEAL_BG: string = '#E2F1F2'; // 个性化任务 / 技能创建徽章背景
  static readonly TEAL_FG: string = '#1E6E73';
  static readonly SUMMARY_BG: string = '#E9F7EE'; // 执行汇总绿色头部
  static readonly SUMMARY_FG: string = '#2E7D46';
  static readonly TERMINAL_BG: string = '#1E2530';
  static readonly TERMINAL_FG: string = '#D6DCE5';
}
