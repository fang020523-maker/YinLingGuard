import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { GuardStore } from '../service/GuardStore';
import { NotifyService } from '../service/NotifyService';

const DOMAIN: number = 0x0000;
const TAG: string = 'YinLingGuard';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
    GuardStore.getInstance().init(this.context);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
      this.requestDistributedPermission();
    });
  }

  /** 分布式跨设备同步为用户授权级权限：进入首页后弹出授权框 */
  private requestDistributedPermission(): void {
    const permissions: Array<Permissions> = ['ohos.permission.DISTRIBUTED_DATASYNC'];
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      atManager.requestPermissionsFromUser(this.context, permissions).then((result) => {
        hilog.info(DOMAIN, TAG, 'distributed permission: %{public}d', result.authResults[0]);
      }).catch(() => {
        hilog.info(DOMAIN, TAG, 'distributed permission request dismissed');
      });
    } catch (err) {
      hilog.info(DOMAIN, TAG, 'permission request failed');
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
    // 通知开关授权（告警通知的前提；用户拒绝时不阻塞应用）
    NotifyService.getInstance().requestEnable(this.context);
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
}
