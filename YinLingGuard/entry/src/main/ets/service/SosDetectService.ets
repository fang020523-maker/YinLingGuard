import { speechRecognizer } from '@kit.CoreSpeechKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'YinLingSos';
const DOMAIN = 0x0000;

/** 求救关键词表：命中任一即触发告警 */
const SOS_KEYWORDS: string[] = ['救命', '摔倒了', '摔倒了', '救救我', '帮帮我', '不好了', '疼'];

/**
 * 语音求救识别服务（Core Speech Kit 端侧短语音识别）。
 * 对应创新叙事：跌倒后老人无法起身触屏时，喊"救命"即可触发告警——
 * 多模态感知的"语音模态"补充（加速度 + 语音双通道互补，覆盖未触发传感器阈值或无法操作屏幕的场景）。
 * 识别在端侧完成，语音原文不出设备，仅命中的关键词事件外发。
 */
export class SosDetectService {
  private static instance?: SosDetectService;

  static getInstance(): SosDetectService {
    if (!SosDetectService.instance) {
      SosDetectService.instance = new SosDetectService();
    }
    return SosDetectService.instance;
  }

  private engine?: speechRecognizer.SpeechRecognitionEngine;
  private started: boolean = false;
  private listener?: (text: string) => void;

  setListener(l: (text: string) => void): void {
    this.listener = l;
  }

  isStarted(): boolean {
    return this.started;
  }

  async start(): Promise<void> {
    if (this.started) {
      return;
    }
    const extra: Record<string, Object> = {
      'locate': 'CN',
      'recognizerMode': 'short',
      // 系统热词：将求救关键词注册为热词可显著提升端侧识别率
      'sysGeneralLexicon': SOS_KEYWORDS
    };
    const params: speechRecognizer.CreateEngineParams = {
      language: 'zh-CN',
      online: 1,
      extraParams: extra
    };
    try {
      this.engine = await speechRecognizer.createEngine(params);
      const listener: speechRecognizer.RecognitionListener = {
        onStart: (sessionId: string, eventMessage: string) => {
          hilog.info(DOMAIN, TAG, 'recognition started');
        },
        onEvent: (sessionId: string, eventCode: number, eventMessage: string) => {
        },
        onResult: (sessionId: string, result: speechRecognizer.SpeechRecognitionResult) => {
          this.match(result.result);
        },
        onComplete: (sessionId: string, eventMessage: string) => {
          // 短语音模式单轮结束：自动开启下一轮，持续守护
          this.restart();
        },
        onError: (sessionId: string, errorCode: number, errorMessage: string) => {
          hilog.warn(DOMAIN, TAG, 'recognition error %{public}d', errorCode);
          this.started = false;
        }
      };
      this.engine.setListener(listener);
      this.beginSession();
      this.started = true;
      hilog.info(DOMAIN, TAG, 'sos detect ready');
    } catch (err) {
      this.started = false;
      hilog.warn(DOMAIN, TAG, 'create engine failed, sos detect unavailable');
    }
  }

  stop(): void {
    if (this.engine) {
      try {
        this.engine.shutdown();
      } catch (err) {
        // 引擎已失效时忽略
      }
      this.engine = undefined;
    }
    this.started = false;
  }

  /** 演示模式：注入一次识别结果（评审演示 / 无麦克风环境） */
  simulate(text: string): void {
    this.match(text);
  }

  private beginSession(): void {
    if (!this.engine) {
      return;
    }
    try {
      const listenParams: speechRecognizer.StartParams = {
        sessionId: Date.now().toString(),
        audioInfo: {
          audioType: 'pcm',
          sampleRate: 16000,
          soundChannel: 1,
          sampleBit: 16
        }
      };
      this.engine.startListening(listenParams);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'startListening failed');
    }
  }

  private restart(): void {
    if (!this.started) {
      return;
    }
    this.beginSession();
  }

  private match(text: string): void {
    if (!text || text.length === 0) {
      return;
    }
    for (const k of SOS_KEYWORDS) {
      if (text.indexOf(k) >= 0) {
        hilog.info(DOMAIN, TAG, 'sos keyword hit');
        if (this.listener) {
          this.listener(text);
        }
        return;
      }
    }
  }
}
