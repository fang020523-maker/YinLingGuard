// 领域数据模型：老人端与家属端共享

export type Role = 'elder' | 'family';

export type AlertType = 'fall' | 'sos' | 'med';

/** waiting=倒计时确认中 escalated=已升级通知家属 resolved=已处理 */
export type AlertStatus = 'waiting' | 'escalated' | 'resolved';

export interface AlertEvent {
  id: string;
  type: AlertType;
  status: AlertStatus;
  timestamp: number;   // 毫秒时间戳
  detail: string;      // 事件描述（含判定依据）
  responseSec: number; // 老人响应耗时（秒），-1 表示未响应/家属处理
}

export interface MedicationPlan {
  name: string;
  time: string;        // HH:mm
  taken: boolean;
  note: string;        // 服用备注，如"早餐后服用"
}

export interface ChatMessage {
  role: string;        // 'user' | 'assistant'
  content: string;
  sources: string[];   // 引用的知识库条目标题（答案可溯源）
}
