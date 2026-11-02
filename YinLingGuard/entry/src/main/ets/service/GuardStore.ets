import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AlertEvent, AlertType, MedicationPlan, Role } from '../model/Models';
import { AlertDb } from './AlertDb';
import { DistributedSync, HealthPayload } from './DistributedSync';
import { NotifyService } from './NotifyService';

const PREF_NAME = 'yl_guard_pref';
const KEY_ROLE = 'yl_role';
const KEY_MEDS = 'yl_meds_json';
const CARD_PREF_NAME = 'yl_card_pref';
const KEY_CARD_STATUS = 'card_status';
const KEY_CARD_GUARDING = 'card_guarding';

/**
 * 全局守护状态仓：单例。
 * 标量状态（心率/步数/守护开关/告警版本号）写入 AppStorage 供页面 @StorageProp 响应式订阅；
 * 对象列表（告警/用药）以页面快照方式读取，由版本号驱动刷新；
 * 告警走 RelationalStore 持久化（重启可恢复），用药与桌面卡片摘要走 Preferences。
 */
export class GuardStore {
  private static instance?: GuardStore;

  static getInstance(): GuardStore {
    if (!GuardStore.instance) {
      GuardStore.instance = new GuardStore();
    }
    return GuardStore.instance;
  }

  role: Role = 'elder';
  alerts: AlertEvent[] = [];
  meds: MedicationPlan[] = [
    { name: '苯磺酸氨氯地平（降压）', time: '08:00', taken: true, note: '早餐后服用' },
    { name: '盐酸二甲双胍（降糖）', time: '12:30', taken: false, note: '午餐后服用' },
    { name: '阿托伐他汀（调脂）', time: '20:00', taken: false, note: '晚餐后服用' }
  ];
  alarmActive: boolean = false; // 跌倒告警页是否在前台（防重复触发）

  private context?: common.Context;
  private db: AlertDb = new AlertDb();
  private sync: DistributedSync = DistributedSync.getInstance();

  async init(context: common.Context): Promise<void> {
    this.context = context;
    AppStorage.setOrCreate<number>('yl_hr', 76);
    AppStorage.setOrCreate<number>('yl_steps', 1832);
    AppStorage.setOrCreate<boolean>('yl_guarding', true);
    AppStorage.setOrCreate<number>('yl_alertVer', 0);
    try {
      // 告警持久化恢复
      await this.db.init(context);
      const savedAlerts = await this.db.loadAll();
      if (savedAlerts.length > 0) {
        this.alerts = savedAlerts;
      }
      // 用药计划与角色恢复
      const pref = await preferences.getPreferences(context, PREF_NAME);
      const medsJson: preferences.ValueType = await pref.get(KEY_MEDS, '');
      if (typeof medsJson === 'string' && medsJson.length > 0) {
        const parsed = JSON.parse(medsJson) as MedicationPlan[];
        if (parsed.length > 0) {
          this.meds = parsed;
        }
      }
      const saved: preferences.ValueType = await pref.get(KEY_ROLE, 'elder');
      if (typeof saved === 'string' && (saved === 'elder' || saved === 'family')) {
        this.role = saved;
      }
      this.bumpAlerts();
    } catch (err) {
      // 首次启动无历史数据，使用默认值
    }
    // 分布式同步：授权+同账号时自动组网，否则降级纯本机
    await this.sync.init(context);
    this.sync.onRemoteAlert = (a: AlertEvent) => {
      this.mergeRemoteAlert(a);
    };
    this.sync.onRemoteHealth = (h: HealthPayload) => {
      AppStorage.setOrCreate<number>('yl_hr', h.hr);
      AppStorage.setOrCreate<number>('yl_steps', h.steps);
      AppStorage.setOrCreate<boolean>('yl_guarding', h.guarding);
    };
  }

  async saveRole(role: Role): Promise<void> {
    this.role = role;
    if (!this.context) {
      return;
    }
    try {
      const pref = await preferences.getPreferences(this.context, PREF_NAME);
      await pref.put(KEY_ROLE, role);
      await pref.flush();
    } catch (err) {
      // 持久化失败不影响本次会话
    }
  }

  async persistMeds(): Promise<void> {
    if (!this.context) {
      return;
    }
    try {
      const pref = await preferences.getPreferences(this.context, PREF_NAME);
      await pref.put(KEY_MEDS, JSON.stringify(this.meds));
      await pref.flush();
    } catch (err) {
      // 忽略持久化失败
    }
  }

  addAlert(a: AlertEvent): void {
    this.alerts.unshift(a);
    this.bumpAlerts();
    this.db.upsert(a).catch(() => {
      // 持久化失败不影响内存态展示
    });
    this.sync.putAlert(a);
    // 语音求救类告警即时通知家属（跌倒类由升级路径统一通知）
    if (a.type === 'sos') {
      NotifyService.getInstance().sendAlertNotify('银龄守护 · 求救呼叫', a.detail);
    }
    this.writeCardStatus('告警：' + this.alertLabel(a.type));
  }

  /** 远端设备同步来的告警：按 id 合入本地列表并落库（跨设备协同核心路径） */
  private mergeRemoteAlert(a: AlertEvent): void {
    for (const e of this.alerts) {
      if (e.id === a.id) {
        e.status = a.status;
        e.responseSec = a.responseSec;
        this.bumpAlerts();
        this.db.upsert(a).catch(() => {});
        return;
      }
    }
    this.alerts.unshift(a);
    this.bumpAlerts();
    this.db.upsert(a).catch(() => {});
  }

  escalateAlert(id: string): void {
    for (const a of this.alerts) {
      if (a.id === id) {
        a.status = 'escalated';
        this.db.upsert(a).catch(() => {});
        this.sync.putAlert(a);
        NotifyService.getInstance().sendAlertNotify('银龄守护 · 疑似跌倒告警', a.detail);
      }
    }
    this.bumpAlerts();
  }

  resolveAlert(id: string, responseSec: number): void {
    for (const a of this.alerts) {
      if (a.id === id) {
        a.status = 'resolved';
        a.responseSec = responseSec;
        this.db.upsert(a).catch(() => {});
        this.sync.putAlert(a);
      }
    }
    this.bumpAlerts();
    this.writeCardStatus('奶奶一切安好');
  }

  /** 演示模式：模拟手环/手表多源健康数据接入（后续替换为真实设备数据） */
  simulateHealth(): void {
    const hr = 68 + Math.floor(Math.random() * 16);
    const steps = (AppStorage.get<number>('yl_steps') ?? 1832) + Math.floor(Math.random() * 90);
    this.setHealth(hr, steps);
  }

  setHealth(hr: number, steps: number): void {
    AppStorage.setOrCreate<number>('yl_hr', hr);
    AppStorage.setOrCreate<number>('yl_steps', steps);
    this.sync.putHealth({
      hr: hr,
      steps: steps,
      guarding: AppStorage.get<boolean>('yl_guarding') ?? true
    });
    this.writeCardStatus(`心率 ${hr} · 步数 ${steps}`);
  }

  setGuarding(g: boolean): void {
    AppStorage.setOrCreate<boolean>('yl_guarding', g);
    this.writeCardStatus(g ? '守护中' : '守护已暂停');
  }

  private alertLabel(t: AlertType): string {
    if (t === 'fall') {
      return '疑似跌倒';
    }
    if (t === 'sos') {
      return '一键呼叫';
    }
    return '用药异常';
  }

  /** 供元服务桌面卡片读取的最新摘要（写入 Preferences，卡片进程可访问） */
  private async writeCardStatus(status: string): Promise<void> {
    if (!this.context) {
      return;
    }
    try {
      const pref = await preferences.getPreferences(this.context, CARD_PREF_NAME);
      await pref.put(KEY_CARD_STATUS, status);
      const guarding = AppStorage.get<boolean>('yl_guarding') ?? true;
      await pref.put(KEY_CARD_GUARDING, guarding);
      await pref.flush();
    } catch (err) {
      // 忽略卡片摘要写入失败
    }
  }

  private bumpAlerts(): void {
    AppStorage.setOrCreate<number>('yl_alertVer', Date.now());
  }
}
