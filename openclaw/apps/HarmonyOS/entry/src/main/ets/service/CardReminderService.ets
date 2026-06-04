import { formProvider, formBindingData, formInfo } from '@kit.FormKit';
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

  getFormIdsCount(): number {
    return this.formIds.length;
  }

  addFormId(formId: string): void {
    const trimmed = formId.trim();
    if (trimmed.length === 0) return;
    if (this.formIds.indexOf(trimmed) < 0) {
      this.formIds.push(trimmed);
      console.info('CardReminderService: added formId=' + trimmed + ', total=' + this.formIds.length);
    }
  }

  removeFormId(formId: string): void {
    const trimmed = formId.trim();
    const index = this.formIds.indexOf(trimmed);
    if (index >= 0) {
      this.formIds.splice(index, 1);
      console.info('CardReminderService: removed formId=' + trimmed + ', total=' + this.formIds.length);
    }
  }

  pushCurrentToForm(formId: string): void {
    if (!formId || formId.trim().length === 0) return;
    const bindingData = this.buildFormBindingData();
    formProvider.updateForm(formId, bindingData)
      .then(() => console.info('CardReminderService: pushed to formId=' + formId))
      .catch((err: Error) => console.warn('CardReminderService: push failed ' + err.message));
  }

  updateReminderCard(content: ReminderCardContent): void {
    this.currentContent = content;
    console.info('CardReminderService: update, title=' + content.title + ', body=' + content.body +
      ', note=' + content.note + ', formIdsCount=' + this.formIds.length);
    if (this.formIds.length === 0) {
      this.refreshFormIds().then(() => {
        if (this.formIds.length > 0) this.pushToAllForms();
      });
    } else {
      this.pushToAllForms();
    }
  }

  resetToDefault(): void {
    const c = new ReminderCardContent();
    c.body = '当前无主动提醒';
    this.updateReminderCard(c);
  }

  handleUpdateReminderCommand(request: InvokeRequest): InvokeResult {
    const paramsJson = request.paramsJson.trim();
    if (paramsJson.length === 0) {
      return InvokeResult.error('INVALID_PARAMS', 'Missing paramsJson');
    }
    try {
      const parsed = JSON.parse(paramsJson) as Record<string, string>;
      const content = new ReminderCardContent();
      content.title = (parsed['title'] || '').trim();
      content.body = (parsed['body'] || '').trim();
      content.note = (parsed['note'] || '').trim();
      content.imageUrl = (parsed['imageUrl'] || '').trim();
      if (content.body.length === 0) {
        return InvokeResult.error('INVALID_PARAMS', 'body is required');
      }
      this.updateReminderCard(content);
      return InvokeResult.ok(JSON.stringify({ ok: true, formIdsCount: this.formIds.length }));
    } catch (e) {
      return InvokeResult.error('INVALID_PARAMS', 'Failed to parse paramsJson');
    }
  }

  buildCurrentFormBindingData(): formBindingData.FormBindingData {
    return this.buildFormBindingData();
  }

  private async refreshFormIds(): Promise<void> {
    try {
      const forms: formInfo.RunningFormInfo[] = await formProvider.getPublishedRunningFormInfos();
      for (let i = 0; i < forms.length; i++) {
        this.addFormId(forms[i].formId);
      }
    } catch (e) {
      console.error('CardReminderService: refreshFormIds failed');
    }
  }

  private pushToAllForms(): void {
    const bindingData = this.buildFormBindingData();
    for (let i = 0; i < this.formIds.length; i++) {
      const formId = this.formIds[i];
      formProvider.updateForm(formId, bindingData)
        .then(() => console.info('CardReminderService: pushed to formId=' + formId))
        .catch((err: Error) => {
          if (err.message.includes('not found') || err.message.includes('deleted')) {
            this.formIds.splice(i, 1);
            i--;
          }
        });
    }
  }

  private buildFormBindingData(): formBindingData.FormBindingData {
    const data: Record<string, string> = {
      'title': this.currentContent.title,
      'body': this.currentContent.body,
      'note': this.currentContent.note,
      'imageUrl': this.currentContent.imageUrl,
      'hasImage': this.currentContent.imageUrl.length > 0 ? 'true' : 'false'
    };
    return formBindingData.createFormBindingData(data);
  }
}

export const cardReminderService = new CardReminderService();
