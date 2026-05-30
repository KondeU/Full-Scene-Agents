export class CardData {
  number: number = 0;
  title: string = '';
  line0: string = '';
  line1: string = '';
  buttonText: string = '';
  sourcePath: string = '';

  constructor(number: number, title: string, line0: string, line1: string = '',
    buttonText: string = '', sourcePath: string = '') {
    this.number = number;
    this.title = title;
    this.line0 = line0;
    this.line1 = line1;
    this.buttonText = buttonText;
    this.sourcePath = sourcePath;
  }
}