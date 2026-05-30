import { fileIo as fs } from '@kit.CoreFileKit';
import { Logger } from '@ohos/common';
import { CardData } from '../model/CardData';
import { AgentAppConfig } from '../model/AgentAppConfig';
import { commonConstants } from '../constants/CommonConstants';

const logger = new Logger();
const TAG = 'JsonParser';

export class JsonParser {
  static parseCardData(jsonPath: string): CardData | null {
    try {
      const content = fs.readTextSync(jsonPath);
      const json = JSON.parse(content);
      const fileName = jsonPath.split('/').pop() || '';
      const numberMatch = fileName.match(/^(\d+)\.json$/);
      const number = numberMatch ? parseInt(numberMatch[1], 10) : 0;
      return new CardData(
        number,
        json.title || '',
        json.line0 || '',
        json.line1,
        json.buttonText,
        jsonPath
      );
    } catch (err) {
      logger.error(TAG, `Failed to parse card JSON: ${jsonPath}, error: ${JSON.stringify(err)}`);
      return null;
    }
  }

  static parseConfig(configPath: string): AgentAppConfig {
    try {
      if (!fs.accessSync(configPath)) {
        return new AgentAppConfig(commonConstants.DEFAULT_ASCENDING_ORDER);
      }
      const content = fs.readTextSync(configPath);
      const json = JSON.parse(content);
      return new AgentAppConfig(json.ascendingOrder);
    } catch (err) {
      logger.warn(TAG, `Failed to parse config.json: ${configPath}, using defaults. Error: ${JSON.stringify(err)}`);
      return new AgentAppConfig(commonConstants.DEFAULT_ASCENDING_ORDER);
    }
  }
}