import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { InvokeRequest, InvokeResult } from '../api/GatewaySession';

const TAG = 'NotificationService';

class NotifyResultPayload {
  notifyId: number = 0;

  constructor(notifyId: number) {
    this.notifyId = notifyId;
  }
}

interface SystemNotifyParams {
  title: string;
  body: string;
  sound?: string;
  priority?: string;
}

export class NotificationService {
  private static nextId: number = 1;
  private slotsRegistered: boolean = false;

  async handleSystemNotify(request: InvokeRequest): Promise<InvokeResult> {
    // 1. 解析参数
    let params: SystemNotifyParams;
    try {
      const pj = request.paramsJson.trim();
      if (pj.length === 0) {
        return InvokeResult.error('INVALID_PARAMS', 'Missing title and body');
      }
      const parsed: Record<string, Object> = JSON.parse(pj) as Record<string, Object>;
      const titleObj = parsed['title'];
      const bodyObj = parsed['body'];
      if (typeof titleObj !== 'string' || typeof bodyObj !== 'string') {
        return InvokeResult.error('INVALID_PARAMS', 'title and body must be strings');
      }
      params = {
        title: titleObj,
        body: bodyObj,
        sound: typeof parsed['sound'] === 'string' ? parsed['sound'] : undefined,
        priority: typeof parsed['priority'] === 'string' ? parsed['priority'] : undefined
      };
    } catch (_err) {
      return InvokeResult.error('INVALID_PARAMS', 'Invalid JSON');
    }

    if (params.title.trim().length === 0 || params.body.trim().length === 0) {
      return InvokeResult.error('INVALID_PARAMS', 'title and body are required');
    }

    // 2. 确保 Slot 已注册
    this.ensureSlotsRegistered();

    // 4. 确定 SlotType：静音时用 SERVICE_INFORMATION（不发声），否则按优先级映射
    const silent = this.isSilent(params.sound);
    const slotType: notificationManager.SlotType = silent
      ? notificationManager.SlotType.SERVICE_INFORMATION
      : this.mapPriority(params.priority);

    // 5. 发布通知
    const notifyId = NotificationService.nextId++;

    const notificationReq: notificationManager.NotificationRequest = {
      id: notifyId,
      content: {
        notificationContentType: notificationManager.ContentType
          .NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: params.title.trim(),
          text: params.body.trim()
        }
      },
      notificationSlotType: slotType,
      isOngoing: false,
      isUnremovable: false
    };

    return new Promise<InvokeResult>((resolve: (value: InvokeResult) => void) => {
      notificationManager.publish(notificationReq, (err: BusinessError) => {
        if (err) {
          console.error(TAG + ' publish failed: code=' + String(err.code) +
            ', msg=' + err.message);
          resolve(InvokeResult.error('NOTIFY_FAILED', err.message));
        } else {
          console.info(TAG + ' published notifyId=' + String(notifyId) +
            ' title=' + params.title);
          resolve(InvokeResult.ok(JSON.stringify(new NotifyResultPayload(notifyId))));
        }
      });
    });
  }

  /**
   * 确保通知 Slot 已注册（API 14+ 必需）。
   */
  private ensureSlotsRegistered(): void {
    if (this.slotsRegistered) {
      return;
    }
    try {
      notificationManager.addSlot(
        notificationManager.SlotType.SOCIAL_COMMUNICATION,
        (err: BusinessError) => {
          if (err) {
            console.warn(TAG + ' addSlot SOCIAL_COMMUNICATION failed: ' + err.message);
          }
        }
      );
      notificationManager.addSlot(
        notificationManager.SlotType.SERVICE_INFORMATION,
        (err: BusinessError) => {
          if (err) {
            console.warn(TAG + ' addSlot SERVICE_INFORMATION failed: ' + err.message);
          }
        }
      );
      this.slotsRegistered = true;
    } catch (err) {
      const error = err as Error;
      console.warn(TAG + ' ensureSlotsRegistered exception: ' + error.message);
    }
  }

  private mapPriority(priority?: string): notificationManager.SlotType {
    if (priority === undefined || priority === null) {
      return notificationManager.SlotType.SOCIAL_COMMUNICATION;
    }
    const p = priority.toLowerCase().trim();
    if (p === 'passive') {
      return notificationManager.SlotType.SERVICE_INFORMATION;
    }
    // 'active', 'timeSensitive', 或其他 → 默认 SOCIAL_COMMUNICATION
    return notificationManager.SlotType.SOCIAL_COMMUNICATION;
  }

  private isSilent(sound?: string): boolean {
    if (sound === undefined || sound === null) {
      return false;
    }
    const s = sound.toLowerCase().trim();
    return s === 'none' || s === 'silent' || s === 'off' ||
           s === 'false' || s === '0';
  }
}

export const notificationService = new NotificationService();
