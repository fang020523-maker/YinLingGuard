import { promptAction } from '@kit.ArkUI';
import { GuardStore } from '../../service/GuardStore';
import { Theme } from '../../common/Theme';
import { AlertEvent, AlertStatus, AlertType } from '../../model/Models';

/**
 * 家属端看板：老人实时状态（守护开关/心率/步数）+ 告警与求助记录。
 * 第二周接入：分布式数据对象跨设备同步、Push Kit 推送、元服务桌面卡片。
 */
@Entry
@Component
struct FamilyHomePage {
  // 监听告警版本号变化（GuardStore 每次数据变更都会更新该版本号），刷新告警快照
  @StorageProp('yl_alertVer') @Watch('onAlertsChanged') alertVer: number = 0;
  @StorageProp('yl_hr') hr: number = 76;
  @StorageProp('yl_steps') steps: number = 1832;
  @StorageProp('yl_guarding') guarding: boolean = true;
  @State alertsSnap: AlertEvent[] = [];

  private store: GuardStore = GuardStore.getInstance();

  aboutToAppear(): void {
    this.refreshAlerts();
  }

  onAlertsChanged(): void {
    this.refreshAlerts();
  }

  private refreshAlerts(): void {
    this.alertsSnap = this.store.alerts.slice();
  }

  private statusLabel(s: AlertStatus): string {
    if (s === 'waiting') {
      return '确认中';
    }
    if (s === 'escalated') {
      return '待处理';
    }
    return '已处理';
  }

  private statusColor(s: AlertStatus): string {
    if (s === 'waiting') {
      return Theme.COLOR_WARN;
    }
    if (s === 'escalated') {
      return Theme.COLOR_DANGER;
    }
    return Theme.COLOR_OK;
  }

  private typeTitle(t: AlertType): string {
    if (t === 'fall') {
      return '疑似跌倒告警';
    }
    if (t === 'sos') {
      return '一键呼叫';
    }
    return '用药异常提醒';
  }

  private typeEmoji(t: AlertType): string {
    if (t === 'fall') {
      return '🚨';
    }
    if (t === 'sos') {
      return '📢';
    }
    return '💊';
  }

  private timeStr(ts: number): string {
    const d = new Date(ts);
    const p = (n: number): string => (n < 10 ? '0' + n.toString() : n.toString());
    return `${p(d.getHours())}:${p(d.getMinutes())}`;
  }

  private handleAlert(id: string): void {
    this.store.resolveAlert(id, -1);
    promptAction.showToast({ message: '已标记处理，稍后将支持一键回拨' });
  }

  private simulateIncomingAlert(): void {
    this.store.addAlert({
      id: 'fall' + Date.now().toString(),
      type: 'fall',
      status: 'escalated',
      timestamp: Date.now(),
      detail: '老人端倒计时无响应，自动升级通知（演示）',
      responseSec: -1
    });
    promptAction.showToast({ message: '收到老人端跌倒告警！' });
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 16 }) {
          // 顶栏
          Row() {
            Column({ space: 4 }) {
              Text('家人看板')
                .fontSize(Theme.FONT_FAMILY_TITLE + 6)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.COLOR_TEXT)
              Text('王奶奶 · 72岁 · 独居（演示档案）')
                .fontSize(15)
                .fontColor(Theme.COLOR_TEXT_SUB)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .margin({ top: 20 })

          // 实时状态卡
          Column({ space: 14 }) {
            Row({ space: 10 }) {
              Text(this.guarding ? '🟢 守护中' : '⚪ 守护已暂停')
                .fontSize(20)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.guarding ? Theme.COLOR_OK : Theme.COLOR_TEXT_SUB)
                .layoutWeight(1)
              Text('实时')
                .fontSize(13)
                .fontColor(Theme.COLOR_PRIMARY)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius(10)
                .backgroundColor(Theme.COLOR_CHIP)
            }
            .width('100%')

            Row() {
              Column({ space: 4 }) {
                Text('❤️ ' + this.hr.toString())
                  .fontSize(30)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Theme.COLOR_DANGER)
                Text('心率 次/分').fontSize(14).fontColor(Theme.COLOR_TEXT_SUB)
              }
              .layoutWeight(1)

              Column({ space: 4 }) {
                Text('🚶 ' + this.steps.toString())
                  .fontSize(30)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Theme.COLOR_OK)
                Text('今日步数').fontSize(14).fontColor(Theme.COLOR_TEXT_SUB)
              }
              .layoutWeight(1)

              Column({ space: 4 }) {
                Text('✅ 3/3')
                  .fontSize(30)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Theme.COLOR_WARN)
                Text('今日用药').fontSize(14).fontColor(Theme.COLOR_TEXT_SUB)
              }
              .layoutWeight(1)
            }
            .width('100%')
          }
          .width('100%')
          .padding(20)
          .borderRadius(20)
          .backgroundColor(Theme.COLOR_CARD)

          // 告警与求助记录
          Column({ space: 12 }) {
            Row() {
              Text('告警与求助记录')
                .fontSize(21)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.COLOR_TEXT)
                .layoutWeight(1)
              Text(`共 ${this.alertsSnap.length} 条`)
                .fontSize(14)
                .fontColor(Theme.COLOR_TEXT_SUB)
            }
            .width('100%')

            if (this.alertsSnap.length === 0) {
              Text('暂无记录，一切安好 🌿')
                .fontSize(16)
                .fontColor(Theme.COLOR_TEXT_SUB)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding(20)
            }

            ForEach(this.alertsSnap, (a: AlertEvent) => {
              Row({ space: 14 }) {
                Text(this.typeEmoji(a.type)).fontSize(28)
                Column({ space: 4 }) {
                  Text(this.typeTitle(a.type))
                    .fontSize(19)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Theme.COLOR_TEXT)
                  Text(this.timeStr(a.timestamp) + ' · ' + a.detail)
                    .fontSize(13)
                    .fontColor(Theme.COLOR_TEXT_SUB)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text(this.statusLabel(a.status))
                  .fontSize(13)
                  .fontColor(Color.White)
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .borderRadius(12)
                  .backgroundColor(this.statusColor(a.status))
              }
              .width('100%')
              .padding(14)
              .borderRadius(14)
              .backgroundColor(a.status === 'escalated' ? '#FDEDEA' : Theme.COLOR_CARD)

              if (a.status === 'escalated') {
                Row({ space: 10 }) {
                  Button('📞 回拨老人')
                    .fontSize(16)
                    .fontColor(Color.White)
                    .backgroundColor(Theme.COLOR_PRIMARY)
                    .height(44)
                    .layoutWeight(1)
                    .onClick(() => {
                      promptAction.showToast({ message: '拨号能力第二周接入（Call Kit）' });
                    })
                  Button('✅ 标记处理')
                    .fontSize(16)
                    .fontColor(Color.White)
                    .backgroundColor(Theme.COLOR_OK)
                    .height(44)
                    .layoutWeight(1)
                    .onClick(() => {
                      this.handleAlert(a.id);
                    })
                }
                .width('100%')
              }
            }, (a: AlertEvent) => a.id + '-' + a.status + '-' + this.alertVer.toString())
          }
          .width('100%')
          .padding(20)
          .borderRadius(20)
          .backgroundColor(Theme.COLOR_CARD)
          .alignItems(HorizontalAlign.Start)

          // 演示入口
          Button('【演示】模拟接收一次老人端跌倒告警')
            .fontSize(18)
            .fontColor(Color.White)
            .backgroundColor(Theme.COLOR_WARN)
            .width('100%')
            .height(60)
            .onClick(() => {
              this.simulateIncomingAlert();
            })

          // 后续能力预告（第二/三周接入）
          Text('即将接入：分布式跨设备同步 · Push Kit 告警推送 · 桌面元服务卡片 · 手表心率多模态融合')
            .fontSize(13)
            .fontColor(Theme.COLOR_TEXT_SUB)
            .opacity(0.75)
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
