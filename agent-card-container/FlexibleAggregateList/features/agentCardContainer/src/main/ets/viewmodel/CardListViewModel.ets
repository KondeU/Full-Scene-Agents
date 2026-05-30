import { DirectoryScanner } from '../utils/DirectoryScanner';
import { JsonParser } from '../utils/JsonParser';
import { CardData } from '../model/CardData';
import { AgentAppConfig } from '../model/AgentAppConfig';
import { commonConstants } from '../constants/CommonConstants';

export class CardListViewModel {
  getCardList(agentAppPath: string): CardData[] {
    const jsonFiles = DirectoryScanner.scanCardJsonFiles(agentAppPath);
    const cards: CardData[] = [];
    for (const jsonPath of jsonFiles) {
      const card = JsonParser.parseCardData(jsonPath);
      if (card) {
        cards.push(card);
      }
    }
    const config = this.getConfig(agentAppPath);
    if (config.ascendingOrder) {
      cards.sort((a, b) => a.number - b.number);
    } else {
      cards.sort((a, b) => b.number - a.number);
    }
    return cards;
  }

  getConfig(agentAppPath: string): AgentAppConfig {
    const configPath = `${agentAppPath}/${commonConstants.CONFIG_FILE_NAME}`;
    return JsonParser.parseConfig(configPath);
  }
}

const cardListViewModel = new CardListViewModel();
export default cardListViewModel;