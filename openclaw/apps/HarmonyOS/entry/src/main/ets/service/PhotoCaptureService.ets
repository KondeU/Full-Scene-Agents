import { cameraPicker } from '@kit.CameraKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class PhotoResult {
  uri: string = '';
  displayName: string = '';
}

export class PhotoCaptureService {
  /**
   * 从相册选取照片，使用 PhotoViewPicker 安全控件模式。
   * 用户取消选取时返回 null（不抛异常）。
   */
  async pickFromAlbum(): Promise<PhotoResult | null> {
    try {
      let picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      let options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;

      let result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      // 用户取消：result 存在但 photoUris 为空
      if (!result || !result.photoUris || result.photoUris.length === 0) {
        console.info('PhotoCaptureService: album pick cancelled or returned no URI');
        return null;
      }

      let uri: string = result.photoUris[0];
      let photoResult: PhotoResult = new PhotoResult();
      photoResult.uri = uri;
      photoResult.displayName = this.extractDisplayName(uri);
      console.info('PhotoCaptureService: album pick success, uri=' + uri);
      return photoResult;
    } catch (error) {
      let bizErr: BusinessError = error as BusinessError;
      console.error('PhotoCaptureService: pickFromAlbum error, code=' + bizErr.code + ', msg=' + bizErr.message);
      return null;
    }
  }

  /**
   * 使用相机拍照，使用 cameraPicker 安全控件模式。
   * 拍照后自动存入系统相册，返回存入后的 URI。
   * 用户取消拍照时返回 null（不抛异常）。
   */
  async capturePhoto(): Promise<PhotoResult | null> {
    try {
      // cameraPicker.pick() 需要 UIAbility 上下文，通过 AppStorage 获取
      // （EntryAbility 已在启动时将 abilityContext 存入 AppStorage）
      let ctx: Context | undefined = AppStorage.get<Context>('abilityContext');
      if (!ctx) {
        console.error('PhotoCaptureService: abilityContext not found in AppStorage');
        return null;
      }

      // cameraPicker.pick() 打开系统相机 UI，拍照后自动存入相册
      let pickerProfile: cameraPicker.PickerProfile = new cameraPicker.PickerProfile();
      let result: cameraPicker.PickerResult = await cameraPicker.pick(
        ctx,
        [cameraPicker.PickerMediaType.PHOTO],
        pickerProfile
      );

      // 用户取消或拍照失败：resultUri 为空
      if (!result || !result.resultUri || result.resultUri.length === 0) {
        console.info('PhotoCaptureService: camera capture cancelled or returned no URI');
        return null;
      }

      let uri: string = result.resultUri;
      let photoResult: PhotoResult = new PhotoResult();
      photoResult.uri = uri;
      photoResult.displayName = this.extractDisplayName(uri);
      console.info('PhotoCaptureService: camera capture success, uri=' + uri);
      return photoResult;
    } catch (error) {
      let bizErr: BusinessError = error as BusinessError;
      console.error('PhotoCaptureService: capturePhoto error, code=' + bizErr.code + ', msg=' + bizErr.message);
      return null;
    }
  }

  /**
   * 照片后处理入口。当前 stub 实现，仅 console.log。
   * 后续由其他同学对接实际处理逻辑。
   *
   * @param photoResult 拍摄或选取得到的照片信息（uri + displayName）
   */
  obtainPhotoToProcess(photoResult: PhotoResult): void {
    console.info(
      'PhotoCaptureService: obtainPhotoToProcess called, uri=' + photoResult.uri +
      ', displayName=' + photoResult.displayName
    );
  }

  private extractDisplayName(uri: string): string {
    if (!uri || uri.length === 0) {
      return '';
    }
    let lastSlash: number = uri.lastIndexOf('/');
    if (lastSlash >= 0 && lastSlash < uri.length - 1) {
      return uri.substring(lastSlash + 1);
    }
    return uri;
  }
}

export const photoCaptureService = new PhotoCaptureService();
