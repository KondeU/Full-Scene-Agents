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
    console.info('ReminderFormExtension: onUpdateForm, formId=' + formId);
    cardReminderService.pushCurrentToForm(formId);
  }

  onRemoveForm(formId: string): void {
    console.info('ReminderFormExtension: onRemoveForm, formId=' + formId);
    cardReminderService.removeFormId(formId);
  }

  onFormEvent(formId: string, message: string): void {
    console.info('ReminderFormExtension: onFormEvent, formId=' + formId + ', message=' + message);
  }
}
