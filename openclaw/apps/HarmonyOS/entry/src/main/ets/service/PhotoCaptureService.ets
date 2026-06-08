import { cameraPicker } from '@kit.CameraKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { mainViewModel } from '../viewmodel/MainViewModel';
import { OutgoingAttachment } from '../model/GatewayModels';

/** 客户端侧文件大小上限（解码后），与服务端 5MB 限制对齐。 */
const MAX_FILE_SIZE_BYTES: number = 5 * 1024 * 1024;
/**
 * 服务端 parseMessageWithAttachments 的 offload 阈值为 2MB 解码后文件大小。
 * 图片压缩目标：原始文件 ≤ 1.5MB，保留足够余量确保内联传输，避免 offload。
 */
const MAX_INLINE_BYTES: number = 1.5 * 1024 * 1024;
/** 压缩时 JPEG 质量 (0-100)，取值越高文件越大画质越好 */
const JPEG_QUALITY: number = 80;
/** 压缩时长边最大像素数，保持合理画质同时控制文件大小 */
const MAX_DIMENSION: number = 1920;

export class PhotoResult {
  uri: string = '';
  displayName: string = '';
}

export class PhotoCaptureService {
  private base64Helper: util.Base64Helper = new util.Base64Helper();

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
      let ctx: Context | undefined = AppStorage.get<Context>('abilityContext');
      if (!ctx) {
        console.error('PhotoCaptureService: abilityContext not found in AppStorage');
        return null;
      }

      let pickerProfile: cameraPicker.PickerProfile = new cameraPicker.PickerProfile();
      let result: cameraPicker.PickerResult = await cameraPicker.pick(
        ctx,
        [cameraPicker.PickerMediaType.PHOTO],
        pickerProfile
      );

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
   * 照片后处理入口。读取照片并作为附件以聊天消息形式发送给 OpenClaw 服务端。
   * 消息内容为 "/ImageData"。
   *
   * @param photoResult 拍摄或选取得到的照片信息（uri + displayName）
   */
  async obtainPhotoToProcess(photoResult: PhotoResult): Promise<void> {
    console.info(
      'PhotoCaptureService: obtainPhotoToProcess called, uri=' + photoResult.uri +
      ', displayName=' + photoResult.displayName
    );

    try {
      // 打开文件 — fd 必须在 finally 中关闭
      let file = fileIo.openSync(photoResult.uri, fileIo.OpenMode.READ_ONLY);
      try {
        let stat = fileIo.statSync(file.fd);

        // P0-02: 前置校验文件大小
        if (stat.size <= 0) {
          console.error('PhotoCaptureService: file is empty, uri=' + photoResult.uri);
          return;
        }
        // P1-01: 客户端侧大小上限，防止 OOM
        if (stat.size > MAX_FILE_SIZE_BYTES) {
          console.error(
            'PhotoCaptureService: file too large (' + stat.size + ' bytes), max=' + MAX_FILE_SIZE_BYTES
          );
          return;
        }

        let buffer = new ArrayBuffer(stat.size);
        fileIo.readSync(file.fd, buffer);

        // 图片压缩：确保解码后文件 ≤ 1.5MB，低于服务端 2MB offload 阈值
        let finalBuffer = await this.compressImageIfNeeded(buffer);
        let wasCompressed = finalBuffer !== buffer;

        // 使用系统 Base64Helper 编码
        let base64 = await this.base64Helper.encodeToString(new Uint8Array(finalBuffer));

        // 通过文件后缀推断 mimeType；压缩后统一输出 JPEG
        let mimeType = wasCompressed ? 'image/jpeg' : this.inferMimeType(photoResult.displayName || photoResult.uri);
        let fileName = photoResult.displayName || ('photo.' + this.extensionFromMimeType(mimeType));

        // 构造附件
        let attachment = new OutgoingAttachment();
        attachment.type = 'image';
        attachment.mimeType = mimeType;
        attachment.fileName = fileName;
        attachment.content = base64;

        // 发送到专用的 ImportImage 会话，避免主对话被心跳刷屏
        mainViewModel.sendChat('/ImageData', 'off', [attachment], 'ImportImage');
        console.info('PhotoCaptureService: photo sent to ImportImage session');
      } finally {
        // P0-01: 无论 read/encode 是否异常，fd 必须关闭
        fileIo.closeSync(file);
      }
    } catch (error) {
      let bizErr: BusinessError = error as BusinessError;
      console.error(
        'PhotoCaptureService: obtainPhotoToProcess error, code=' + bizErr.code +
        ', msg=' + bizErr.message
      );
    }
  }

  /**
   * 若图片原始文件超过 INLINE 阈值，则缩放并重新编码为 JPEG。
   * GIF 跳过压缩（保留动画帧），其余格式统一输出 JPEG。
   *
   * @returns 压缩后的 ArrayBuffer（可能等于原始 buffer）
   */
  private async compressImageIfNeeded(buffer: ArrayBuffer): Promise<ArrayBuffer> {
    if (buffer.byteLength <= MAX_INLINE_BYTES) {
      return buffer;
    }

    console.info(
      'PhotoCaptureService: compressing image, original=' + buffer.byteLength +
      ' bytes, target≤' + MAX_INLINE_BYTES
    );

    try {
      let source = image.createImageSource(buffer);
      let info = await source.getImageInfo(0);
      let originalWidth = info.size.width;
      let originalHeight = info.size.height;

      // 等比缩放到长边不超过 MAX_DIMENSION
      let targetWidth = originalWidth;
      let targetHeight = originalHeight;
      if (originalWidth > MAX_DIMENSION || originalHeight > MAX_DIMENSION) {
        let scale = MAX_DIMENSION / Math.max(originalWidth, originalHeight);
        targetWidth = Math.round(originalWidth * scale);
        targetHeight = Math.round(originalHeight * scale);
      }

      let decodeOptions: image.DecodingOptions = {
        desiredSize: { width: targetWidth, height: targetHeight }
      };
      let pixelMap = await source.createPixelMap(decodeOptions);

      let packer = image.createImagePacker();
      let packOptions: image.PackingOption = {
        format: 'image/jpeg',
        quality: JPEG_QUALITY
      };
      let compressed = await packer.packing(pixelMap, packOptions);

      pixelMap.release();
      source.release();

      console.info(
        'PhotoCaptureService: compressed ' + buffer.byteLength + '→' +
        compressed.byteLength + ' bytes (' + targetWidth + 'x' + targetHeight + ')'
      );
      return buffer.byteLength <= compressed.byteLength ? buffer : compressed;
    } catch (error) {
      console.warn(
        'PhotoCaptureService: compression failed, using original buffer: ' +
        (error as Error).message
      );
      return buffer;
    }
  }

  /**
   * 根据文件名后缀推断图片 MIME 类型。
   */
  private inferMimeType(fileName: string): string {
    if (!fileName || fileName.length === 0) {
      return 'image/jpeg';
    }
    let lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      return 'image/heic';
    }
    if (lower.endsWith('.bmp')) {
      return 'image/bmp';
    }
    return 'image/jpeg';
  }

  /**
   * 根据 MIME 类型返回文件扩展名（不含点号）。
   */
  private extensionFromMimeType(mime: string): string {
    if (mime === 'image/png') {
      return 'png';
    }
    if (mime === 'image/webp') {
      return 'webp';
    }
    if (mime === 'image/gif') {
      return 'gif';
    }
    if (mime === 'image/heic') {
      return 'heic';
    }
    return 'jpg';
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
