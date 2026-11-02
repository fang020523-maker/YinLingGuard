import { common } from '@kit.AbilityKit';
import { distributedKVStore } from '@kit.ArkData';
import { distributedDeviceManager } from '@kit.DistributedServiceKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AlertEvent } from '../model/Models';

const TAG = 'YinLingSync';
const DOMAIN = 0x0000;
const STORE_ID = 'yl_guard_store';
const KEY_HEALTH = 'yl_health';

export interface HealthPayload {
  hr: number;
  steps: number;
  guarding: boolean;
}

/**
 * 分布式同步服务（distributedKVStore）：
 * 老人端与家属端登录同一华为账号后自动组网，告警事件与健康摘要双向同步。
 * 前提：双方均已授权 ohos.permission.DISTRIBUTED_DATASYNC 且登录同一账号；
 * 未满足任一条件时优雅降级为纯本机模式，不影响任何现有功能。
 */
export class DistributedSync {
  private static instance?: DistributedSync;

  static getInstance(): DistributedSync {
    if (!DistributedSync.instance) {
      DistributedSync.instance = new DistributedSync();
    }
    return DistributedSync.instance;
  }

  private kvStore?: distributedKVStore.SingleKVStore;
  private ready: boolean = false;

  /** 远端数据变化回调（由 GuardStore 注入，避免服务层反向依赖） */
  onRemoteAlert?: (a: AlertEvent) => void;
  onRemoteHealth?: (h: HealthPayload) => void;

  async init(context: common.Context): Promise<void> {
    if (this.ready) {
      return;
    }
    try {
      const cfg: distributedKVStore.KVManagerConfig = {
        context: context,
        bundleName: 'com.yinling.guard'
      };
      const kvManager: distributedKVStore.KVManager = distributedKVStore.createKVManager(cfg);
      const options: distributedKVStore.Options = {
        createIfMissing: true,
        encrypt: false,
        backup: false,
        autoSync: true,
        kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,
        securityLevel: distributedKVStore.SecurityLevel.S1
      };
      this.kvStore = await kvManager.getKVStore<distributedKVStore.SingleKVStore>(STORE_ID, options);
      this.kvStore.on('dataChange', distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_REMOTE,
        (data: distributedKVStore.ChangeNotification) => {
          this.handleChange(data);
        });
      this.ready = true;
      hilog.info(DOMAIN, TAG, 'distributed sync ready');
    } catch (err) {
      // 未登录同账号/未授权/无分布式环境：降级为纯本机模式
      this.ready = false;
      hilog.info(DOMAIN, TAG, 'distributed sync unavailable, fallback to local mode');
    }
  }

  isReady(): boolean {
    return this.ready;
  }

  /** 推送告警事件到可信设备组 */
  putAlert(a: AlertEvent): void {
    if (!this.ready || !this.kvStore) {
      return;
    }
    this.kvStore.put('alert_' + a.id, JSON.stringify(a)).then(() => {
      this.syncAll();
    }).catch((err: object) => {
      hilog.warn(DOMAIN, TAG, 'putAlert failed');
    });
  }

  /** 推送健康摘要到可信设备组 */
  putHealth(h: HealthPayload): void {
    if (!this.ready || !this.kvStore) {
      return;
    }
    this.kvStore.put(KEY_HEALTH, JSON.stringify(h)).then(() => {
      this.syncAll();
    }).catch((err: object) => {
      hilog.warn(DOMAIN, TAG, 'putHealth failed');
    });
  }

  private syncAll(): void {
    if (!this.kvStore) {
      return;
    }
    try {
      const dm = distributedDeviceManager.createDeviceManager('com.yinling.guard');
      const devices = dm.getAvailableDeviceListSync();
      const ids: string[] = [];
      for (const d of devices) {
        if (d.networkId && d.networkId.length > 0) {
          ids.push(d.networkId);
        }
      }
      if (ids.length > 0) {
        this.kvStore.sync(ids, distributedKVStore.SyncMode.PUSH_PULL);
        hilog.info(DOMAIN, TAG, 'synced to %{public}d device(s)', ids.length);
      }
    } catch (err) {
      // 无对端设备或未登录：跳过同步
    }
  }

  private handleChange(data: distributedKVStore.ChangeNotification): void {
    for (const e of data.insertEntries.concat(data.updateEntries)) {
      try {
        if (e.key === KEY_HEALTH) {
          const h = JSON.parse(e.value.toString()) as HealthPayload;
          if (this.onRemoteHealth) {
            this.onRemoteHealth(h);
          }
        } else if (e.key.startsWith('alert_')) {
          const a = JSON.parse(e.value.toString()) as AlertEvent;
          if (this.onRemoteAlert) {
            this.onRemoteAlert(a);
          }
        }
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'handle change failed');
      }
    }
  }
}
