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
      const content: string = fs.readTextSync(jsonPath);
      const json: Record<string, string> = JSON.parse(content) as Record<string, string>;
      const fileName: string = jsonPath.split('/').pop() ?? '';
      const numberMatch: RegExpMatchArray | null = fileName.match(/^(\d+)\.json$/);
      const number: number = numberMatch !== null ? parseInt(numberMatch[1], 10) : 0;
      return new CardData(
        number,
        json['title'] ?? '',
        json['line0'] ?? '',
        json['line1'] ?? '',
        json['buttonText'] ?? '',
        jsonPath
      );
    } catch (err) {
      logger.error(TAG, `Failed to parse card JSON: ${jsonPath}`);
      return null;
    }
  }

  static parseConfig(configPath: string): AgentAppConfig {
    try {
      if (!fs.accessSync(configPath)) {
        return new AgentAppConfig(commonConstants.DEFAULT_ASCENDING_ORDER);
      }
      const content: string = fs.readTextSync(configPath);
      const json: Record<string, boolean> = JSON.parse(content) as Record<string, boolean>;
      return new AgentAppConfig(json['ascendingOrder']);
    } catch (err) {
      logger.warn(TAG, `Failed to parse config.json, using defaults`);
      return new AgentAppConfig(commonConstants.DEFAULT_ASCENDING_ORDER);
    }
  }
}