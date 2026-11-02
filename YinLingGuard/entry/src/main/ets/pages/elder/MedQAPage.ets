import { router } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { LlmService } from '../../service/LlmService';
import { AgentService, AgentStep } from '../../service/AgentService';
import { Theme } from '../../common/Theme';
import { ChatMessage } from '../../model/Models';

/**
 * AI 用药安全问答页（RAG + 多模态识药 + 管家 Agent）：
 * 拍照/相册识药（GLM-4V）→ 识别结果自动进入 RAG 问答；
 * 快捷问题/自由输入 → 向量检索知识库（embedding 召回）→ 云端 GLM 生成；
 * 用药管家（Agent）："分析→检索→生成"多步编排，过程步骤在对话流可视化。
 * 答案附知识来源，可溯源、抑幻觉。适老化大字号气泡对话。
 */
@Entry
@Component
struct MedQAPage {
  @State msgs: ChatMessage[] = [
    {
      role: 'assistant',
      content: '您好，我是您的用药安全助手。可以点下方"📷 拍照识药"拍药盒问我，也可以直接提问：\n· 这个药和降压药能一起吃吗？\n· 忘记吃药了怎么办？',
      sources: [] as string[]
    }
  ];
  @State input: string = '';
  @State busy: boolean = false;
  @State identifying: boolean = false;
  @State mode: string = '';

  private llm: LlmService = LlmService.getInstance();
  private agent: AgentService = AgentService.getInstance();
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.mode = this.llm.modeLabel();
  }
  private quicks: string[] = [
    '降压药和降糖药能一起吃吗？',
    '忘记吃降压药了怎么办？',
    '感冒药可以和降压药一起吃吗？'
  ];

  private async send(text: string): Promise<void> {
    const q = text.trim();
    if (q.length === 0 || this.busy) {
      return;
    }
    this.msgs.push({ role: 'user', content: q, sources: [] as string[] });
    this.busy = true;
    this.input = '';
    this.scroller.scrollEdge(Edge.Bottom);

    const ans = await this.llm.ask(q);
    this.msgs.push(ans);
    this.busy = false;
    this.mode = this.llm.modeLabel();
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 100);
  }

  /** 相册选图 → GLM-4V 识别 → 自动发起联用安全问答（系统 Picker 免权限） */
  private async identifyFromGallery(): Promise<void> {
    if (this.identifying || this.busy) {
      return;
    }
    try {
      this.identifying = true;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      if (result.photoUris.length === 0) {
        this.identifying = false;
        return;
      }
      const file = fileIo.openSync(result.photoUris[0], fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(file.fd);
      const buf = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file);
      const base64 = new util.Base64Helper().encodeToStringSync(new Uint8Array(buf));

      const med = await this.llm.identifyMed(base64);
      this.identifying = false;
      this.msgs.push({ role: 'assistant', content: '📷 识别结果：' + med, sources: [] as string[] });
      this.scroller.scrollEdge(Edge.Bottom);
      const question = '我手里这个药（' + med + '）和我平时吃的降压药、降糖药能一起吃吗？要注意什么？';
      await this.send(question);
    } catch (err) {
      this.identifying = false;
      // 识别失败走演示注入，保证演示链路完整
      this.useDemoMed();
    }
  }

  /** 演示模式：示例识别结果直接进入问答（无相册/断网环境） */
  private useDemoMed(): void {
    const med = this.llm.simulateIdentify();
    this.msgs.push({ role: 'assistant', content: '📷 识别结果（示例）：' + med, sources: [] as string[] });
    this.scroller.scrollEdge(Edge.Bottom);
    this.send('我手里这个药（' + med + '）和我平时吃的降压药、降糖药能一起吃吗？要注意什么？');
  }

  /** 用药管家 Agent：多步任务编排，过程步骤实时插入对话流 */
  private async runAgentDemo(): Promise<void> {
    if (this.busy) {
      return;
    }
    const goal = '我感冒了，本身有高血压和糖尿病，帮我看看怎么选感冒药，要注意什么';
    this.msgs.push({ role: 'user', content: '🤖 ' + goal, sources: [] as string[] });
    this.busy = true;
    this.scroller.scrollEdge(Edge.Bottom);
    try {
      const answer = await this.agent.runTask(goal, (s: AgentStep) => {
        this.msgs.push({
          role: 'assistant',
          content: s.icon + ' 【' + s.title + '】' + s.detail,
          sources: [] as string[]
        });
        this.scroller.scrollEdge(Edge.Bottom);
      });
      this.msgs.push(answer);
    } catch (err) {
      this.msgs.push({
        role: 'assistant',
        content: '管家暂时离线，请稍后再试或直接提问。',
        sources: [] as string[]
      });
    }
    this.busy = false;
    this.mode = this.llm.modeLabel();
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 100);
  }

  build() {
    Column() {
      // 顶栏
      Row({ space: 12 }) {
        Text('‹')
          .fontSize(34)
          .fontColor(Theme.COLOR_TEXT)
          .onClick(() => {
            router.back();
          })
        Text('AI 用药安全助手')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.COLOR_TEXT)
          .layoutWeight(1)
        Text(this.mode)
          .fontSize(14)
          .fontColor(Theme.COLOR_PRIMARY)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(12)
          .backgroundColor(Theme.COLOR_CHIP)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })

      // 对话区
      List({ space: 14, scroller: this.scroller }) {
        ForEach(this.msgs, (m: ChatMessage) => {
          ListItem() {
            this.bubble(m)
          }
        }, (m: ChatMessage, idx: number) => `msg-${idx}-${m.content.length}`)
      }
      .layoutWeight(1)
      .padding({ left: 16, right: 16 })

      // 识药与管家行动条：拍照识药（GLM-4V）+ 示例识药 + 用药管家 Agent
      Row({ space: 8 }) {
        Button(this.identifying ? '识别中…' : '📷 拍照识药')
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor(Theme.COLOR_PRIMARY)
          .height(42)
          .layoutWeight(1.1)
          .enabled(!this.identifying && !this.busy)
          .onClick(() => {
            this.identifyFromGallery();
          })
        Button('🧪 示例识药')
          .fontSize(15)
          .fontColor(Theme.COLOR_PRIMARY)
          .backgroundColor(Theme.COLOR_CHIP)
          .height(42)
          .layoutWeight(0.9)
          .enabled(!this.busy)
          .onClick(() => {
            this.useDemoMed();
          })
        Button('🤖 用药管家')
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor(Theme.COLOR_OK)
          .height(42)
          .layoutWeight(1)
          .enabled(!this.busy)
          .onClick(() => {
            this.runAgentDemo();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 6 })

      // 快捷问题
      Scroll() {
        Row({ space: 10 }) {
          ForEach(this.quicks, (q: string) => {
            Text(q)
              .fontSize(16)
              .fontColor(Theme.COLOR_PRIMARY)
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor(Theme.COLOR_CHIP)
              .borderRadius(18)
              .onClick(() => {
                this.send(q);
              })
          }, (q: string) => q)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })

      // 输入栏
      Row({ space: 10 }) {
        TextInput({ placeholder: '请输入您的用药问题…', text: this.input })
          .fontSize(20)
          .height(54)
          .layoutWeight(1)
          .backgroundColor(Theme.COLOR_CARD)
          .enterKeyType(EnterKeyType.Send)
          .onChange((v: string) => {
            this.input = v;
          })
          .onSubmit(() => {
            this.send(this.input);
          })
        Button(this.busy ? '思考中…' : '发送')
          .fontSize(20)
          .fontColor(Color.White)
          .backgroundColor(this.busy ? Theme.COLOR_TEXT_SUB : Theme.COLOR_PRIMARY)
          .height(54)
          .enabled(!this.busy)
          .onClick(() => {
            this.send(this.input);
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.COLOR_BG)
  }

  @Builder
  bubble(m: ChatMessage) {
    Column({ space: 4 }) {
      Text(m.content)
        .fontSize(21)
        .lineHeight(32)
        .fontColor(m.role === 'user' ? Color.White : Theme.COLOR_TEXT)
        .backgroundColor(m.role === 'user' ? Theme.COLOR_PRIMARY : Theme.COLOR_CARD)
        .padding(16)
        .borderRadius(16)
        .constraintSize({ maxWidth: '84%' })
      if (m.sources.length > 0) {
        Text('知识来源：' + m.sources.join('、'))
          .fontSize(13)
          .fontColor(Theme.COLOR_TEXT_SUB)
          .opacity(0.85)
      }
    }
    .width('100%')
    .alignItems(m.role === 'user' ? HorizontalAlign.End : HorizontalAlign.Start)
  }
}
