import { Want } from '@kit.AbilityKit';
import { FormExtensionAbility, formBindingData, formProvider } from '@kit.FormKit';
import { preferences } from '@kit.ArkData';

const CARD_PREF_NAME = 'yl_card_pref';

/**
 * 元服务桌面卡片能力：展示老人守护状态摘要。
 * 数据来源：GuardStore 写入的 Preferences（card_status/card_guarding），
 * 同应用跨进程可读；onAddForm/onUpdateForm 时刷新卡片数据。
 */
export default class EntryFormAbility extends FormExtensionAbility {
  private async readCardData(): Promise<Record<string, string>> {
    let status = '奶奶一切安好';
    let guarding = '守护中';
    try {
      const pref = await preferences.getPreferences(this.context, CARD_PREF_NAME);
      const s: preferences.ValueType = await pref.get('card_status', status);
      if (typeof s === 'string' && s.length > 0) {
        status = s;
      }
      const g: preferences.ValueType = await pref.get('card_guarding', true);
      if (typeof g === 'boolean' && !g) {
        guarding = '已暂停';
      }
    } catch (err) {
      // 无历史数据时使用默认文案
    }
    const data: Record<string, string> = { 'status': status, 'guarding': guarding };
    return data;
  }

  onAddForm(want: Want): formBindingData.FormBindingData {
    this.readCardData().then((data: Record<string, string>) => {
      const formId = want.parameters?.['ohos.extra.param.key.form_identity'] as string;
      if (formId && formId.length > 0) {
        formProvider.updateForm(formId, formBindingData.createFormBindingData(data));
      }
    }).catch(() => {
      // 忽略刷新失败，保留默认卡片内容
    });
    const init: Record<string, string> = { 'status': '奶奶一切安好', 'guarding': '守护中' };
    return formBindingData.createFormBindingData(init);
  }

  onUpdateForm(formId: string): void {
    this.readCardData().then((data: Record<string, string>) => {
      formProvider.updateForm(formId, formBindingData.createFormBindingData(data));
    }).catch(() => {
      // 忽略刷新失败
    });
  }

  onCastToNormal(formId: string): void {
    // 当前仅静态卡片，无需升级为常态卡片
  }

  onChangeFormVisibility(newStatus: Record<string, number>): void {
    // 可见性变化时无需特殊处理
  }

  onFormEvent(formId: string, message: string): void {
    // 卡片消息事件（后续可扩展一键呼叫按钮）
  }

  onRemoveForm(formId: string): void {
    // 卡片移除时无需清理
  }
}
