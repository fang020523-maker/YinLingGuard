import { notificationManager } from '@kit.NotificationKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'YinLingNotify';
const DOMAIN = 0x0000;

/**
 * 告警系统通知服务（Notification Kit 本地通知）。
 * 告警升级时发布系统级通知，即使应用在后台家属也能在通知栏/手表看到。
 * Push Kit 云端推送在真机上架阶段接入（需 AGC 开通推送服务与证书），
 * 当前本地通知已覆盖"应用后台仍可感知"的核心体验，且模拟器可完整验证。
 */
export class NotifyService {
  private static instance?: NotifyService;

  static getInstance(): NotifyService {
    if (!NotifyService.instance) {
      NotifyService.instance = new NotifyService();
    }
    return NotifyService.instance;
  }

  /** 首次启动请求通知开关授权（用户可在设置中更改） */
  async requestEnable(context: common.UIAbilityContext): Promise<void> {
    try {
      await notificationManager.requestEnableNotification(context);
    } catch (err) {
      hilog.info(DOMAIN, TAG, 'notification not enabled');
    }
  }

  async sendAlertNotify(title: string, detail: string): Promise<void> {
    try {
      const request: notificationManager.NotificationRequest = {
        id: Date.now(),
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: detail,
            additionalText: '点击查看家人看板'
          }
        }
      };
      await notificationManager.publish(request);
      hilog.info(DOMAIN, TAG, 'alert notification published');
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'publish notification failed');
    }
  }
}
