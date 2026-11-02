import { ChatMessage } from '../model/Models';
import { LlmService } from './LlmService';
import { http } from '@kit.NetworkKit';

interface GlmMessage {
  role: string;
  content: string;
}

interface GlmChoice {
  message: GlmMessage;
}

interface GlmResponse {
  choices: GlmChoice[];
}

/** Agent 执行计划：检索主题列表（GLM 结构化输出） */
interface AgentPlan {
  retrievalQueries: string[];
}

/** Agent 过程步骤（对话流中可视化展示"思考-行动"链） */
export interface AgentStep {
  icon: string;
  title: string;
  detail: string;
}

const GLM_API_URL = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';

/**
 * 用药管家 Agent：ReAct 式多步任务编排（AI 工作流）。
 * 步骤：① 规划（GLM 将老人自然语言目标拆解为检索主题）
 *      ② 行动（逐主题向量检索本地药师知识库）
 *      ③ 综合（多主题上下文受控生成，附全部来源）
 * 过程步骤通过 onStep 实时回调在对话流可视化，评审可完整看到
 * Agent 的"分析 → 检索 → 生成"链路，而非黑盒一问一答。
 */
export class AgentService {
  private static instance?: AgentService;

  static getInstance(): AgentService {
    if (!AgentService.instance) {
      AgentService.instance = new AgentService();
    }
    return AgentService.instance;
  }

  private llm: LlmService = LlmService.getInstance();

  /** 执行一次多步管家任务；onStep 每步实时回调用于界面展示 */
  async runTask(goal: string, onStep: (s: AgentStep) => void): Promise<ChatMessage> {
    // 步骤1：规划——把自然语言目标拆解为 2-4 个检索主题
    onStep({ icon: '🤔', title: '分析需求', detail: '正在理解您的目标并制定检索计划…' });
    let queries: string[] = [];
    try {
      const plan = await this.plan(goal);
      queries = plan.retrievalQueries;
    } catch (err) {
      queries = [goal];
    }
    if (queries.length === 0) {
      queries = [goal];
    }
    onStep({
      icon: '🧭',
      title: '检索计划',
      detail: queries.map((q: string, i: number) => `${i + 1}. ${q}`).join('　')
    });

    // 步骤2：行动——逐主题向量检索
    const hitTitles: string[] = [];
    const contexts: string[] = [];
    for (const q of queries) {
      const hits = await this.llm.retrieve(q);
      for (const h of hits) {
        if (hitTitles.indexOf(h.title) < 0) {
          hitTitles.push(h.title);
          contexts.push(`【${h.title}】${h.content}`);
        }
      }
    }
    onStep({
      icon: '📚',
      title: '知识检索',
      detail: `命中 ${hitTitles.length} 条：` + hitTitles.slice(0, 4).join('、')
    });

    // 步骤3：综合——多主题上下文受控生成
    onStep({ icon: '✍️', title: '生成建议', detail: '正在综合以上知识生成安全建议…' });
    const answer = await this.generate(goal, contexts);
    return answer;
  }

  private async plan(goal: string): Promise<AgentPlan> {
    const sys = '你是用药安全助手的任务规划器。将老人的自然语言目标拆解为2-4个知识库检索主题。只输出JSON，格式：{"retrievalQueries":["主题1","主题2"]}。主题要覆盖目标中涉及的所有药物与场景。';
    const content = await this.callGlm([
      { role: 'system', content: sys },
      { role: 'user', content: '老人目标：' + goal }
    ]);
    const start = content.indexOf('{');
    const end = content.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw new Error('plan parse failed');
    }
    const parsed = JSON.parse(content.slice(start, end + 1)) as AgentPlan;
    return parsed;
  }

  private async generate(goal: string, contexts: string[]): Promise<ChatMessage> {
    if (contexts.length === 0) {
      return {
        role: 'assistant',
        content: '知识库中未检索到足够依据。请咨询医生或药师，紧急情况拨打120。',
        sources: [] as string[]
      };
    }
    const sys = '你是"银龄守护"的用药管家，服务老年人和子女。基于给出的多条知识，给出分点的行动建议（选药方向、禁忌、何时就医），口语化，不超过200字，结尾提醒"具体请遵医嘱"。仅基于知识内容，不要编造。';
    const user = `知识条目：\n${contexts.join('\n')}\n\n老人目标：${goal}`;
    const content = await this.callGlm([
      { role: 'system', content: sys },
      { role: 'user', content: user }
    ]);
    // 来源从检索命中的标题还原
    const sources: string[] = [];
    for (const c of contexts) {
      const m = c.match(/【(.+?)】/);
      if (m && m.length > 1) {
        sources.push(m[1]);
      }
    }
    return { role: 'assistant', content: content, sources: sources };
  }

  private async callGlm(messages: GlmMessage[]): Promise<string> {
    const req: Record<string, Object> = {
      'model': 'glm-4-flash',
      'messages': messages
    };
    const httpRequest = http.createHttp();
    try {
      const opt: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + this.llm.apiKey()
        },
        extraData: JSON.stringify(req),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 30000
      };
      const resp = await httpRequest.request(GLM_API_URL, opt);
      if (resp.responseCode === 200) {
        const parsed = JSON.parse(resp.result as string) as GlmResponse;
        return parsed.choices[0].message.content;
      }
      throw new Error('glm http ' + resp.responseCode);
    } finally {
      httpRequest.destroy();
    }
  }
}
