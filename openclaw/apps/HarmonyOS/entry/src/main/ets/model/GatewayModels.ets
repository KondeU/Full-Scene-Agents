/**
 * Gateway endpoint model
 */
export class GatewayEndpoint {
  stableId: string = '';
  name: string = '';
  host: string = '';
  port: number = 0;
  tlsEnabled: boolean = false;
}

/**
 * Gateway authentication response
 */
export interface GatewayAuthResponse {
  serverName: string;
  mainSessionKey: string;
  protocolVersion?: string;
  serverAddress?: string;
}

/**
 * Chat message content block.
 * type='text' → text 字段存文本
 * type='image' → imageUri 字段存本地 URI（用于缩略图展示）
 */
export class ChatMessageContent {
  type: string = 'text';
  text: string = '';
  imageUri: string = '';
}

/**
 * Chat message
 */
export class ChatMessage {
  stableKey: string = '';
  role: string = '';
  content: ChatMessageContent[] = [];
}

/**
 * Chat session entry
 */
export class ChatSessionEntry {
  key: string = '';
  displayName: string = '';
  updatedAtMs: number = 0;
}

/**
 * Chat pending tool call
 */
export class ChatPendingToolCall {
  id: string = '';
  name: string = '';
  paramsJson: string = '';
}

/**
 * Outgoing attachment — matches server-side RpcAttachmentInput schema.
 * content holds the base64-encoded file data (no data: prefix).
 *
 * BREAKING CHANGE (2026-06): field `data` renamed to `content` to align
 * with server protocol. New fields `mimeType` and `fileName` added.
 */
export class OutgoingAttachment {
  type: string = '';
  mimeType: string = '';
  fileName: string = '';
  content: string = '';
}

/**
 * Voice conversation entry
 */
export class VoiceConversationEntry {
  role: string = '';
  text: string = '';
}

/**
 * Gateway protocol version constant
 */
export const GATEWAY_PROTOCOL_VERSION = 3;
