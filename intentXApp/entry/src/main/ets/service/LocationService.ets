import { geoLocationManager } from '@kit.LocationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { InvokeRequest, InvokeResult } from '../api/GatewaySession';
import { securePrefs, LocationMode } from '../common/SecurePrefs';

export class LocationResult {
  latitude: number = 0;
  longitude: number = 0;
  altitude: number | null = null;
  accuracy: number = 0;
  timestamp: number = 0;
}

export class LocationService {
  async handleGetLocation(request: InvokeRequest): Promise<InvokeResult> {
    // 1. 读取用户位置偏好
    const modeStr = await securePrefs.getLocationMode();
    if (modeStr === LocationMode.Off) {
      return InvokeResult.error('LOCATION_DISABLED', 'Location disabled by user preference');
    }

    // 2. 解析可选参数
    let timeoutMs = 10000;
    let priority = geoLocationManager.LocatingPriority.PRIORITY_ACCURACY;
    try {
      const pj = request.paramsJson.trim();
      if (pj.length > 0) {
        const p = JSON.parse(pj) as Record<string, Object>;
        if (typeof p['timeoutMs'] === 'number') {
          timeoutMs = p['timeoutMs'] as number;
        }
        if (typeof p['maxAgeMs'] === 'number') {
          // maxAgeMs 由 Gateway 传入，用于缓存策略；当前简单实现忽略缓存
        }
        const desiredAccuracy = typeof p['desiredAccuracy'] === 'string' ? p['desiredAccuracy'] : '';
        if (desiredAccuracy === 'coarse' || desiredAccuracy === 'balanced') {
          priority = geoLocationManager.LocatingPriority.PRIORITY_LOCATING_SPEED;
        }
        // 'precise' 或不指定 → 保持默认 PRIORITY_ACCURACY
      }
    } catch (_) {
      // 参数解析失败，使用默认值
    }

    // 3. 用户偏好覆盖：Approximate 使用快速定位（多技术融合，精度适中）
    if (modeStr === LocationMode.Approximate) {
      priority = geoLocationManager.LocatingPriority.PRIORITY_LOCATING_SPEED;
    }

    // 4. 调用系统定位接口
    try {
      const singleRequest: geoLocationManager.SingleLocationRequest = {
        'locatingPriority': priority,
        'locatingTimeoutMs': timeoutMs
      };
      const location = await geoLocationManager.getCurrentLocation(singleRequest);
      const result = new LocationResult();
      result.latitude = location.latitude;
      result.longitude = location.longitude;
      result.altitude = location.altitude !== undefined ? location.altitude : null;
      result.accuracy = location.accuracy;
      result.timestamp = location.timeStamp;
      console.info('LocationService: got location ' +
        'lat=' + result.latitude + ' lon=' + result.longitude +
        ' acc=' + result.accuracy);
      return InvokeResult.ok(JSON.stringify(result));
    } catch (e) {
      const err = e as BusinessError;
      console.error('LocationService: getCurrentLocation failed: ' + err.message);
      return InvokeResult.error('LOCATION_FAILED', err.message);
    }
  }
}

export const locationService = new LocationService();
