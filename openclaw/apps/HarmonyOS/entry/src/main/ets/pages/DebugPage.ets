import { MainViewModel } from '../viewmodel/MainViewModel';
import { InvokeRequest } from '../api/GatewaySession';
import { ReminderCardContent, cardReminderService } from '../service/CardReminderService';

@Component
export struct DebugPage {
  @ObjectLink viewModel: MainViewModel;
  @StorageProp('localeVersion') localeVersion: number = 0;

  @State debugTitle: string = '';
  @State debugBody: string = '';
  @State debugNote: string = '';
  @State debugImageUrl: string = '';
  @State pushResult: string = '';
  @State currentCardState: string = '';

  aboutToAppear(): void {
    this.refreshCurrentCardState();
  }

  aboutToDisappear(): void {
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        this.Header();
        this.CardPreviewSection();
        this.PushFormSection();
        this.InvokeSimulateSection();
        this.CardStateSection();

        if (this.pushResult.length > 0) {
          this.PushResultRail();
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 24 });
    }
    .width('100%')
    .height('100%');
  }

  @Builder Header() {
    Column({ space: 6 }) {
      Text(this.localizedText('debug_header_eyebrow', 'DEBUG'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#C8841A');

      Text(this.localizedText('debug_header_title', 'Debug'))
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#17181C');

      Text(this.localizedText('debug_header_subtitle', 'Test card content, simulate invoke commands, and inspect device state.'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#4D5563');
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder CardPreviewSection() {
    Column({ space: 12 }) {
      Text(this.localizedText('debug_card_preview_label', 'CARD PREVIEW'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#C8841A');

      Column() {
        Row() {
          Column() {
            if (this.currentCardContent().title.length > 0) {
              Text(this.currentCardContent().title)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#17181C')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
            }

            Text(this.currentCardContent().body)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#4D5563')
              .maxLines(this.currentCardContent().imageUrl.length > 0 ? 3 : 5)
              .textOverflow({ overflow: TextOverflow.Ellipsis });

            if (this.currentCardContent().note.length > 0) {
              Text(this.currentCardContent().note)
                .fontSize(10)
                .fontWeight(FontWeight.Normal)
                .fontColor('#8A92A2')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
            }
          }
          .layoutWeight(this.currentCardContent().imageUrl.length > 0 ? 1 : 0)
          .width(this.currentCardContent().imageUrl.length > 0 ? '60%' : '100%')
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 14, right: 4, top: 14, bottom: 14 });

          if (this.currentCardContent().imageUrl.length > 0) {
            Image(this.currentCardContent().imageUrl)
              .width('38%')
              .height(120)
              .objectFit(ImageFit.Cover)
              .borderRadius(8)
              .alt($r('app.media.icon'));
          }
        }
        .width('100%');
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 14 })
      .backgroundColor('#FFFFFF')
      .borderRadius(14)
      .border({ width: 1, color: '#E5E7EC' });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder PushFormSection() {
    Column({ space: 12 }) {
      Text(this.localizedText('debug_push_label', 'PUSH CARD CONTENT'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#C8841A');

      Column({ space: 10 }) {
        TextInput({ placeholder: this.localizedText('debug_push_title_placeholder', 'Title (optional)') })
          .fontSize(14)
          .onChange((value: string) => {
            this.debugTitle = value;
          });

        TextInput({ placeholder: this.localizedText('debug_push_body_placeholder', 'Body (required)') })
          .fontSize(14)
          .onChange((value: string) => {
            this.debugBody = value;
          });

        TextInput({ placeholder: this.localizedText('debug_push_note_placeholder', 'Note (optional)') })
          .fontSize(14)
          .onChange((value: string) => {
            this.debugNote = value;
          });

        TextInput({ placeholder: this.localizedText('debug_push_image_placeholder', 'Image URL (optional)') })
          .fontSize(14)
          .onChange((value: string) => {
            this.debugImageUrl = value;
          });

        Row({ space: 12 }) {
          Button(this.localizedText('debug_push_button', 'Push to Card'))
            .type(ButtonType.Normal)
            .backgroundColor('#C8841A')
            .fontColor('#FFFFFF')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .borderRadius(12)
            .onClick(() => {
              this.handlePushToCard();
            });

          Button(this.localizedText('debug_reset_button', 'Reset Default'))
            .type(ButtonType.Normal)
            .backgroundColor('#F6F7FA')
            .fontColor('#8A92A2')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .borderRadius(12)
            .border({ width: 1, color: '#E5E7EC' })
            .onClick(() => {
              this.handleResetDefault();
            });
        }
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 14 })
      .backgroundColor('#FFFFFF')
      .borderRadius(14)
      .border({ width: 1, color: '#E5E7EC' });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder InvokeSimulateSection() {
    Column({ space: 12 }) {
      Text(this.localizedText('debug_invoke_label', 'INVOKE SIMULATION'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#C8841A');

      Column({ space: 10 }) {
        Text(this.localizedText('debug_invoke_desc', 'Simulates a gateway invoke command (card.reminder.update) using the current form fields above.'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#4D5563');

        Button(this.localizedText('debug_invoke_button', 'Simulate Invoke'))
          .type(ButtonType.Normal)
          .backgroundColor('#1D5DD8')
          .fontColor('#FFFFFF')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .borderRadius(12)
          .onClick(() => {
            this.handleSimulateInvoke();
          });
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 14 })
      .backgroundColor('#FFFFFF')
      .borderRadius(14)
      .border({ width: 1, color: '#E5E7EC' });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder CardStateSection() {
    Column({ space: 12 }) {
      Text(this.localizedText('debug_state_label', 'CARD STATE'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#C8841A');

      Column({ space: 8 }) {
        this.InfoRow('formIds count', String(cardReminderService.getCurrentContent().body.length > 0 ? 'has content' : 'empty'));
        this.InfoRow(this.localizedText('debug_state_title', 'Title'), this.currentCardContent().title || '(empty)');
        this.InfoRow(this.localizedText('debug_state_body', 'Body'), this.currentCardContent().body);
        this.InfoRow(this.localizedText('debug_state_note', 'Note'), this.currentCardContent().note || '(empty)');
        this.InfoRow(this.localizedText('debug_state_image', 'Image URL'), this.currentCardContent().imageUrl || '(empty)');
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 14 })
      .backgroundColor('#FFFFFF')
      .borderRadius(14)
      .border({ width: 1, color: '#E5E7EC' });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder PushResultRail() {
    Column({ space: 2 }) {
      Text(this.localizedText('debug_result_label', 'PUSH RESULT'))
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor('#C8841A');

      Text(this.pushResult)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#17181C');
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#C8841A' });
  }

  @Builder InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#17181C');

      Blank();

      Text(value)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#8A92A2')
        .maxLines(2)
        .textAlign(TextAlign.End);
    }
    .width('100%');
  }

  private currentCardContent(): ReminderCardContent {
    return cardReminderService.getCurrentContent();
  }

  private refreshCurrentCardState(): void {
    const content = cardReminderService.getCurrentContent();
    this.currentCardState = JSON.stringify({
      title: content.title,
      body: content.body,
      note: content.note,
      imageUrl: content.imageUrl
    });
  }

  private handlePushToCard(): void {
    if (this.debugBody.trim().length === 0) {
      this.pushResult = 'Error: body is required.';
      return;
    }

    const content = new ReminderCardContent();
    content.title = this.debugTitle.trim();
    content.body = this.debugBody.trim();
    content.note = this.debugNote.trim();
    content.imageUrl = this.debugImageUrl.trim();

    cardReminderService.updateReminderCard(content);
    this.refreshCurrentCardState();
    this.pushResult = 'Pushed: title="' + content.title + '", body="' + content.body + '"';
  }

  private handleResetDefault(): void {
    cardReminderService.resetToDefault();
    this.refreshCurrentCardState();
    this.debugTitle = '';
    this.debugBody = '';
    this.debugNote = '';
    this.debugImageUrl = '';
    this.pushResult = 'Reset to default.';
  }

  private handleSimulateInvoke(): void {
    if (this.debugBody.trim().length === 0) {
      this.pushResult = 'Error: body is required for invoke.';
      return;
    }

    const paramsJson = JSON.stringify({
      title: this.debugTitle.trim(),
      body: this.debugBody.trim(),
      note: this.debugNote.trim(),
      imageUrl: this.debugImageUrl.trim()
    });

    const request = new InvokeRequest();
    request.id = 'debug-simulate';
    request.nodeId = 'debug-node';
    request.command = 'card.reminder.update';
    request.paramsJson = paramsJson;

    const result = cardReminderService.handleUpdateReminderCommand(request);
    this.refreshCurrentCardState();
    this.pushResult = 'Invoke result: ok=' + result.ok + (result.error ? ', error=' + result.error.message : '');
  }

  private localizedText(name: string, fallback: string): string {
    try {
      void this.localeVersion;
      return getContext(this).resourceManager.getStringByNameSync(name);
    } catch (error) {
      console.warn('DebugPage: localizedText failed for key: ' + name);
      return fallback;
    }
  }
}
