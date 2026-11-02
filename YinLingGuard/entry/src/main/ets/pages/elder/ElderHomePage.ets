import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { GuardStore } from '../../service/GuardStore';
import { FallDetectService } from '../../service/FallDetectService';
import { SosDetectService } from '../../service/SosDetectService';
import { Theme } from '../../common/Theme';
import { MedicationPlan } from '../../model/Models';

/**
 * 老人端首页：适老化大字号高对比度设计。
 * 核心能力：跌倒检测开关（传感器端侧判定）、语音求救守护（端侧关键词识别）、
 * 演示模式一键模拟、用药计划打卡、一键呼叫家属、AI用药安全问答入口。
 */
@Entry
@Component
struct ElderHomePage {
  @StorageProp('yl_hr') hr: number = 76;
  @StorageProp('yl_steps') steps: number = 1832;
  @State guarding: boolean = true;
  @State sosOn: boolean = false;
  @State meds: MedicationPlan[] = GuardStore.getInstance().meds;

  private store: GuardStore = GuardStore.getInstance();
  private fall: FallDetectService = FallDetectService.getInstance();
  private sos: SosDetectService = SosDetectService.getInstance();
  private healthTimer: number = -1;

  aboutToAppear(): void {
    this.fall.setListener((src: string) => {
      this.onFallDetected(src);
    });
    this.sos.setListener((text: string) => {
      this.onSosHit(text);
    });
    if (this.guarding) {
      this.fall.start();
    }
    // 演示模式：每5秒模拟一次手环健康数据上报（后续替换为真实穿戴设备数据源）
    this.healthTimer = setInterval(() => {
      this.store.simulateHealth();
    }, 5000);
  }

  aboutToDisappear(): void {
    if (this.healthTimer >= 0) {
      clearInterval(this.healthTimer);
      this.healthTimer = -1;
    }
  }

  private onFallDetected(src: string): void {
    if (this.store.alarmActive) {
      return;
    }
    router.pushUrl({ url: 'pages/elder/FallAlarmPage' });
  }

  private toggleGuard(): void {
    this.guarding = !this.guarding;
    this.store.setGuarding(this.guarding);
    if (this.guarding) {
      this.fall.start();
    } else {
      this.fall.stop();
    }
  }

  /** 开启语音守护：先申请麦克风权限，成功后启动端侧识别 */
  private async toggleSos(): Promise<void> {
    if (!this.sosOn) {
      try {
        const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
        const atManager = abilityAccessCtrl.createAtManager();
        const perms: Array<Permissions> = ['ohos.permission.MICROPHONE'];
        const result = await atManager.requestPermissionsFromUser(ctx, perms);
        if (result.authResults.length > 0 && result.authResults[0] === 0) {
          await this.sos.start();
          this.sosOn = this.sos.isStarted();
        } else {
          promptAction.showToast({ message: '需要麦克风权限才能听懂呼救' });
        }
      } catch (err) {
        promptAction.showToast({ message: '当前设备暂不支持语音识别' });
      }
    } else {
      this.sos.stop();
      this.sosOn = false;
    }
  }

  /** 端侧识别命中求救关键词：语音模态告警（原始音频不出端，仅事件外发） */
  private onSosHit(text: string): void {
    this.store.addAlert({
      id: 'sosv' + Date.now().toString(),
      type: 'sos',
      status: 'escalated',
      timestamp: Date.now(),
      detail: `端侧语音识别到求救：“${text}”`,
      responseSec: -1
    });
    promptAction.showToast({ message: '听到您的呼救，已通知家人' });
  }

  private toggleMed(index: number): void {
    const m = this.meds[index];
    const updated: MedicationPlan = { name: m.name, time: m.time, taken: !m.taken, note: m.note };
    this.meds.splice(index, 1, updated);
    GuardStore.getInstance().persistMeds();
  }

  private sosCall(): void {
    this.store.addAlert({
      id: 'sos' + Date.now().toString(),
      type: 'sos',
      status: 'escalated',
      timestamp: Date.now(),
      detail: '老人主动发起一键呼叫',
      responseSec: -1
    });
    promptAction.showToast({ message: '已通知家属，请保持手机畅通' });
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 16 }) {
          // 顶部问候与守护状态
          Row() {
            Column({ space: 4 }) {
              Text('下午好，王奶奶')
                .fontSize(Theme.FONT_ELDER_TITLE)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.COLOR_TEXT)
              Text('银龄守护正在为您服务')
                .fontSize(18)
                .fontColor(Theme.COLOR_TEXT_SUB)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text(this.guarding ? '守护中 🟢' : '已暂停 ⚪')
              .fontSize(20)
              .fontColor(this.guarding ? Theme.COLOR_OK : Theme.COLOR_TEXT_SUB)
          }
          .width('100%')
          .margin({ top: 20 })

          // 健康数据卡（多源模拟：手环/手表，第二周接入真实穿戴设备）
          Row({ space: 24 }) {
            Column({ space: 6 }) {
              Text('❤️ ' + this.hr.toString())
                .fontSize(36)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.COLOR_DANGER)
              Text('心率 次/分').fontSize(16).fontColor(Theme.COLOR_TEXT_SUB)
            }
            Column({ space: 6 }) {
              Text('🚶 ' + this.steps.toString())
                .fontSize(36)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.COLOR_OK)
              Text('今日步数').fontSize(16).fontColor(Theme.COLOR_TEXT_SUB)
            }
            Column({ space: 6 }) {
              Text('🔋 82%').fontSize(36).fontWeight(FontWeight.Bold).fontColor(Theme.COLOR_WARN)
              Text('手环电量').fontSize(16).fontColor(Theme.COLOR_TEXT_SUB)
            }
          }
          .width('100%')
          .padding(24)
          .borderRadius(20)
          .backgroundColor(Theme.COLOR_CARD)
          .justifyContent(FlexAlign.SpaceAround)

          // 用药提醒卡
          Column({ space: 12 }) {
            Text('今日用药')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.COLOR_TEXT)
            ForEach(this.meds, (m: MedicationPlan, index: number) => {
              Row({ space: 14 }) {
                Text(m.time).fontSize(22).fontColor(Theme.COLOR_PRIMARY).fontWeight(FontWeight.Medium)
                Column({ space: 2 }) {
                  Text(m.name).fontSize(22).fontColor(Theme.COLOR_TEXT)
                  Text(m.note).fontSize(15).fontColor(Theme.COLOR_TEXT_SUB)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text(m.taken ? '✓' : '')
                  .fontSize(24)
                  .fontColor(Color.White)
                  .width(44)
                  .height(44)
                  .textAlign(TextAlign.Center)
                  .borderRadius(22)
                  .backgroundColor(m.taken ? Theme.COLOR_OK : '#E8DDD5')
                  .onClick(() => {
                    this.toggleMed(index);
                  })
              }
              .width('100%')
              .padding(14)
              .borderRadius(14)
              .backgroundColor('#FBF3EE')
            }, (m: MedicationPlan) => m.name)
          }
          .width('100%')
          .padding(20)
          .borderRadius(20)
          .backgroundColor(Theme.COLOR_CARD)
          .alignItems(HorizontalAlign.Start)

          // 核心行动按钮
          Button('🆘 一键呼叫家人', { type: ButtonType.Capsule })
            .fontSize(Theme.FONT_ELDER_BTN)
            .fontColor(Color.White)
            .backgroundColor(Theme.COLOR_DANGER)
            .width('100%')
            .height(84)
            .onClick(() => {
              this.sosCall();
            })

          Button('💊 AI 用药安全问答', { type: ButtonType.Capsule })
            .fontSize(Theme.FONT_ELDER_BTN)
            .fontColor(Color.White)
            .backgroundColor(Theme.COLOR_PRIMARY)
            .width('100%')
            .height(84)
            .onClick(() => {
              router.pushUrl({ url: 'pages/elder/MedQAPage' });
            })

          // 守护设置
          Row({ space: 12 }) {
            Text('跌倒智能守护')
              .fontSize(22)
              .fontColor(Theme.COLOR_TEXT)
              .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.guarding })
              .selectedColor(Theme.COLOR_OK)
              .onChange((on: boolean) => {
                if (on !== this.guarding) {
                  this.toggleGuard();
                }
              })
          }
          .width('100%')
          .padding(20)
          .borderRadius(20)
          .backgroundColor(Theme.COLOR_CARD)

          Row({ space: 12 }) {
            Column({ space: 2 }) {
              Text('语音求救守护')
                .fontSize(22)
                .fontColor(Theme.COLOR_TEXT)
              Text('喊“救命/摔倒了”即可呼救 · 语音不出设备')
                .fontSize(14)
                .fontColor(Theme.COLOR_TEXT_SUB)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.sosOn })
              .selectedColor(Theme.COLOR_OK)
              .onChange((on: boolean) => {
                if (on !== this.sosOn) {
                  this.toggleSos();
                }
              })
          }
          .width('100%')
          .padding(20)
          .borderRadius(20)
          .backgroundColor(Theme.COLOR_CARD)

          Button('【演示】模拟一次跌倒')
            .fontSize(20)
            .fontColor(Color.White)
            .backgroundColor(Theme.COLOR_WARN)
            .width('100%')
            .height(64)
            .onClick(() => {
              this.fall.simulateFall();
            })

          Button('【演示】模拟喊“救命”触发语音告警')
            .fontSize(20)
            .fontColor(Color.White)
            .backgroundColor(Theme.COLOR_WARN)
            .width('100%')
            .height(64)
            .onClick(() => {
              this.sos.simulate('救命…我摔倒了');
            })
            .margin({ bottom: 30 })
        }
        .width('100%')
        .padding({ left: 22, right: 22 })
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.COLOR_BG)
  }
}
