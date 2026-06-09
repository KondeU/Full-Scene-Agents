import { MainViewModel } from '../viewmodel/MainViewModel';
import { InvokeRequest } from '../api/GatewaySession';
import { ReminderCardContent, cardReminderService } from '../service/CardReminderService';
import { locationService } from '../service/LocationService';
import { notificationService } from '../service/NotificationService';

@Component
export struct DebugPage {
  @ObjectLink viewModel: MainViewModel;
  @StorageProp('localeVersion') localeVersion: number = 0;

  @State debugTitle: string = '';
  @State debugBody: string = '';
  @State debugNote: string = '';
  @State debugImageUrl: string = '';
  @State locDesiredAccuracy: string = 'precise';
  @State locTimeoutMs: string = '10000';
  @State pushResult: string = '';
  @State notifyTitle: string = 'Agent Notification';
  @State notifyBody: string = 'This is a test notification from Agent.';
  @State notifySound: string = '';
  @State notifyPriority: string = 'active';

  aboutToAppear(): void {
    console.info('[DebugPage] aboutToAppear');
  }

  aboutToDisappear(): void {
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        this.Header();
        this.PushFormSection();

        if (this.pushResult.length > 0) {
          this.PushResultRail();
        }

        this.InvokeSimulateSection();

        this.LocationInvokeSection();

        this.NotificationInvokeSection();
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
        .fontSize(12).fontWeight(FontWeight.Bold).fontColor('#C8841A');
      Text(this.localizedText('debug_header_title', 'Debug'))
        .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#17181C');
      Text(this.localizedText('debug_header_subtitle', 'Test card content, simulate invoke commands, and inspect device state.'))
        .fontSize(14).fontWeight(FontWeight.Medium).fontColor('#4D5563');
    }
    .width('100%').alignItems(HorizontalAlign.Start);
  }

  @Builder PushFormSection() {
    Column({ space: 12 }) {
      Text(this.localizedText('debug_push_label', 'PUSH CARD CONTENT'))
        .fontSize(12).fontWeight(FontWeight.Bold).fontColor('#C8841A');

      Column({ space: 10 }) {
        TextInput({ placeholder: this.localizedText('debug_push_title_placeholder', 'Title (optional)'), text: this.debugTitle })
          .fontSize(14).onChange((v: string) => { this.debugTitle = v; });
        TextInput({ placeholder: this.localizedText('debug_push_body_placeholder', 'Body (required)'), text: this.debugBody })
          .fontSize(14).onChange((v: string) => { this.debugBody = v; });
        TextInput({ placeholder: this.localizedText('debug_push_note_placeholder', 'Note (optional)'), text: this.debugNote })
          .fontSize(14).onChange((v: string) => { this.debugNote = v; });
        TextInput({ placeholder: this.localizedText('debug_push_image_placeholder', 'Image URL (optional)'), text: this.debugImageUrl })
          .fontSize(14).onChange((v: string) => { this.debugImageUrl = v; });

        Row({ space: 12 }) {
          Button(this.localizedText('debug_push_button', 'Push to Card'))
            .type(ButtonType.Normal).backgroundColor('#C8841A').fontColor('#FFFFFF')
            .fontSize(14).fontWeight(FontWeight.Bold).borderRadius(12)
            .onClick(() => { this.handlePushToCard(); });

          Button(this.localizedText('debug_reset_button', 'Reset Default'))
            .type(ButtonType.Normal).backgroundColor('#F6F7FA').fontColor('#8A92A2')
            .fontSize(14).fontWeight(FontWeight.Bold)
            .border({ width: 1, color: '#E5E7EC' }).borderRadius(12)
            .onClick(() => { this.handleResetDefault(); });
        }
      }
      .width('100%').padding(14).backgroundColor('#FFFFFF').borderRadius(14)
      .border({ width: 1, color: '#E5E7EC' });
    }
    .width('100%').alignItems(HorizontalAlign.Start);
  }

  @Builder InvokeSimulateSection() {
    Column({ space: 12 }) {
      Text(this.localizedText('debug_invoke_label', 'INVOKE SIMULATION'))
        .fontSize(12).fontWeight(FontWeight.Bold).fontColor('#C8841A');

      Column({ space: 10 }) {
        Text(this.localizedText('debug_invoke_desc', 'Simulates a gateway invoke command (card.reminder.update) using the current form fields above.'))
          .fontSize(13).fontWeight(FontWeight.Medium).fontColor('#4D5563');

        Button(this.localizedText('debug_invoke_button', 'Simulate Invoke'))
          .type(ButtonType.Normal).backgroundColor('#C8841A').fontColor('#FFFFFF')
          .fontSize(14).fontWeight(FontWeight.Bold).borderRadius(12)
          .onClick(() => { this.handleSimulateInvoke(); });
      }
      .width('100%').padding(14).backgroundColor('#FFFFFF').borderRadius(14)
      .border({ width: 1, color: '#E5E7EC' });
    }
    .width('100%').alignItems(HorizontalAlign.Start);
  }

  @Builder PushResultRail() {
    Column({ space: 4 }) {
      Text(this.localizedText('debug_result_label', 'PUSH RESULT'))
        .fontSize(11).fontWeight(FontWeight.Medium).fontColor('#C8841A');
      Text(this.pushResult).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#17181C')
        .maxLines(10).textOverflow({ overflow: TextOverflow.Ellipsis }).wordBreak(WordBreak.BREAK_ALL);
    }
    .width('100%').padding(12)
    .backgroundColor('#FFFFFF').borderRadius(12).border({ width: 1, color: '#C8841A' });
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
    this.pushResult = 'Pushed: title="' + content.title + '", body="' + content.body +
      '", note="' + content.note + '", imageUrl="' + content.imageUrl + '"';
  }

  private handleResetDefault(): void {
    cardReminderService.resetToDefault();
    this.debugTitle = '';
    this.debugBody = '';
    this.debugNote = '';
    this.debugImageUrl = '';
    this.pushResult = 'Reset to default.';
  }

  @Builder LocationInvokeSection() {
    Column({ space: 12 }) {
      Text(this.localizedText('debug_location_label', 'LOCATION SIMULATION'))
        .fontSize(12).fontWeight(FontWeight.Bold).fontColor('#C8841A');

      Column({ space: 10 }) {
        Text(this.localizedText('debug_location_desc', 'Simulate a location.get invoke command for client-side stub testing.'))
          .fontSize(13).fontWeight(FontWeight.Medium).fontColor('#4D5563');

        Row({ space: 8 }) {
          Text('Accuracy:').fontSize(13).fontWeight(FontWeight.Medium).fontColor('#4D5563');

          Button('precise')
            .type(ButtonType.Normal)
            .backgroundColor(this.locDesiredAccuracy === 'precise' ? '#C8841A' : '#F6F7FA')
            .fontColor(this.locDesiredAccuracy === 'precise' ? '#FFFFFF' : '#8A92A2')
            .fontSize(12).fontWeight(FontWeight.Bold).borderRadius(8)
            .border({ width: 1, color: '#E5E7EC' })
            .onClick(() => { this.locDesiredAccuracy = 'precise'; });

          Button('balanced')
            .type(ButtonType.Normal)
            .backgroundColor(this.locDesiredAccuracy === 'balanced' ? '#C8841A' : '#F6F7FA')
            .fontColor(this.locDesiredAccuracy === 'balanced' ? '#FFFFFF' : '#8A92A2')
            .fontSize(12).fontWeight(FontWeight.Bold).borderRadius(8)
            .border({ width: 1, color: '#E5E7EC' })
            .onClick(() => { this.locDesiredAccuracy = 'balanced'; });

          Button('coarse')
            .type(ButtonType.Normal)
            .backgroundColor(this.locDesiredAccuracy === 'coarse' ? '#C8841A' : '#F6F7FA')
            .fontColor(this.locDesiredAccuracy === 'coarse' ? '#FFFFFF' : '#8A92A2')
            .fontSize(12).fontWeight(FontWeight.Bold).borderRadius(8)
            .border({ width: 1, color: '#E5E7EC' })
            .onClick(() => { this.locDesiredAccuracy = 'coarse'; });
        }

        TextInput({ placeholder: 'Timeout (ms, default 10000)', text: this.locTimeoutMs })
          .fontSize(13).type(InputType.Number)
          .onChange((v: string) => { this.locTimeoutMs = v; });

        Button(this.localizedText('debug_location_button', 'Simulate Location Invoke'))
          .type(ButtonType.Normal).backgroundColor('#C8841A').fontColor('#FFFFFF')
          .fontSize(14).fontWeight(FontWeight.Bold).borderRadius(12)
          .onClick(() => { this.handleLocationSimulate(); });
      }
      .width('100%').padding(14).backgroundColor('#FFFFFF').borderRadius(14)
      .border({ width: 1, color: '#E5E7EC' });
    }
    .width('100%').alignItems(HorizontalAlign.Start);
  }

  private handleLocationSimulate(): void {
    const params: Record<string, string> = {};
    params['desiredAccuracy'] = this.locDesiredAccuracy;
    if (this.locTimeoutMs.trim().length > 0) {
      params['timeoutMs'] = this.locTimeoutMs.trim();
    }
    const request = new InvokeRequest();
    request.id = 'debug-location';
    request.command = 'location.get';
    request.paramsJson = JSON.stringify(params);
    locationService.handleGetLocation(request).then((result) => {
      if (result.ok) {
        this.pushResult = 'Location result: ' + (result.payloadJson || '{}');
      } else {
        this.pushResult = 'Location error: ' + (result.error ? result.error.message : 'unknown');
      }
    });
  }

  private handleSimulateInvoke(): void {
    if (this.debugBody.trim().length === 0) {
      this.pushResult = 'Error: body is required.';
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
    request.command = 'card.reminder.update';
    request.paramsJson = paramsJson;
    const result = cardReminderService.handleUpdateReminderCommand(request);
    this.pushResult = 'Invoke result: ok=' + result.ok + (result.error ? ', error=' + result.error.message : '');
  }

  @Builder NotificationInvokeSection() {
    Column({ space: 12 }) {
      Text(this.localizedText('debug_notify_label', 'NOTIFICATION SIMULATION'))
        .fontSize(12).fontWeight(FontWeight.Bold).fontColor('#C8841A');

      Column({ space: 10 }) {
        Text(this.localizedText('debug_notify_desc', 'Simulate system.notify to send a test notification.'))
          .fontSize(13).fontWeight(FontWeight.Medium).fontColor('#4D5563');

        TextInput({ placeholder: 'Title', text: this.notifyTitle })
          .fontSize(14).onChange((v: string) => { this.notifyTitle = v; });

        TextInput({ placeholder: 'Body', text: this.notifyBody })
          .fontSize(14).onChange((v: string) => { this.notifyBody = v; });

        Row({ space: 8 }) {
          Text('Priority:').fontSize(13).fontWeight(FontWeight.Medium).fontColor('#4D5563');

          Button('active')
            .type(ButtonType.Normal).fontSize(12).fontWeight(FontWeight.Bold).borderRadius(8)
            .backgroundColor(this.notifyPriority === 'active' ? '#C8841A' : '#F6F7FA')
            .fontColor(this.notifyPriority === 'active' ? '#FFFFFF' : '#8A92A2')
            .border({ width: 1, color: '#E5E7EC' })
            .onClick(() => { this.notifyPriority = 'active'; });

          Button('passive')
            .type(ButtonType.Normal).fontSize(12).fontWeight(FontWeight.Bold).borderRadius(8)
            .backgroundColor(this.notifyPriority === 'passive' ? '#C8841A' : '#F6F7FA')
            .fontColor(this.notifyPriority === 'passive' ? '#FFFFFF' : '#8A92A2')
            .border({ width: 1, color: '#E5E7EC' })
            .onClick(() => { this.notifyPriority = 'passive'; });

          Button('timeSensitive')
            .type(ButtonType.Normal).fontSize(12).fontWeight(FontWeight.Bold).borderRadius(8)
            .backgroundColor(this.notifyPriority === 'timeSensitive' ? '#C8841A' : '#F6F7FA')
            .fontColor(this.notifyPriority === 'timeSensitive' ? '#FFFFFF' : '#8A92A2')
            .border({ width: 1, color: '#E5E7EC' })
            .onClick(() => { this.notifyPriority = 'timeSensitive'; });
        }

        Row({ space: 8 }) {
          Text('Sound:').fontSize(13).fontWeight(FontWeight.Medium).fontColor('#4D5563');

          Button('default')
            .type(ButtonType.Normal).fontSize(12).fontWeight(FontWeight.Bold).borderRadius(8)
            .backgroundColor(this.notifySound.length === 0 ? '#C8841A' : '#F6F7FA')
            .fontColor(this.notifySound.length === 0 ? '#FFFFFF' : '#8A92A2')
            .border({ width: 1, color: '#E5E7EC' })
            .onClick(() => { this.notifySound = ''; });

          Button('silent')
            .type(ButtonType.Normal).fontSize(12).fontWeight(FontWeight.Bold).borderRadius(8)
            .backgroundColor(this.notifySound === 'none' ? '#C8841A' : '#F6F7FA')
            .fontColor(this.notifySound === 'none' ? '#FFFFFF' : '#8A92A2')
            .border({ width: 1, color: '#E5E7EC' })
            .onClick(() => { this.notifySound = 'none'; });
        }

        Button(this.localizedText('debug_notify_button', 'Send Test Notification'))
          .type(ButtonType.Normal).backgroundColor('#C8841A').fontColor('#FFFFFF')
          .fontSize(14).fontWeight(FontWeight.Bold).borderRadius(12)
          .onClick(() => { this.handleNotifySimulate(); });
      }
      .width('100%').padding(14).backgroundColor('#FFFFFF').borderRadius(14)
      .border({ width: 1, color: '#E5E7EC' });
    }
    .width('100%').alignItems(HorizontalAlign.Start);
  }

  private handleNotifySimulate(): void {
    const paramsObj: Record<string, string> = {
      'title': this.notifyTitle.trim(),
      'body': this.notifyBody.trim()
    };
    if (this.notifySound.length > 0) {
      paramsObj['sound'] = this.notifySound;
    }
    if (this.notifyPriority.length > 0) {
      paramsObj['priority'] = this.notifyPriority;
    }
    const request = new InvokeRequest();
    request.id = 'debug-notify';
    request.command = 'system.notify';
    request.paramsJson = JSON.stringify(paramsObj);
    notificationService.handleSystemNotify(request).then((result) => {
      if (result.ok) {
        this.pushResult = 'Notify ok: ' + (result.payloadJson || '{}');
      } else {
        this.pushResult = 'Notify error: ' + (result.error ? result.error.message : 'unknown');
      }
    });
  }

  private localizedText(name: string, fallback: string): string {
    try {
      void this.localeVersion;
      return getContext(this).resourceManager.getStringByNameSync(name);
    } catch (e) {
      return fallback;
    }
  }
}
