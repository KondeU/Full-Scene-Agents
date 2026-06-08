import { ShareExtensionAbility, UIExtensionContentSession, Want, Context } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { mainViewModel } from '../viewmodel/MainViewModel';
import { photoCaptureService } from '../service/PhotoCaptureService';
import { securePrefs } from '../common/SecurePrefs';
import { GatewayEndpoint } from '../model/GatewayModels';

const TAG = '[Share2Agent]';

export default class ShareReceiveExtensionAbility extends ShareExtensionAbility {
  onSessionCreate(want: Want, session: UIExtensionContentSession): void {
    // 传递 session 给 ShareReceivePage 用于关闭面板
    AppStorage.setOrCreate<UIExtensionContentSession>('shareSession', session);

    // 注入 share extension 自身的 context，供 MainViewModel 和 SecurePrefs 使用
    AppStorage.setOrCreate<Context>('abilityContext', this.context);

    // 诊断日志
    console.info(
      TAG + ' onSessionCreate: isConnected=' + mainViewModel.isConnected +
      ', chatSessionKey=' + mainViewModel.chatSessionKey +
      ', statusText=' + (mainViewModel.statusText || '(empty)') +
      ', chatError=' + (mainViewModel.chatError || '(none)')
    );

    // 初始化 SecurePrefs（文件级存储，跨进程可读），然后确保 Gateway 连接
    securePrefs.init(this.context).then(() => {
      console.info(TAG + ' SecurePrefs initialized');
      return this.ensureConnection();
    }).catch((err: Error) => {
      console.error(TAG + ' SecurePrefs init failed: ' + err.message);
      return false;
    }).then((connected: boolean) => {
      if (!connected) {
        console.warn(TAG + ' ensureConnection failed, cannot send');
        AppStorage.setOrCreate<string>('shareReceiveStatus', 'fail');
        AppStorage.setOrCreate<string>(
          'shareReceiveError',
          'Not connected to Gateway. Please open IntentX App, go to Connect tab, and connect first.'
        );
        session.loadContent('pages/ShareReceivePage');
        return;
      }

      systemShare.getSharedData(want)
        .then((data: systemShare.SharedData) => {
          const records = data.getRecords();
          if (records.length === 0) {
            console.warn(TAG + ': getSharedData returned 0 records');
            session.terminateSelf();
            return;
          }

          const record = records[0];
          console.info(TAG + ': received share, utd=' + record.utd + ', uri=' + record.uri);

          const imageUri = record.uri;
          if (!imageUri || imageUri.length === 0) {
            console.warn(TAG + ': imageUri is empty');
            session.terminateSelf();
            return;
          }
          AppStorage.setOrCreate<string>('shareReceiveUri', imageUri);
          AppStorage.setOrCreate<string>('shareReceiveStatus', 'sending');
          AppStorage.setOrCreate<string>('shareReceiveError', '');
          session.loadContent('pages/ShareReceivePage');

          console.info(TAG + ': starting photo processing pipeline');
          photoCaptureService.processSharedUri(imageUri);
        })
        .catch((error: BusinessError) => {
          console.error(TAG + ': getSharedData failed, code=' + error.code + ', msg=' + error.message);
          AppStorage.setOrCreate<string>('shareReceiveStatus', 'fail');
          AppStorage.setOrCreate<string>(
            'shareReceiveError',
            'Unable to read shared image. Please try again.'
          );
          session.loadContent('pages/ShareReceivePage');
        });
    });
  }

  /**
   * 确保 Gateway 连接可用。若当前 ViewModel 未连接但沙箱文件中有保存的端点信息，
   * 则尝试重新建立连接。
   * @returns Promise<boolean> 连接是否成功
   */
  private async ensureConnection(): Promise<boolean> {
    if (mainViewModel.isConnected) {
      console.info(TAG + ' ensureConnection: already connected');
      return true;
    }

    const endpoint = this.readEndpointFromFile();
    if (endpoint === null) {
      console.warn(TAG + ' ensureConnection: no saved endpoint file');
      return false;
    }

    console.info(
      TAG + ' ensureConnection: reconnecting to ' + endpoint.host + ':' + endpoint.port +
      ', tls=' + endpoint.tlsEnabled
    );

    try {
      await mainViewModel.connect(endpoint);
      console.info(
        TAG + ' ensureConnection: reconnected, isConnected=' + mainViewModel.isConnected +
        ', statusText=' + mainViewModel.statusText
      );
      return mainViewModel.isConnected;
    } catch (error) {
      console.error(TAG + ' ensureConnection: reconnect failed: ' + (error as Error).message);
      return false;
    }
  }

  private readEndpointFromFile(): GatewayEndpoint | null {
    try {
      const filePath = this.context.filesDir + '/gateway_endpoint.json';
      const stat = fileIo.statSync(filePath);
      if (stat.size <= 0) {
        return null;
      }
      const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
      try {
        const buf = new ArrayBuffer(stat.size);
        const readLen = fileIo.readSync(file.fd, buf, { offset: 0, length: stat.size });
        // 注意：V2 签名的 readSync 返回 number | undefined，但实际运行时返回 number
        const actualLen = (typeof readLen === 'number') ? readLen : stat.size;
        const textDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
        const text = textDecoder.decodeWithStream(new Uint8Array(buf, 0, actualLen), { stream: false });
        const json = JSON.parse(text) as Record<string, Object>;
        const host = json['host'] as string;
        const port = json['port'] as number;
        const tls = json['tlsEnabled'] as boolean;
        const stableId = json['stableId'] as string;
        if (!host || host.length === 0 || !port || port <= 0) {
          return null;
        }
        const endpoint = new GatewayEndpoint();
        endpoint.host = host;
        endpoint.port = port;
        endpoint.tlsEnabled = tls || false;
        endpoint.stableId = stableId || '';
        endpoint.name = host + ':' + port;
        return endpoint;
      } finally {
        fileIo.closeSync(file);
      }
    } catch (err) {
      console.warn(TAG + ' readEndpointFromFile failed: ' + (err as Error).message);
      return null;
    }
  }
}
