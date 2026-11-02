import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { AlertEvent, AlertStatus, AlertType } from '../model/Models';

const DB_NAME = 'yinling.db';
const TABLE_ALERTS = 'alerts';
const CREATE_ALERTS = `CREATE TABLE IF NOT EXISTS ${TABLE_ALERTS} (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  status TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  detail TEXT,
  responseSec INTEGER
)`;

/**
 * 告警事件持久化层（RelationalStore）。
 * 应用重启后恢复告警记录，家属端历史可追溯；隐私边界不变——仅本机存储，不外发。
 */
export class AlertDb {
  private store?: relationalStore.RdbStore;

  async init(context: common.Context): Promise<void> {
    const cfg: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    this.store = await relationalStore.getRdbStore(context, cfg);
    await this.store.executeSql(CREATE_ALERTS);
  }

  async loadAll(): Promise<AlertEvent[]> {
    if (!this.store) {
      return [];
    }
    const pred = new relationalStore.RdbPredicates(TABLE_ALERTS);
    pred.orderByDesc('timestamp');
    const rs = await this.store.query(pred, ['id', 'type', 'status', 'timestamp', 'detail', 'responseSec']);
    const out: AlertEvent[] = [];
    try {
      while (rs.goToNextRow()) {
        const typeStr = rs.getString(rs.getColumnIndex('type'));
        const statusStr = rs.getString(rs.getColumnIndex('status'));
        out.push({
          id: rs.getString(rs.getColumnIndex('id')),
          type: typeStr as AlertType,
          status: statusStr as AlertStatus,
          timestamp: rs.getLong(rs.getColumnIndex('timestamp')),
          detail: rs.getString(rs.getColumnIndex('detail')),
          responseSec: rs.getLong(rs.getColumnIndex('responseSec'))
        });
      }
    } finally {
      rs.close();
    }
    return out;
  }

  async upsert(a: AlertEvent): Promise<void> {
    if (!this.store) {
      return;
    }
    const bucket: relationalStore.ValuesBucket = {
      'id': a.id,
      'type': a.type,
      'status': a.status,
      'timestamp': a.timestamp,
      'detail': a.detail,
      'responseSec': a.responseSec
    };
    await this.store.insert(TABLE_ALERTS, bucket, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }
}
