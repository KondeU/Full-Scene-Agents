import { formProvider, formBindingData, formInfo } from '@kit.FormKit';
import { InvokeRequest, InvokeResult } from '../api/GatewaySession';
import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';

const IMG_KEY: string = 'cardImage';

export class ReminderCardContent {
  title: string = '';
  body: string = '';
  note: string = '';
  imageUrl: string = '';
  style: string = '';   // '' | 'infoShowTitleBodyNoteImage' | 'infoShowTitleImageAndImport'
  skill: string = '';   // 可选，拍/选图片后发送给 chat 的技能文本。空则默认 '/ImageData'
}

export class CardReminderService {
  private formIds: string[] = [];
  private currentContent: ReminderCardContent;
  private currentImagePath: string = '';

  constructor() {
    this.currentContent = new ReminderCardContent();
    this.currentContent.body = '当前无主动提醒';
  }

  getCurrentContent(): ReminderCardContent { return this.currentContent; }
  getFormIdsCount(): number { return this.formIds.length; }

  addFormId(formId: string): void {
    const t = formId.trim();
    if (t.length === 0) return;
    if (this.formIds.indexOf(t) < 0) {
      this.formIds.push(t);
      console.info('CardReminderService: added formId=' + t + ', total=' + this.formIds.length);
    }
  }

  removeFormId(formId: string): void {
    const t = formId.trim();
    const idx = this.formIds.indexOf(t);
    if (idx >= 0) {
      this.formIds.splice(idx, 1);
      console.info('CardReminderService: removed formId=' + t + ', total=' + this.formIds.length);
    }
  }

  pushCurrentToForm(formId: string): void {
    if (!formId || formId.trim().length === 0) return;
    this.pushToForm(formId);
  }

  updateReminderCard(content: ReminderCardContent): void {
    this.currentContent = content;
    // skill 不参与卡片渲染，存入 AppStorage 供拍照/选图后 sendChat 构造消息文本
    AppStorage.setOrCreate<string>('cardSkill', content.skill);
    console.info('CardReminderService: update ' +
      'title=' + content.title + ' body=' + content.body +
      ' note=' + content.note + ' imageUrl=' + content.imageUrl +
      ' style=' + content.style + ' skill=' + content.skill +
      ' hasImage=' + (content.imageUrl.length > 0) +
      ' formIdsCount=' + this.formIds.length);

    this.refreshFormIds().then(() => {
      if (this.formIds.length > 0) this.doPush();
    });
  }

  resetToDefault(): void {
    const c = new ReminderCardContent();
    c.body = '当前无主动提醒';
    this.updateReminderCard(c);
  }

  handleUpdateReminderCommand(request: InvokeRequest): InvokeResult {
    const pj = request.paramsJson.trim();
    if (pj.length === 0) return InvokeResult.error('INVALID_PARAMS', 'Missing paramsJson');
    try {
      const p = JSON.parse(pj) as Record<string, string>;
      const content = new ReminderCardContent();
      content.title = (p['title'] || '').trim();
      content.body = (p['body'] || '').trim();
      content.note = (p['note'] || '').trim();
      content.imageUrl = (p['imageUrl'] || '').trim();
      content.style = (p['style'] || '').trim();
      content.skill = (p['skill'] || '').trim();
      if (content.body.length === 0) return InvokeResult.error('INVALID_PARAMS', 'body is required');
      this.updateReminderCard(content);
      return InvokeResult.ok(JSON.stringify({ ok: true, formIdsCount: this.formIds.length }));
    } catch (e) {
      return InvokeResult.error('INVALID_PARAMS', 'Failed to parse paramsJson');
    }
  }

  buildCurrentFormBindingData(): formBindingData.FormBindingData {
    return this.buildFormBindingData();
  }

  // ═══ 图片下载 ═══

  private async downloadImage(url: string): Promise<string> {
    const req = http.createHttp();
    try {
      console.info('CardReminderService: downloading ' + url);
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });
      if (resp.result instanceof ArrayBuffer && resp.result.byteLength > 0) {
        const ctx = AppStorage.get<Context>('abilityContext');
        const base = ctx ? ctx.tempDir : '/data/storage/el2/base/temp/';
        const path = base + '/reminder_' + Date.now() + '.img';
        const file = fileIo.openSync(path,
          fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
        try {
          fileIo.writeSync(file.fd, new Uint8Array(resp.result as ArrayBuffer).buffer);
        } finally {
          fileIo.closeSync(file);
        }
        console.info('CardReminderService: downloaded ' + resp.result.byteLength + ' bytes → ' + path);
        return path;
      }
      console.warn('CardReminderService: download empty');
    } catch (e) {
      console.error('CardReminderService: download failed: ' + (e as BusinessError).message);
    } finally {
      req.destroy();
    }
    return '';
  }

  private cleanupImage(): void {
    if (this.currentImagePath.length === 0) return;
    try {
      fileIo.unlinkSync(this.currentImagePath);
      console.info('CardReminderService: deleted old image ' + this.currentImagePath);
    } catch (e) {
      console.warn('CardReminderService: cleanup failed: ' + (e as Error).message);
    }
    this.currentImagePath = '';
  }

  // ═══ 推送 ═══

  private doPush(): void {
    if (this.currentContent.imageUrl.length > 0) {
      this.downloadAndPush();
    } else {
      this.cleanupImage();
      this.pushToAllForms();
    }
  }

  private async downloadAndPush(): Promise<void> {
    const url = this.currentContent.imageUrl;
    if (url.length === 0) return;
    const local = await this.downloadImage(url);
    if (local.length > 0) {
      this.cleanupImage();
      this.currentImagePath = local;
    }
    this.pushToAllForms();
  }

  private async refreshFormIds(): Promise<void> {
    try {
      const list: formInfo.RunningFormInfo[] = await formProvider.getPublishedRunningFormInfos();
      for (let i = 0; i < list.length; i++) {
        this.addFormId(list[i].formId);
      }
    } catch (e) {
      console.error('CardReminderService: refreshFormIds failed');
    }
  }

  private pushToForm(formId: string): void {
    const bd = this.buildFormBindingData();
    formProvider.updateForm(formId, bd)
      .then(() => console.info('CardReminderService: pushed to formId=' + formId))
      .catch((e: Error) => console.warn('CardReminderService: push failed ' + e.message));
  }

  private pushToAllForms(): void {
    const bd = this.buildFormBindingData();
    for (let i = 0; i < this.formIds.length; i++) {
      const fid = this.formIds[i];
      formProvider.updateForm(fid, bd)
        .then(() => console.info('CardReminderService: pushed to formId=' + fid))
        .catch((err: Error) => {
          if (err.message.includes('not found') || err.message.includes('deleted')) {
            this.formIds.splice(i, 1);
            i--;
          }
        });
    }
  }

  private buildFormBindingData(): formBindingData.FormBindingData {
    const hasImg = this.currentImagePath.length > 0;
    const data: Record<string, Object> = {
      'title': this.currentContent.title,
      'body': this.currentContent.body,
      'note': this.currentContent.note,
      'hasImage': hasImg ? 'true' : 'false',
      'style': this.currentContent.style.length > 0 ? this.currentContent.style : 'infoShowTitleBodyNoteImage'
    };
    if (hasImg) {
      try {
        const imgFile = fileIo.openSync(this.currentImagePath, fileIo.OpenMode.READ_ONLY);
        data['imgSrc'] = IMG_KEY;
        let formImages: Record<string, number> = {};
        formImages[IMG_KEY] = imgFile.fd;
        data['formImages'] = formImages;
      } catch (e) {
        console.warn('CardReminderService: cannot open image file ' + this.currentImagePath + ': ' + (e as Error).message);
        // 文件已损坏或被系统清理，回退到无图模式
        this.currentImagePath = '';
        data['hasImage'] = 'false';
      }
    }
    return formBindingData.createFormBindingData(data);
  }
}

export const cardReminderService = new CardReminderService();
