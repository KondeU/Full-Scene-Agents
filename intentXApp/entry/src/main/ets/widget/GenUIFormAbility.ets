/**
 * 生成式 Widget 服务卡片生命周期管理
 * 负责卡片的创建、更新和销毁
 */
import FormExtension from '@ohos.app.form.FormExtensionAbility';
import formProvider from '@ohos.app.form.formProvider';
import Want from '@ohos.app.ability.Want';
import formBindingData from '@ohos.app.form.formBindingData';

/**
 * 卡片数据接口
 */
interface FormCardData {
  formId: string;
  weightValue: string;
  bloodPressureValue: string;
}

/**
 * 卡片事件数据接口
 */
interface FormEventData {
  action?: string;
  formId?: string;
}

export default class GenUIFormAbility extends FormExtension {
  /**
   * 卡片创建时调用
   * 用于初始化卡片数据
   */
  onAddForm(want: Want) {
    console.info('[GenUIFormAbility] onAddForm called');
    
    // 从 Want 中获取参数
    let formId = want.parameters?.['ohos.extra.param.key.form_identity'] as string;
    let formName = want.parameters?.['ohos.extra.param.key.form_name'] as string;
    let formDimension = want.parameters?.['ohos.extra.param.key.form_dimension'] as string;
    
    console.info(`[GenUIFormAbility] Form created: id=${formId}, name=${formName}, dimension=${formDimension}`);
    
    // 创建初始数据
    let formData: FormCardData = {
      formId: formId,
      weightValue: '61.5',
      bloodPressureValue: '117'
    };
    
    // 返回卡片数据
    return formBindingData.createFormBindingData(formData);
  }
  
  /**
   * 卡片更新时调用
   * 定时更新或主动更新卡片数据
   */
  onUpdateForm(formId: string) {
    console.info(`[GenUIFormAbility] onUpdateForm called, formId: ${formId}`);
    
    // 获取最新的卡片数据
    let formData = this.getLatestFormData(formId);
    
    // 更新卡片
    formProvider.updateForm(formId, formBindingData.createFormBindingData(formData))
      .then(() => {
        console.info(`[GenUIFormAbility] Form updated successfully: ${formId}`);
      })
      .catch((error: Error) => {
        console.error(`[GenUIFormAbility] Failed to update form: ${error.message}`);
      });
  }
  
  /**
   * 卡片移除时调用
   * 清理相关资源
   */
  onRemoveForm(formId: string) {
    console.info(`[GenUIFormAbility] onRemoveForm called, formId: ${formId}`);
    // 清理该卡片相关的数据
  }
  
  /**
   * 卡片事件处理
   * 处理来自卡片的交互消息
   */
  onFormEvent(formId: string, message: string) {
    console.info(`[GenUIFormAbility] onFormEvent called, formId: ${formId}, message: ${message}`);
    
    // 解析消息
    try {
      let eventData: FormEventData = JSON.parse(message) as FormEventData;
      console.info(`[GenUIFormAbility] Event data: ${JSON.stringify(eventData)}`);
      
      // 根据不同的操作类型处理
      if (eventData.action) {
        this.handleCardAction(formId, eventData.action, eventData);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`[GenUIFormAbility] Failed to parse event message: ${message}`);
    }
  }
  
  /**
   * 获取最新的卡片数据
   */
  private getLatestFormData(formId: string): FormCardData {
    // TODO: 从应用数据源获取最新数据
    // 这里可以根据实际需求从数据库、网络或应用状态获取数据
    
    let formData: FormCardData = {
      formId: formId,
      weightValue: '61.5',
      bloodPressureValue: '117'
    };
    
    return formData;
  }
  
  /**
   * 处理卡片操作
   */
  private handleCardAction(formId: string, action: string, data: FormEventData) {
    console.info(`[GenUIFormAbility] Handling action: ${action}`);
    
    switch (action) {
      case 'capture_health_data':
        console.info('[GenUIFormAbility] Capture health data action triggered');
        // TODO: 跳转或唤起健康数据拍照录入流程
        break;
        
      default:
        console.warn(`[GenUIFormAbility] Unknown action: ${action}`);
    }
    
    // 操作后更新卡片状态
    this.onUpdateForm(formId);
  }
}
