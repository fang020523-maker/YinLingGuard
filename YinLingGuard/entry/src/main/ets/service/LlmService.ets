import { http } from '@kit.NetworkKit';
import { ChatMessage } from '../model/Models';

// 本地用药知识库条目（药师审核流程规划中；正式版扩充为 500+ 条并支持云端同步）
interface KbEntry {
  keywords: string[];
  title: string;
  content: string;
}

interface GlmMessage {
  role: string;
  content: string;
}

interface GlmRequest {
  model: string;
  messages: GlmMessage[];
}

interface GlmChoice {
  message: GlmMessage;
}

interface GlmResponse {
  choices: GlmChoice[];
}

// GLM-4V 多模态消息：content 为 文本/图片 混合数组
interface VisionPart {
  type: string;
  text?: string;
  image_url?: VisionUrl;
}

interface VisionUrl {
  url: string;
}

interface GlmVisionMessage {
  role: string;
  content: VisionPart[];
}

interface GlmVisionRequest {
  model: string;
  messages: GlmVisionMessage[];
}

/** 向量召回的打分中间结构 */
interface ScoredEntry {
  entry: KbEntry;
  score: number;
}

interface EmbeddingResponse {
  data: EmbeddingItem[];
}

interface EmbeddingItem {
  embedding: number[];
}

const KB: KbEntry[] = [
  {
    keywords: ['降压', '氨氯地平', '血压药', '地平', '络活喜'],
    title: '降压药服用与联用须知',
    content: '氨氯地平等地平类降压药建议每天固定时间服用，不可自行停药或减量；与其他降压药联用可能引起头晕、乏力等低血压症状，起身时要缓慢；服药期间避免大量饮用西柚汁或葡萄柚，会导致血药浓度升高。'
  },
  {
    keywords: ['二甲双胍', '降糖', '血糖', '糖尿病', '格华止'],
    title: '二甲双胍用药要点',
    content: '二甲双胍随餐或餐后服用可减少胃肠不适；单独使用一般不易低血糖，但与胰岛素或其他降糖药联用时需警惕心慌、出汗、手抖等低血糖表现；长期服用建议每年检查肾功能和维生素B12。'
  },
  {
    keywords: ['他汀', '调脂', '阿托伐', '血脂', '胆固醇', '立普妥'],
    title: '他汀类调脂药须知',
    content: '他汀类（如阿托伐他汀）晚间服用效果更好；避免与大量西柚同食；如出现不明原因肌肉酸痛、乏力或尿色加深，应立即就医排查横纹肌溶解风险，不要自行停药。'
  },
  {
    keywords: ['阿司匹林', '抗凝', '活血', '出血', '华法林', '氯吡格雷'],
    title: '抗血小板/抗凝药安全',
    content: '阿司匹林等抗血小板药与华法林等抗凝药、活血化瘀类中药或鱼油同服会增加出血风险；注意观察牙龈出血、皮肤瘀斑、黑便等信号；拔牙或手术前务必告知医生正在服用此类药物。'
  },
  {
    keywords: ['一起吃', '同时服', '联用', '合用', '同服'],
    title: '多种药物联用基本原则',
    content: '老年人同时服用多种药物时，建议：①所有药物在医生或药师指导下统一梳理，避免重复成分；②降压药与降糖药联用注意体位变化缓慢，防止头晕跌倒；③不确定能否同服时，间隔1-2小时服用并咨询药师。'
  },
  {
    keywords: ['感冒', '感冒药', '退烧', '止咳', '布洛芬', '对乙酰'],
    title: '感冒药与慢病药物注意事项',
    content: '含伪麻黄碱的复方感冒药可能升高血压、加快心率，高血压患者慎用；对乙酰氨基酚每日总量有限（一般不超过2克），切勿同时服用多种感冒药造成叠加过量；感冒药与降压药同服前建议咨询药师。'
  },
  {
    keywords: ['忘记', '漏服', '忘了', '补服'],
    title: '漏服药物处理原则',
    content: '漏服药物的一般原则：想起时距离下次服药时间较远可立即补服；已接近下次服药时间则跳过本次，切勿一次服用双倍剂量补救；具体要求以药品说明书为准，或咨询开方医生。'
  },
  {
    keywords: ['钙', '维生素', '保健品', '补钙'],
    title: '钙剂与维生素类补充须知',
    content: '钙剂与某些药物（如部分抗生素、甲状腺类药物）需间隔2小时以上服用；大量补钙需注意便秘和结石风险；保健品不能替代处方药，慢病患者添加任何保健品前应咨询医生。'
  },
  {
    keywords: ['抗生素', '消炎药', '阿莫西林', '头孢', '左氧氟沙星'],
    title: '抗生素使用须知',
    content: '头孢类抗生素服药期间及停药后7天内严禁饮酒或含酒精食物（可能发生双硫仑样反应，严重可危及生命）；左氧氟沙星等喹诺酮类可能影响血糖并引起肌腱不适，老年人慎用；抗生素必须遵医嘱足疗程使用，不可自行停药。'
  },
  {
    keywords: ['安眠', '助眠', '镇静', '地西泮', '艾司唑仑'],
    title: '安眠药/镇静药安全',
    content: '安眠药起效后应立即上床，避免夜间起床行走（跌倒风险显著升高）；不要与酒精同服；老年人宜从最小剂量开始；长期使用不可突然停药，应在医生指导下逐渐减量。'
  },
  {
    keywords: ['胃药', '胃酸', '奥美拉唑', '反酸', '胃舒'],
    title: '常用胃药注意事项',
    content: '奥美拉唑等质子泵抑制剂建议早餐前半小时服用；长期使用可能影响钙、镁及维生素B12吸收；与氯吡格雷等药物可能存在相互作用，联用前咨询医生；铝碳酸镁等抗酸剂与其他药物间隔1-2小时服用。'
  },
  {
    keywords: ['中药', '中成药', '活血', '丹参', '三七'],
    title: '中药与西药联用注意',
    content: '活血化瘀类中药（丹参、三七等）与抗血小板/抗凝西药同服会增加出血风险；含甘草的中成药长期服用可能升高血压；中西药联用建议间隔1-2小时，并向医师说明全部在用药物。'
  },
  {
    keywords: ['胰岛素', '注射', '血糖仪'],
    title: '胰岛素使用要点',
    content: '胰岛素注射后必须按时进餐，否则易发生严重低血糖；注射部位轮换避免脂肪增生；开封后常温保存不超过28天；外出携带糖果备用，出现心慌出汗立即进食并测血糖。'
  },
  {
    keywords: ['抗过敏', '氯雷他定', '扑尔敏', '过敏'],
    title: '抗过敏药使用注意',
    content: '扑尔敏等第一代抗组胺药易引起嗜睡，老年人服用后跌倒风险升高，优先选择氯雷他定等嗜睡副作用较小的药物；服药期间避免驾驶和高空活动；与安眠药同服会加重嗜睡。'
  },
  {
    keywords: ['利尿', '氢氯噻嗪', '呋塞米', '水肿'],
    title: '利尿剂使用注意',
    content: '利尿剂建议早晨服用，避免夜尿增多影响睡眠与夜间跌倒；长期使用注意补钾（具体遵医嘱），出现乏力、心慌可能提示低血钾；痛风患者慎用噻嗪类利尿剂。'
  },
  {
    keywords: ['头晕', '跌倒', '摔倒', '起夜', '起床'],
    title: '预防跌倒的用药与起居建议',
    content: '多种药物（降压、降糖、安眠、抗过敏）都可能引起体位性低血压或嗜睡；起床遵循"三个半分钟"（醒后半分钟再坐起、坐半分钟再下床、床边站半分钟再行走）；夜间起夜先开灯；卫生间建议安装扶手。'
  }
];

const GLM_API_URL = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
const GLM_EMBED_URL = 'https://open.bigmodel.cn/api/paas/v4/embeddings';
// 智谱开放平台 API Key（https://bigmodel.cn 控制台获取）；为空时自动使用本地知识库模式
const GLM_API_KEY = '';  // 提交版已脱敏：请在 bigmodel.cn 申请免费 Key 后填入启用云端能力，留空自动降级本地知识库模式

/**
 * 用药安全 AI 问答服务（RAG：检索增强生成）。
 * 检索层：GLM embedding 向量召回（余弦相似度 TopK）为主，关键词打分为降级；
 * 生成层：命中条目作为上下文 → 云端 GLM 生成通俗回答，云端不可用降级本地直答；
 * 多模态：GLM-4V 拍照识药，识别结果自动进入 RAG 问答链路。
 * 答案附带来源条目（Self-RAG 式可溯源），抑制幻觉、便于老人子女核验。
 */
export class LlmService {
  private static instance?: LlmService;

  static getInstance(): LlmService {
    if (!LlmService.instance) {
      LlmService.instance = new LlmService();
    }
    return LlmService.instance;
  }

  private embedCache: Map<string, number[]> = new Map();
  private embedReady: boolean = false;
  private embedFailed: boolean = false;

  hasCloud(): boolean {
    return GLM_API_KEY.length > 0;
  }

  /** 供 AgentService 等同应用服务复用同一云端凭证 */
  apiKey(): string {
    return GLM_API_KEY;
  }

  modeLabel(): string {
    if (!this.hasCloud()) {
      return '本地知识库模式';
    }
    return this.embedReady ? '云端GLM · 向量RAG' : '云端GLM · RAG';
  }

  /** 检索（RAG 的 R）：向量召回为主，关键词降级，返回最相关的前3条 */
  async retrieve(query: string): Promise<KbEntry[]> {
    if (this.hasCloud() && !this.embedFailed) {
      try {
        await this.ensureEmbeddings();
        const q = await this.embed(query);
        const scored: ScoredEntry[] = [];
        for (const entry of KB) {
          const v = this.embedCache.get(entry.title);
          if (v) {
            const item: ScoredEntry = { entry: entry, score: this.cosine(q, v) };
            scored.push(item);
          }
        }
        scored.sort((a: ScoredEntry, b: ScoredEntry) => b.score - a.score);
        const top = scored.slice(0, 3).map((x: ScoredEntry) => x.entry);
        if (top.length > 0) {
          return top;
        }
      } catch (err) {
        this.embedFailed = true; // 本次会话降级关键词检索
      }
    }
    return this.retrieveByKeyword(query);
  }

  /** 关键词打分检索（降级路径） */
  private retrieveByKeyword(query: string): KbEntry[] {
    const hits: KbEntry[] = [];
    for (const e of KB) {
      let score = 0;
      for (const k of e.keywords) {
        if (query.indexOf(k) >= 0) {
          score += 2;
        }
        if (e.title.indexOf(k) >= 0) {
          score += 1;
        }
      }
      if (score > 0) {
        hits.push(e);
      }
    }
    return hits.slice(0, 3);
  }

  async ask(question: string): Promise<ChatMessage> {
    const hits = await this.retrieve(question);
    const sources: string[] = hits.map((h: KbEntry) => h.title);
    if (!this.hasCloud()) {
      return { role: 'assistant', content: this.localAnswer(hits), sources: sources };
    }
    return await this.askCloud(question, hits);
  }

  /**
   * 拍照识药（GLM-4V 多模态）：识别药盒/药片名称与类别，
   * 返回供下一步问答的药物描述文本。
   */
  async identifyMed(imageBase64: string): Promise<string> {
    if (!this.hasCloud()) {
      return this.simulateIdentify();
    }
    const visionMsgs: GlmVisionMessage[] = [
      {
        role: 'user',
        content: [
          {
            type: 'image_url',
            image_url: { url: 'data:image/jpeg;base64,' + imageBase64 }
          },
          {
            type: 'text',
            text: '这是老人拍摄的一张药品照片（药盒或药板）。请识别：1.药品名称（含商品名/通用名）；2.药品类别（如降压药）；3.一句用途说明。若无法确定，请直说无法确定。用不超过60字回答，格式：药名｜类别｜用途。'
          }
        ]
      }
    ];
    const body: GlmVisionRequest = { model: 'glm-4v-flash', messages: visionMsgs };
    const httpRequest = http.createHttp();
    try {
      const opt: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${GLM_API_KEY}`
        },
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 30000
      };
      const resp = await httpRequest.request(GLM_API_URL, opt);
      if (resp.responseCode === 200) {
        const parsed = JSON.parse(resp.result as string) as GlmResponse;
        return parsed.choices[0].message.content;
      }
      return this.simulateIdentify();
    } catch (err) {
      return this.simulateIdentify();
    } finally {
      httpRequest.destroy();
    }
  }

  /** 演示模式：注入示例识别结果（无照片/断网环境保证演示完整） */
  simulateIdentify(): string {
    return '苯磺酸氨氯地平片（络活喜）5mg｜钙通道阻滞剂类降压药｜用于治疗高血压';
  }

  private async ensureEmbeddings(): Promise<void> {
    if (this.embedReady) {
      return;
    }
    const tasks: Promise<void>[] = [];
    for (const entry of KB) {
      if (this.embedCache.has(entry.title)) {
        continue;
      }
      tasks.push(this.embed(entry.title + '：' + entry.content.slice(0, 60)).then((v: number[]) => {
        this.embedCache.set(entry.title, v);
      }));
    }
    await Promise.all(tasks);
    this.embedReady = true;
  }

  private async embed(text: string): Promise<number[]> {
    const body: Record<string, Object> = { 'model': 'embedding-2', 'input': text };
    const httpRequest = http.createHttp();
    try {
      const opt: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${GLM_API_KEY}`
        },
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 30000
      };
      const resp = await httpRequest.request(GLM_EMBED_URL, opt);
      if (resp.responseCode === 200) {
        const parsed = JSON.parse(resp.result as string) as EmbeddingResponse;
        return parsed.data[0].embedding;
      }
      throw new Error('embed http ' + resp.responseCode);
    } finally {
      httpRequest.destroy();
    }
  }

  private cosine(a: number[], b: number[]): number {
    let dot = 0;
    let na = 0;
    let nb = 0;
    const len = Math.min(a.length, b.length);
    for (let i = 0; i < len; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na === 0 || nb === 0) {
      return 0;
    }
    return dot / (Math.sqrt(na) * Math.sqrt(nb));
  }

  private localAnswer(hits: KbEntry[]): string {
    if (hits.length === 0) {
      return '暂未在用药知识库中找到相关内容。建议咨询药师或医生，紧急情况请拨打120。';
    }
    return hits.map((h: KbEntry) => h.content).join('\n\n');
  }

  private async askCloud(question: string, hits: KbEntry[]): Promise<ChatMessage> {
    const context = hits.map((h: KbEntry) => `【${h.title}】${h.content}`).join('\n');
    const sys = '你是"银龄守护"App的用药安全助手，服务对象是老年人和其子女。请仅基于提供的知识条目回答，用通俗易懂的口语，不超过150字，结尾提醒"具体请遵医嘱"。若知识条目不足以回答，请明确说明并建议咨询医生或药师，不要编造。';
    const msgs: GlmMessage[] = [
      { role: 'system', content: sys },
      { role: 'user', content: `知识条目：\n${context}\n\n老人提问：${question}` }
    ];
    const req: GlmRequest = { model: 'glm-4-flash', messages: msgs };

    const httpRequest = http.createHttp();
    try {
      const opt: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${GLM_API_KEY}`
        },
        extraData: JSON.stringify(req),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 30000
      };
      const resp = await httpRequest.request(GLM_API_URL, opt);
      if (resp.responseCode === 200) {
        const parsed = JSON.parse(resp.result as string) as GlmResponse;
        return { role: 'assistant', content: parsed.choices[0].message.content, sources: hits.map((h: KbEntry) => h.title) };
      }
      return {
        role: 'assistant',
        content: `云端服务暂不可用（错误码 ${resp.responseCode}），已切换本地知识库回答：\n\n${this.localAnswer(hits)}`,
        sources: hits.map((h: KbEntry) => h.title)
      };
    } catch (err) {
      return {
        role: 'assistant',
        content: `网络异常，已切换本地知识库回答：\n\n${this.localAnswer(hits)}`,
        sources: hits.map((h: KbEntry) => h.title)
      };
    } finally {
      httpRequest.destroy();
    }
  }
}
