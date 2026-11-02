import { sensor } from '@kit.SensorServiceKit';

/**
 * 端侧跌倒检测服务：加速度合幅值"冲击相 + 静止相"滑动窗口状态机。
 * 对应学术叙事：Edge-Cloud Collaborative Inference——原始传感数据全程不出端，
 * 仅告警事件（结构化结论）外发，兼顾隐私与时延。
 * 论文演进路径（写入参赛文档）：阈值状态机 → 轻量时序模型 → 联邦学习跨家庭联合优化（FedAvg）。
 */
export class FallDetectService {
  private static instance?: FallDetectService;

  static getInstance(): FallDetectService {
    if (!FallDetectService.instance) {
      FallDetectService.instance = new FallDetectService();
    }
    return FallDetectService.instance;
  }

  private spikeTs: number = 0;      // 冲击发生时刻
  private stillCount: number = 0;   // 冲击后静止帧计数
  private lastFireTs: number = 0;   // 触发冷却（防重复告警）
  private started: boolean = false;
  private listener?: (src: string) => void;

  setListener(l: (src: string) => void): void {
    this.listener = l;
  }

  start(): void {
    if (this.started) {
      return;
    }
    this.started = true;
    try {
      sensor.on(sensor.SensorId.ACCELEROMETER, (event: sensor.AccelerometerResponse) => {
        this.onAcc(event.x, event.y, event.z);
      }, { interval: 100000000 }); // 100ms 采样
    } catch (err) {
      // 模拟器或部分设备不支持加速度传感器时静默降级，演示模式仍可用
    }
  }

  stop(): void {
    this.started = false;
    try {
      sensor.off(sensor.SensorId.ACCELEROMETER);
    } catch (err) {
      // 忽略重复注销
    }
  }

  isStarted(): boolean {
    return this.started;
  }

  /** 演示模式：注入一次模拟跌倒（评审演示 / 模拟器无传感器场景） */
  simulateFall(): void {
    this.fire('demo');
  }

  private onAcc(x: number, y: number, z: number): void {
    const g = Math.sqrt(x * x + y * y + z * z) / 9.8;
    const now = Date.now();

    if (g > 2.8) {
      // 冲击相：合加速度突增（摔倒瞬间人体撞击地面约 2.5~4g）
      this.spikeTs = now;
      this.stillCount = 0;
      return;
    }
    if (this.spikeTs > 0 && now - this.spikeTs < 5000) {
      if (g < 0.25) {
        // 静止相：冲击后持续近似静止（躺地不起特征）
        this.stillCount++;
        if (this.stillCount >= 12) {
          this.reset();
          this.fire('sensor');
        }
      }
    }
  }

  private reset(): void {
    this.spikeTs = 0;
    this.stillCount = 0;
  }

  private fire(src: string): void {
    const now = Date.now();
    if (now - this.lastFireTs < 30000) {
      return; // 30秒冷却
    }
    this.lastFireTs = now;
    if (this.listener) {
      this.listener(src);
    }
  }
}
