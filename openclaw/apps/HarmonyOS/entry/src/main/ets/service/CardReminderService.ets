import { formProvider, formBindingData } from '@kit.FormKit';
import { InvokeRequest, InvokeResult } from '../api/GatewaySession';

export class ReminderCardContent {
  title: string = '';
  body: string = '';
  note: string = '';
  imageUrl: string = '';
}

export class CardReminderService {
  private formIds: string[] = [];
  private currentContent: ReminderCardContent;

  constructor() {
    this.currentContent = new ReminderCardContent();
    this.currentContent.title = '';
    this.currentContent.body = '当前无主动提醒';
    this.currentContent.note = '';
    this.currentContent.imageUrl = '';
  }

  getCurrentContent(): ReminderCardContent {
    return this.currentContent;
  }

  addFormId(formId: string): void {
    const trimmed = formId.trim();
    if (trimmed.length === 0) {
      return;
    }
    if (this.formIds.indexOf(trimmed) < 0) {
      this.formIds.push(trimmed);
      console.info('CardReminderService: added formId=' + trimmed);
    }
  }

  removeFormId(formId: string): void {
    const trimmed = formId.trim();
    const index = this.formIds.indexOf(trimmed);
    if (index >= 0) {
      this.formIds.splice(index, 1);
      console.info('CardReminderService: removed formId=' + trimmed);
    }
  }

  /**
   * 向单个 formId 推送当前内容。用于 onAddForm 时立即填充新卡片。
   */
  pushCurrentToForm(formId: string): void {
    if (!formId || formId.trim().length === 0) {
      return;
    }
    try {
      const bindingData = this.buildFormBindingData();
      formProvider.updateForm(formId, bindingData);
      console.info('CardReminderService: pushed current content to formId=' + formId);
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : 'Unknown error';
      console.warn('CardReminderService: pushCurrentToForm failed for formId=' + formId + ', error=' + errorMsg);
    }
  }

  updateReminderCard(content: ReminderCardContent): void {
    this.currentContent = content;
    this.pushToAllForms();
    console.info(
      'CardReminderService: updateReminderCard, title=' + content.title +
      ', body=' + content.body + ', note=' + content.note +
      ', imageUrl=' + content.imageUrl
    );
  }

  resetToDefault(): void {
    const defaultContent = new ReminderCardContent();
    defaultContent.title = '';
    defaultContent.body = '当前无主动提醒';
    defaultContent.note = '';
    defaultContent.imageUrl = '';
    this.updateReminderCard(defaultContent);
  }

  handleUpdateReminderCommand(request: InvokeRequest): InvokeResult {
    const paramsJson = request.paramsJson.trim();
    if (paramsJson.length === 0) {
      return InvokeResult.error('INVALID_PARAMS', 'Missing paramsJson for card.reminder.update');
    }

    try {
      const parsed = JSON.parse(paramsJson) as Record<string, string>;
      const content = new ReminderCardContent();
      content.title = (parsed['title'] || '').trim();
      content.body = (parsed['body'] || '').trim();
      content.note = (parsed['note'] || '').trim();
      content.imageUrl = (parsed['imageUrl'] || '').trim();

      if (content.body.length === 0) {
        return InvokeResult.error('INVALID_PARAMS', 'body is required for card.reminder.update');
      }

      this.updateReminderCard(content);
      return InvokeResult.ok(JSON.stringify({ ok: true, formIdsCount: this.formIds.length }));
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : 'Invalid JSON';
      return InvokeResult.error('INVALID_PARAMS', 'Failed to parse paramsJson: ' + errorMsg);
    }
  }

  private pushToAllForms(): void {
    if (this.formIds.length === 0) {
      console.info('CardReminderService: no formIds registered, skipping push');
      return;
    }

    const bindingData = this.buildFormBindingData();

    for (let i = 0; i < this.formIds.length; i++) {
      const formId = this.formIds[i];
      try {
        formProvider.updateForm(formId, bindingData);
        console.info('CardReminderService: pushed update to formId=' + formId);
      } catch (error) {
        const errorMsg = error instanceof Error ? error.message : 'Unknown error';
        console.warn('CardReminderService: updateForm failed for formId=' + formId + ', error=' + errorMsg);
        if (errorMsg.includes('not found') || errorMsg.includes('deleted') || errorMsg.includes('invalid')) {
          this.formIds.splice(i, 1);
          i--;
          console.info('CardReminderService: pruned invalid formId=' + formId);
        }
      }
    }
  }

  /**
   * 构建当前内容的 FormBindingData 对象。供 ReminderFormExtension.onAddForm 调用。
   */
  buildCurrentFormBindingData(): formBindingData.FormBindingData {
    return this.buildFormBindingData();
  }

  private buildFormBindingData(): formBindingData.FormBindingData {
    const data: Record<string, string> = {
      'title': this.currentContent.title,
      'body': this.currentContent.body,
      'note': this.currentContent.note,
      'imageUrl': this.currentContent.imageUrl,
      'hasImage': this.currentContent.imageUrl.length > 0 ? 'true' : 'false',
      'hasNote': this.currentContent.note.length > 0 ? 'true' : 'false'
    };
    return formBindingData.createFormBindingData(data);
  }
}

export const cardReminderService = new CardReminderService();
