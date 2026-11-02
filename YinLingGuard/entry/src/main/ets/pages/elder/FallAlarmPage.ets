import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { GuardStore } from '../../service/GuardStore';
import { Theme } from '../../common/Theme';

const COUNTDOWN_SEC = 10;

/**
 * 跌倒告警确认页（全屏红色高唤醒界面）。
 * 流程：端侧判定疑似跌倒 → 本页倒计时10秒等待老人取消 →
 * 老人点击"我没事"则解除；无响应则升级为告警事件通知家属。
 * 对应创新叙事：适老"倒计时自救"交互，避免误报骚扰家属，也兜底真跌倒场景。
 */
@Entry
@Component
struct FallAlarmPage {
  @State left: number = COUNTDOWN_SEC;

  private store: GuardStore = GuardStore.getInstance();
  private timerId: number = -1;

  aboutToAppear(): void {
    this.store.alarmActive = true;
    this.store.addAlert({
      id: 'fall' + Date.now().toString(),
      type: 'fall',
      status: 'waiting',
      timestamp: Date.now(),
      detail: '端侧检测到疑似跌倒（冲击+持续静止特征）',
      responseSec: -1
    });
    this.timerId = setInterval(() => {
      this.left -= 1;
      if (this.left <= 0) {
        this.escalate();
      }
    }, 1000);
  }

  aboutToDisappear(): void {
    this.store.alarmActive = false;
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private currentAlertId(): string {
    const alerts = this.store.alerts;
    return alerts.length > 0 ? alerts[0].id : '';
  }

  private imFine(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.store.resolveAlert(this.currentAlertId(), COUNTDOWN_SEC - this.left);
    promptAction.showToast({ message: '好的，请放心活动' });
    router.back();
  }

  private escalate(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.store.escalateAlert(this.currentAlertId());
    promptAction.showToast({ message: '无响应，已自动通知家属' });
    router.back();
  }

  build() {
    Column({ space: 22 }) {
      Text('⚠️').fontSize(80)
      Text('检测到您可能摔倒了')
        .fontSize(38)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
      Text('如果您没有事，请点击下方按钮')
        .fontSize(24)
        .fontColor('#FFE3DD')

      Text(this.left.toString())
        .fontSize(100)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
      Text('秒后将自动通知您的家人')
        .fontSize(20)
        .fontColor('#FFE3DD')

      Button('我没事', { type: ButtonType.Capsule })
        .fontSize(36)
        .fontColor(Theme.COLOR_DANGER)
        .backgroundColor(Color.White)
        .width('78%')
        .height(92)
        .onClick(() => {
          this.imFine();
        })

      Text('家人将收到：事件类型 · 发生时间 · 一键回拨')
        .fontSize(16)
        .fontColor('#FFD0C8')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.COLOR_DANGER)
    .justifyContent(FlexAlign.Center)
  }
}
