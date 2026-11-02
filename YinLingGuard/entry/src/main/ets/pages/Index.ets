import { router } from '@kit.ArkUI';
import { GuardStore } from '../service/GuardStore';
import { Theme } from '../common/Theme';
import { Role } from '../model/Models';

/**
 * 角色选择页：同一应用安装于老人手机与家属设备，
 * 首次启动时选择身份进入对应工作台（单应用双角色，便于分布式同应用数据同步）。
 */
@Entry
@Component
struct Index {

  build() {
    Column({ space: 20 }) {
      Column({ space: 10 }) {
        Text('❤️').fontSize(56)
        Text('银龄守护')
          .fontSize(46)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.COLOR_PRIMARY)
        Text('端云协同 · 多模态感知 · 适老健康守护')
          .fontSize(19)
          .fontColor(Theme.COLOR_TEXT_SUB)
      }
      .margin({ top: 90 })

      Text('为独居老人构建"端侧感知 · 云端智能 · 家人协同"的守护闭环')
        .fontSize(17)
        .fontColor(Theme.COLOR_TEXT_SUB)
        .textAlign(TextAlign.Center)

      Blank()

      this.roleCard('elder', '我是老人', '跌倒守护 · 用药提醒 · AI用药问答', '👵')
      this.roleCard('family', '我是家属', '状态看板 · 告警接收 · 远程关怀', '👨‍💼')

      Text('第九届传智杯 · HarmonyOS Codelabs 挑战赛 · 研究生组')
        .fontSize(13)
        .fontColor(Theme.COLOR_TEXT_SUB)
        .opacity(0.7)
        .margin({ bottom: 30 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.COLOR_BG)
    .padding({ left: 28, right: 28 })
  }

  @Builder
  roleCard(role: Role, title: string, desc: string, emoji: string) {
    Row({ space: 18 }) {
      Text(emoji).fontSize(44)
      Column({ space: 6 }) {
        Text(title)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.COLOR_TEXT)
        Text(desc)
          .fontSize(17)
          .fontColor(Theme.COLOR_TEXT_SUB)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('›')
        .fontSize(34)
        .fontColor(Theme.COLOR_TEXT_SUB)
    }
    .width('100%')
    .padding(24)
    .borderRadius(20)
    .backgroundColor(Theme.COLOR_CARD)
    .shadow({ radius: 12, color: 'rgba(232,93,74,0.10)', offsetY: 4 })
    .onClick(() => {
      this.enter(role);
    })
  }

  private enter(role: Role): void {
    GuardStore.getInstance().saveRole(role);
    if (role === 'elder') {
      router.replaceUrl({ url: 'pages/elder/ElderHomePage' });
    } else {
      router.replaceUrl({ url: 'pages/family/FamilyHomePage' });
    }
  }
}
