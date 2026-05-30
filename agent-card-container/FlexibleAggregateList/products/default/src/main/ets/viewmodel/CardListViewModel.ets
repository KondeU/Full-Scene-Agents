import { DirectoryScanner } from '../utils/DirectoryScanner';
import { JsonParser } from '../utils/JsonParser';
import { CardData } from '../model/CardData';
import { AgentAppConfig } from '../model/AgentAppConfig';
import { commonConstants } from '../constants/CommonConstants';

export class CardListViewModel {
  getCardList(agentAppPath: string): CardData[] {
    const jsonFiles: string[] = DirectoryScanner.scanCardJsonFiles(agentAppPath);
    const cards: CardData[] = [];
    for (const jsonPath of jsonFiles) {
      const card: CardData | null = JsonParser.parseCardData(jsonPath);
      if (card !== null) {
        cards.push(card);
      }
    }
    const config: AgentAppConfig = this.getConfig(agentAppPath);
    if (config.ascendingOrder) {
      cards.sort((a: CardData, b: CardData) => a.number - b.number);
    } else {
      cards.sort((a: CardData, b: CardData) => b.number - a.number);
    }
    return cards;
  }

  getConfig(agentAppPath: string): AgentAppConfig {
    const configPath: string = `${agentAppPath}/${commonConstants.CONFIG_FILE_NAME}`;
    return JsonParser.parseConfig(configPath);
  }
}