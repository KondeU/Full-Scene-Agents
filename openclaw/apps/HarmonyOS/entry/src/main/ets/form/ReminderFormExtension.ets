import { ExtensionAbility, Want } from '@kit.AbilityKit';
import { formBindingData } from '@kit.FormKit';
import { cardReminderService } from '../service/CardReminderService';

export default class ReminderFormExtension extends ExtensionAbility {
  onCreate(want: Want): void {
    console.info('ReminderFormExtension: onCreate');
    const formId = want.parameters?.['ohos.extra.param.key.form_identity'] as string || '';
    if (formId.length > 0) {
      console.info('ReminderFormExtension: onCreate, formId=' + formId);
      cardReminderService.addFormId(formId);
      cardReminderService.pushCurrentToForm(formId);
    }
  }

  onDestroy(): void {
    console.info('ReminderFormExtension: onDestroy');
  }
}
