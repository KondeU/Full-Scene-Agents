import { OpenClawCapability, OpenClawDeviceCommand } from '../protocol/OpenClawProtocolConstants';
import { OpenClawCardCommand, OpenClawLocationCommand, OpenClawSystemCommand } from '../protocol/OpenClawProtocolConstants';

export class HarmonyNodeRuntimeFlags {
  deviceInfoAvailable: boolean = true;
  cardReminderAvailable: boolean = true;
  locationAvailable: boolean = true;
  notificationSystemAvailable: boolean = true;
}

export class InvokeCommandSpec {
  name: string = '';
  requiresForeground: boolean = false;

  constructor(name: string, requiresForeground: boolean = false) {
    this.name = name;
    this.requiresForeground = requiresForeground;
  }
}

export class InvokeCommandRegistry {
  static readonly all: InvokeCommandSpec[] = [
    new InvokeCommandSpec(OpenClawDeviceCommand.Status),
    new InvokeCommandSpec(OpenClawDeviceCommand.Info),
    new InvokeCommandSpec(OpenClawDeviceCommand.Permissions),
    new InvokeCommandSpec(OpenClawCardCommand.ReminderUpdate),
    new InvokeCommandSpec(OpenClawDeviceCommand.Health),
    new InvokeCommandSpec(OpenClawLocationCommand.Get),
    new InvokeCommandSpec(OpenClawSystemCommand.Notify)
  ];

  static find(command: string): InvokeCommandSpec | null {
    const normalized = command.trim();
    const match = InvokeCommandRegistry.all.find((spec: InvokeCommandSpec): boolean => spec.name === normalized);
    return match || null;
  }

  static advertisedCapabilities(flags: HarmonyNodeRuntimeFlags): string[] {
    const caps: string[] = [];
    if (flags.deviceInfoAvailable) {
      caps.push(OpenClawCapability.Device);
    }
    if (flags.cardReminderAvailable) {
      caps.push(OpenClawCapability.Card);
    }
    if (flags.locationAvailable) {
      caps.push(OpenClawCapability.Location);
    }
    if (flags.notificationSystemAvailable) {
      caps.push(OpenClawCapability.System);
    }
    return caps;
  }

  static advertisedCommands(flags: HarmonyNodeRuntimeFlags): string[] {
    const commands: string[] = [];
    if (flags.deviceInfoAvailable) {
      commands.push(OpenClawDeviceCommand.Status);
      commands.push(OpenClawDeviceCommand.Info);
      commands.push(OpenClawDeviceCommand.Permissions);
      commands.push(OpenClawDeviceCommand.Health);
    }
    if (flags.cardReminderAvailable) {
      commands.push(OpenClawCardCommand.ReminderUpdate);
    }
    if (flags.locationAvailable) {
      commands.push(OpenClawLocationCommand.Get);
    }
    if (flags.notificationSystemAvailable) {
      commands.push(OpenClawSystemCommand.Notify);
    }
    return commands;
  }
}
