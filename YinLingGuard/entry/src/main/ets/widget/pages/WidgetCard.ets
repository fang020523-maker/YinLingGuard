let storage = new LocalStorage();

/**
 * 守护状态桌面卡片（2x2 元服务卡片）。
 * ArkTS 卡片运行在受限环境：仅使用基础组件与 LocalStorageProp 数据绑定。
 */
@Entry(storage)
@Component
struct GuardStatusCard {
  @LocalStorageProp('guarding') guarding: string = '守护中';
  @LocalStorageProp('status') status: string = '奶奶一切安好';

  build() {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Text('❤️').fontSize(16)
        Text('银龄守护')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#E85D4A')
      }
      .width('100%')

      Text(this.guarding)
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3E9B6E')

      Text(this.status)
        .fontSize(13)
        .fontColor('#8A7A6D')
        .maxLines(2)
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .backgroundColor('#FFF7F2')
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: {}
      });
    })
  }
}
