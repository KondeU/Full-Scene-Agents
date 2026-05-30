export class AgentAppConfig {
  ascendingOrder: boolean = true;

  constructor(ascendingOrder?: boolean) {
    if (ascendingOrder !== undefined) {
      this.ascendingOrder = ascendingOrder;
    }
  }
}