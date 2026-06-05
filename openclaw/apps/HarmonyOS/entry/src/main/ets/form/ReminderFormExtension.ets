import { FormExtensionAbility, formBindingData } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { cardReminderService } from '../service/CardReminderService';

export default class ReminderFormExtension extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId = want.parameters?.['ohos.extra.param.key.form_identity'] as string || '';
    console.info('ReminderFormExtension: onAddForm, formId=' + formId);
    if (formId.length > 0) {
      cardReminderService.addFormId(formId);
      cardReminderService.pushCurrentToForm(formId);
    }
    return cardReminderService.buildCurrentFormBindingData();
  }

  onUpdateForm(formId: string): void {
    // 卡片内容由主应用侧的 cardReminderService.updateReminderCard() 通过
    // formProvider.updateForm() 直接推送。FormExtension 运行在独立进程，
    // 其 cardReminderService 实例不会被主应用更新，在此推送会覆盖已有内容。
    // onAddForm 时已推送过当前内容，后续由主应用手动更新即可。
    console.info('ReminderFormExtension: onUpdateForm, formId=' + formId + ' (no-op)');
  }

  onRemoveForm(formId: string): void {
    console.info('ReminderFormExtension: onRemoveForm, formId=' + formId);
    cardReminderService.removeFormId(formId);
  }

  onFormEvent(formId: string, message: string): void {
    console.info('ReminderFormExtension: onFormEvent, formId=' + formId + ', message=' + message);
  }
}
