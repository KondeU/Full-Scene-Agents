import { picker } from '@kit.CoreFileKit';
import { camera } from '@kit.CameraKit';
import { Logger } from '@ohos/common';

const logger = new Logger();
const TAG = 'ImageImportComponent';

@Component
export struct ImageImportComponent {
  @State previewImageUri: string = '';
  onImageSelected: (imageUri: string) => void = () => {};

  build() {
    Column() {
      if (this.previewImageUri.length > 0) {
        Image(this.previewImageUri)
          .width('80%')
          .height(200)
          .objectFit(ImageFit.Contain)
          .borderRadius(12)
          .margin({ bottom: 16 })
      } else {
        Column() {
          Text('选择或拍摄图片')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .width('80%')
        .height(200)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .borderRadius(12)
        .backgroundColor($r('sys.color.ohos_id_color_component_normal'))
        .margin({ bottom: 16 })
      }

      Row() {
        Button('拍照')
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
          .borderRadius(8)
          .height(40)
          .layoutWeight(1)
          .margin({ right: 12 })
          .onClick(() => {
            this.openCamera();
          })

        Button('从相册选择')
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
          .borderRadius(8)
          .height(40)
          .layoutWeight(1)
          .onClick(() => {
            this.openPhotoPicker();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  private openPhotoPicker(): void {
    try {
      const photoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      const photoViewPicker = new picker.PhotoViewPicker();
      photoViewPicker.select(photoSelectOptions).then((result) => {
        if (result.photoUris.length > 0) {
          this.previewImageUri = result.photoUris[0];
          this.onImageSelected(this.previewImageUri);
        }
      }).catch((err) => {
        logger.error(TAG, `Photo picker error: ${JSON.stringify(err)}`);
      });
    } catch (err) {
      logger.error(TAG, `Failed to open photo picker: ${JSON.stringify(err)}`);
    }
  }

  private openCamera(): void {
    try {
      const cameraPickOptions = new picker.CameraPickOptions();
      cameraPickOptions.saveUri = '';
      const cameraPicker = new picker.CameraPicker();
      cameraPicker.pick(cameraPickOptions).then((result) => {
        if (result.resultUri.length > 0) {
          this.previewImageUri = result.resultUri;
          this.onImageSelected(this.previewImageUri);
        }
      }).catch((err) => {
        logger.error(TAG, `Camera picker error: ${JSON.stringify(err)}`);
      });
    } catch (err) {
      logger.error(TAG, `Failed to open camera: ${JSON.stringify(err)}`);
    }
  }
}