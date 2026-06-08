import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GatewayEndpoint } from '../model/GatewayModels';
import {
  EventHandler,
  GatewayConnectOptions,
  GatewayError,
  GatewayHandlers,
  GatewayPayload,
  GatewayResponse,
  GatewayResult,
  GatewaySessionLike,
  InvokeHandler
} from './GatewaySession';

const HERMES_CHAT_PATH = '/v1/chat/completions';
const HERMES_RUNS_PATH = '/v1/runs';
const HERMES_DEFAULT_MODEL = 'ikuncode-codex/gpt-5.4';
const HERMES_MAIN_SESSION = 'main';
const HERMES_LOG_DOMAIN = 0x0001;
const HERMES_LOG_TAG = 'HermesGatewaySession';

class HermesMessageContent {
  type: string = 'text';
  text: string = '';
}

class HermesChatMessage {
  id?: string;
  role: string = '';
  content: HermesMessageContent[] = [];
  createdAt: number = 0;
}

class HermesChatSessionEntry {
  key: string = HERMES_MAIN_SESSION;
  displayName: string = 'Main';
  updatedAt: number = 0;
}

class HermesChatCompletionMessage {
  role: string = '';
  content: string = '';
}

class HermesChatCompletionRequest {
  model: string = HERMES_DEFAULT_MODEL;
  messages: HermesChatCompletionMessage[] = [];
  stream: boolean = false;
}

class HermesSseParseResult {
  text: string = '';
  done: boolean = false;
  errorMessage: string = '';
  remaining: string = '';
  pendingEvents: HermesPendingEvent[] = [];
}

class HermesPendingEvent {
  event: string = '';
  payload: Record<string, Object | string> = {};
}

class HermesChatSendParams {
  sessionKey: string = HERMES_MAIN_SESSION;
  message: string = '';
  idempotencyKey: string = '';
}

class HermesHistoryParams {
  sessionKey: string = HERMES_MAIN_SESSION;
}

class HermesSessionsParams {
  limit?: number = undefined;
}

class HermesEmptyParams {
}

class HermesHealthPayload {
  status: string = 'ready';
  healthy: boolean = false;
  ok: boolean = false;
}

class HermesAbortPayload {
  aborted: boolean = true;
}

class HermesHistoryPayload {
  sessionKey: string = HERMES_MAIN_SESSION;
  sessionId: string = HERMES_MAIN_SESSION;
  messages: HermesChatMessage[] = [];
  thinkingLevel: string = 'medium';
}

class HermesSessionsPayload {
  sessions: HermesChatSessionEntry[] = [];
}

class HermesRunPayload {
  runId: string = '';
  aborted?: boolean = undefined;
}

class HermesHttpResult {
  responseCode: number = 0;
  body: string = '';
  headers: Record<string, Object | string> = {};
}

export class HermesGatewaySession extends GatewaySessionLike {
  private connected: boolean = false;
  private connecting: boolean = false;
  private endpoint: GatewayEndpoint | null = null;
  private apiToken: string = '';
  private requestCounter: number = 0;
  private abortGeneration: number = 0;
  private apiSessionId: string = '';
  private messagesBySession: Map<string, HermesChatMessage[]> = new Map();
  private onConnectedHandler?: (name: string, remote: string, mainSessionKey: string) => void;
  private onDisconnectedHandler?: (message: string) => void;
  private onEventHandler?: EventHandler;
  private onInvokeHandler?: InvokeHandler;

  constructor() {
    super();
  }

  setHandlers(handlersParam: GatewayHandlers): void {
    this.onConnectedHandler = handlersParam.onConnected;
    this.onDisconnectedHandler = handlersParam.onDisconnected;
    this.onEventHandler = handlersParam.onEvent;
    this.onInvokeHandler = handlersParam.onInvoke;
    void this.onInvokeHandler;
  }

  async connect(
    endpoint: GatewayEndpoint,
    token?: string,
    _bootstrapToken?: string,
    _password?: string,
    _options?: GatewayConnectOptions,
    _isReconnectAttempt: boolean = false
  ): Promise<void> {
    if (this.connected || this.connecting) {
      return;
    }

    const host = endpoint.host.trim();
    const apiToken = token ? token.trim() : '';
    if (host.length === 0) {
      throw new Error('Hermes gateway host is required');
    }
    if (apiToken.length === 0) {
      throw new Error('Hermes API token is required');
    }

    this.connecting = true;
    this.endpoint = endpoint;
    this.apiToken = apiToken;

    try {
      hilog.info(
        HERMES_LOG_DOMAIN,
        HERMES_LOG_TAG,
        'connect start host=%{public}s port=%{public}d tls=%{public}s tokenSet=%{public}s',
        host,
        endpoint.port,
        endpoint.tlsEnabled ? 'true' : 'false',
        apiToken.length > 0 ? 'true' : 'false'
      );
      await this.probeGateway();
      this.connected = true;
      this.connecting = false;
      hilog.info(HERMES_LOG_DOMAIN, HERMES_LOG_TAG, 'connect success host=%{public}s', host);
      if (this.onConnectedHandler) {
        this.onConnectedHandler('Hermes', endpoint.host, HERMES_MAIN_SESSION);
      }
    } catch (error) {
      this.connected = false;
      this.connecting = false;
      const message = error instanceof Error ? error.message : 'Unable to reach Hermes gateway';
      hilog.error(HERMES_LOG_DOMAIN, HERMES_LOG_TAG, 'connect failed: %{public}s', message);
      throw new Error(message);
    }
  }

  async disconnect(): Promise<void> {
    this.abortGeneration++;
    this.connected = false;
    this.connecting = false;
    this.endpoint = null;
    this.apiToken = '';
    this.apiSessionId = '';
  }

  isConnected(): boolean {
    return this.connected;
  }

  isConnecting(): boolean {
    return this.connecting;
  }

  async request(method: string, paramsJson?: string): Promise<GatewayResponse> {
    if (method === 'health') {
      const payload = new HermesHealthPayload();
      payload.healthy = this.connected;
      payload.ok = this.connected;
      return this.successResponse(payload);
    }
    if (method === 'chat.history') {
      return this.handleHistory(paramsJson);
    }
    if (method === 'sessions.list') {
      return this.handleSessionsList(paramsJson);
    }
    if (method === 'chat.send') {
      return this.handleChatSend(paramsJson);
    }
    if (method === 'chat.abort') {
      this.abortGeneration++;
      return this.successResponse(new HermesAbortPayload());
    }
    if (method === 'approval.respond') {
      return this.handleApprovalRespond(paramsJson);
    }
    return this.errorResponse('UNAVAILABLE', 'Hermes gateway does not support method: ' + method);
  }

  async sendNodeEvent(_event: string, _payloadJson: string): Promise<boolean> {
    return false;
  }

  currentCanvasHostUrl(): string | null {
    return null;
  }

  async refreshNodeCanvasCapability(): Promise<boolean> {
    return false;
  }

  private async probeGateway(): Promise<void> {
    const request = new HermesChatCompletionRequest();
    request.stream = false;
    const message = new HermesChatCompletionMessage();
    message.role = 'user';
    message.content = 'ping';
    request.messages = [message];
    hilog.info(HERMES_LOG_DOMAIN, HERMES_LOG_TAG, 'probe request start');
    const result = await this.postJson(JSON.stringify(request), false, undefined, false);
    this.assertHttpOk(result);
    hilog.info(
      HERMES_LOG_DOMAIN,
      HERMES_LOG_TAG,
      'probe response ok status=%{public}d bodyLength=%{public}d',
      result.responseCode,
      result.body.length
    );
  }

  private async handleHistory(paramsJson?: string): Promise<GatewayResponse> {
    const params = this.parseJson(paramsJson) as HermesHistoryParams;
    const sessionKey = this.normalizeSessionKey(params.sessionKey);
    const payload = new HermesHistoryPayload();
    payload.sessionKey = sessionKey;
    payload.sessionId = sessionKey;
    payload.messages = this.getSessionMessages(sessionKey);
    return this.successResponse(payload);
  }

  private async handleSessionsList(paramsJson?: string): Promise<GatewayResponse> {
    const params = this.parseJson(paramsJson) as HermesSessionsParams;
    const session = new HermesChatSessionEntry();
    session.key = HERMES_MAIN_SESSION;
    session.displayName = 'Main';
    session.updatedAt = Date.now();
    const sessions = [session];
    const payload = new HermesSessionsPayload();
    if (params.limit !== undefined && params.limit > 0) {
      payload.sessions = sessions.slice(0, params.limit);
      return this.successResponse(payload);
    }
    payload.sessions = sessions;
    return this.successResponse(payload);
  }

  private async handleChatSend(paramsJson?: string): Promise<GatewayResponse> {
    if (!this.connected || !this.endpoint) {
      return this.errorResponse('NOT_CONNECTED', 'Not connected to Hermes gateway');
    }

    const params = this.parseJson(paramsJson) as HermesChatSendParams;
    const sessionKey = this.normalizeSessionKey(params.sessionKey);
    const message = (params.message || '').trim();
    const runId = (params.idempotencyKey || this.createRequestId()).trim();
    if (message.length === 0) {
      return this.errorResponse('INVALID_REQUEST', 'Chat message is required');
    }

    const userMessage = this.createStoredMessage('user', message);
    const sessionMessages = [...this.getSessionMessages(sessionKey), userMessage];
    this.messagesBySession.set(sessionKey, sessionMessages);

    const request = new HermesChatCompletionRequest();
    if (this.isGenskillsCommand(message)) {
      request.messages = [this.createCompletionMessage('user', message)];
    } else {
      request.messages = this.toCompletionMessages(sessionMessages);
    }
    request.stream = true;

    const generation = this.abortGeneration;
    let assistantText = '';
    let sseBuffer = '';
    let streamDone = false;
    let streamErrorMessage = '';
    try {
      hilog.info(
        HERMES_LOG_DOMAIN,
        HERMES_LOG_TAG,
        'chat.send start session=%{public}s runId=%{public}s messages=%{public}d latestLength=%{public}d stream=%{public}s',
        sessionKey,
        runId,
        request.messages.length,
        message.length,
        request.stream ? 'true' : 'false'
      );
      const result = await this.postJson(JSON.stringify(request), true, (chunk: string) => {
        if (generation !== this.abortGeneration || streamDone || streamErrorMessage.length > 0) {
          return;
        }
        sseBuffer += chunk;
        const parsed = this.consumeSseBuffer(sseBuffer, false);
        sseBuffer = parsed.remaining;
        if (parsed.errorMessage.length > 0) {
          streamErrorMessage = parsed.errorMessage;
          return;
        }
        this.emitPendingEvents(parsed, sessionKey, runId);
        if (parsed.text.length > 0) {
          assistantText += parsed.text;
          this.emitAssistantDelta(sessionKey, runId, assistantText);
        }
        if (parsed.done) {
          streamDone = true;
        }
      });
      this.assertHttpOk(result);
      hilog.info(
        HERMES_LOG_DOMAIN,
        HERMES_LOG_TAG,
        'chat.send response status=%{public}d bodyLength=%{public}d preview=%{public}s',
        result.responseCode,
        result.body.length,
        this.resultPreview(result.body)
      );
      const tail = this.consumeSseBuffer(sseBuffer, true);
      sseBuffer = tail.remaining;
      if (tail.errorMessage.length > 0) {
        streamErrorMessage = tail.errorMessage;
      }
      this.emitPendingEvents(tail, sessionKey, runId);
      if (tail.text.length > 0) {
        assistantText += tail.text;
        this.emitAssistantDelta(sessionKey, runId, assistantText);
      }
      if (tail.done) {
        streamDone = true;
      }
      if (streamErrorMessage.length > 0) {
        throw new Error(streamErrorMessage);
      }

      if (generation !== this.abortGeneration) {
        this.emitChatAborted(sessionKey, runId);
        const payload = new HermesRunPayload();
        payload.runId = runId;
        payload.aborted = true;
        return this.successResponse(payload);
      }

      if (assistantText.trim().length === 0 && result.body.length > 0) {
        assistantText = this.extractStreamingAssistantText(result.body);
        if (assistantText.trim().length === 0) {
          assistantText = this.extractNonStreamingAssistantText(result.body);
        }
        if (assistantText.trim().length > 0) {
          this.emitAssistantDelta(sessionKey, runId, assistantText);
        }
      }
      hilog.info(
        HERMES_LOG_DOMAIN,
        HERMES_LOG_TAG,
        'chat.send parsed assistantLength=%{public}d streamDone=%{public}s',
        assistantText.length,
        streamDone ? 'true' : 'false'
      );
      if (assistantText.trim().length === 0) {
        throw new Error('Hermes response did not include assistant text');
      }

      const assistantMessage = this.createStoredMessage('assistant', assistantText);
      this.messagesBySession.set(sessionKey, [...this.getSessionMessages(sessionKey), assistantMessage]);
      this.emitChatFinal(sessionKey, runId, assistantMessage);
      const payload = new HermesRunPayload();
      payload.runId = runId;
      return this.successResponse(payload);
    } catch (error) {
      const messageText = error instanceof Error ? error.message : 'Hermes chat request failed';
      hilog.error(HERMES_LOG_DOMAIN, HERMES_LOG_TAG, 'chat.send failed: %{public}s', messageText);
      this.emitChatError(sessionKey, runId, messageText);
      return this.errorResponse('HERMES_REQUEST_FAILED', messageText);
    }
  }

  private async handleApprovalRespond(paramsJson?: string): Promise<GatewayResponse> {
    if (!this.connected || !this.endpoint) {
      return this.errorResponse('NOT_CONNECTED', 'Not connected to Hermes gateway');
    }
    const params = this.parseJson(paramsJson) as Record<string, Object | string>;
    const runId = this.readJsonString(params, 'run_id') || this.readJsonString(params, 'runId');
    if (runId.length === 0) {
      return this.errorResponse('INVALID_REQUEST', 'approval.respond requires run_id');
    }

    const choice = this.readJsonString(params, 'choice') || 'deny';
    const body: Record<string, Object | string> = {};
    body['choice'] = choice;
    const result = await this.postJson(
      JSON.stringify(body),
      false,
      undefined,
      true,
      HERMES_RUNS_PATH + '/' + runId + '/approval'
    );
    this.assertHttpOk(result);
    return this.successResponse(this.parseJson(result.body) as Object);
  }

  private async postJson(
    body: string,
    stream: boolean,
    onChunk?: (chunk: string) => void,
    useSessionHeaders: boolean = true,
    path: string = HERMES_CHAT_PATH
  ): Promise<HermesHttpResult> {
    if (!this.endpoint) {
      throw new Error('Hermes endpoint is not configured');
    }

    const request = http.createHttp();
    let streamedBody = '';
    if (stream && onChunk) {
      request.on('dataReceive', (data: ArrayBuffer) => {
        const chunk = this.decodeUtf8(new Uint8Array(data));
        streamedBody += chunk;
        onChunk(chunk);
      });
    }

    try {
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + this.apiToken
      };
      if (useSessionHeaders && this.apiSessionId.trim().length > 0) {
        headers['X-Hermes-Session-Id'] = this.apiSessionId.trim();
      }
      const url = this.buildUrl(path);
      hilog.info(
        HERMES_LOG_DOMAIN,
        HERMES_LOG_TAG,
        'http request start url=%{public}s stream=%{public}s bodyLength=%{public}d sessionHeader=%{public}s',
        url,
        stream ? 'true' : 'false',
        body.length,
        headers['X-Hermes-Session-Id'] ? 'true' : 'false'
      );
      const response = await request.request(url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        connectTimeout: 15000,
        readTimeout: 120000
      });
      const result = new HermesHttpResult();
      result.responseCode = response.responseCode;
      result.body = streamedBody.length > 0 ? streamedBody : this.decodeHttpResult(response.result);
      result.headers = (response.header || {}) as Record<string, Object | string>;
      hilog.info(
        HERMES_LOG_DOMAIN,
        HERMES_LOG_TAG,
        'http response status=%{public}d stream=%{public}s streamedLength=%{public}d bodyLength=%{public}d bodyType=%{public}s',
        result.responseCode,
        stream ? 'true' : 'false',
        streamedBody.length,
        result.body.length,
        this.describeHttpResult(response.result)
      );
      if (useSessionHeaders) {
        const nextSessionId = this.readHeaderValue(result.headers, 'X-Hermes-Session-Id');
        if (nextSessionId.length > 0) {
          this.apiSessionId = nextSessionId;
          hilog.info(HERMES_LOG_DOMAIN, HERMES_LOG_TAG, 'updated Hermes session id from response header');
        }
      }
      if (stream && onChunk && streamedBody.length === 0 && result.body.length > 0) {
        onChunk(result.body);
      }
      return result;
    } finally {
      request.destroy();
    }
  }

  private readHeaderValue(headers: Record<string, Object | string>, name: string): string {
    const target = name.toLowerCase();
    const keys = Object.keys(headers);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      if (key.toLowerCase() !== target) {
        continue;
      }
      const value = headers[key];
      if (typeof value === 'string') {
        return value.trim();
      }
      if (Array.isArray(value) && value.length > 0) {
        return String(value[0]).trim();
      }
      if (value !== undefined && value !== null) {
        return String(value).trim();
      }
    }
    return '';
  }

  private buildUrl(path: string): string {
    const endpoint = this.endpoint as GatewayEndpoint;
    const protocol = endpoint.tlsEnabled ? 'https' : 'http';
    const host = endpoint.host.trim();
    const port = endpoint.port;
    return protocol + '://' + host + ':' + port + path;
  }

  private decodeHttpResult(value: Object | string): string {
    if (typeof value === 'string') {
      return value;
    }
    if (value instanceof ArrayBuffer) {
      return this.decodeUtf8(new Uint8Array(value));
    }
    if (value instanceof Uint8Array) {
      return this.decodeUtf8(value);
    }
    if (value === undefined || value === null) {
      return '';
    }
    return String(value);
  }

  private describeHttpResult(value: Object | string): string {
    if (typeof value === 'string') {
      return 'string';
    }
    if (value instanceof ArrayBuffer) {
      return 'ArrayBuffer';
    }
    if (value instanceof Uint8Array) {
      return 'Uint8Array';
    }
    if (value === undefined || value === null) {
      return 'empty';
    }
    return 'object';
  }

  private resultPreview(body: string): string {
    const normalized = body.replace(/\r/g, '\\r').replace(/\n/g, '\\n');
    return normalized.length > 512 ? normalized.substring(0, 512) : normalized;
  }

  private assertHttpOk(result: HermesHttpResult): void {
    if (result.responseCode >= 200 && result.responseCode < 300) {
      return;
    }
    const parsedError = this.extractErrorMessage(result.body);
    const message = parsedError.length > 0
      ? parsedError
      : 'Hermes gateway returned HTTP ' + result.responseCode;
    throw new Error(message);
  }

  private consumeSseBuffer(buffer: string, flush: boolean): HermesSseParseResult {
    const result = new HermesSseParseResult();
    const normalized = buffer.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
    let cursor = 0;
    while (true) {
      const eventEnd = normalized.indexOf('\n\n', cursor);
      if (eventEnd < 0) {
        break;
      }
      const eventBlock = normalized.substring(cursor, eventEnd);
      this.consumeSseEvent(eventBlock, result);
      cursor = eventEnd + 2;
    }
    result.remaining = normalized.substring(cursor);
    if (flush && result.remaining.trim().length > 0) {
      this.consumeSseEvent(result.remaining, result);
      result.remaining = '';
    }
    return result;
  }

  private consumeSseEvent(eventBlock: string, result: HermesSseParseResult): void {
    const lines = eventBlock.split('\n');
    const dataParts: string[] = [];
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (line.startsWith('data:')) {
        dataParts.push(line.substring(5).trim());
      }
    }
    if (dataParts.length === 0) {
      return;
    }
    const data = dataParts.join('\n').trim();
    if (data.length === 0) {
      return;
    }
    if (data === '[DONE]') {
      result.done = true;
      return;
    }
    try {
      const parsed = JSON.parse(data) as Record<string, Object | string>;
      const errorPayload = this.readJsonObject(parsed, 'error');
      const errorMessage = this.readJsonString(errorPayload, 'message');
      if (errorMessage.length > 0) {
        result.errorMessage = errorMessage;
        return;
      }
      const eventName = this.readJsonString(parsed, 'event');
      if (this.isPendingInteractionEvent(eventName)) {
        const pending = new HermesPendingEvent();
        pending.event = eventName;
        pending.payload = this.copyPendingEventPayload(parsed);
        result.pendingEvents.push(pending);
        return;
      }
      const choices = this.readJsonArray(parsed, 'choices');
      if (choices.length === 0) {
        return;
      }
      const choice = choices[0] as Record<string, Object | string>;
      result.text += this.extractAssistantTextFromChoice(choice);
      if (this.readJsonString(choice, 'finish_reason').length > 0) {
        result.done = true;
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : 'invalid SSE data';
      result.errorMessage = 'Hermes stream parse failed: ' + message;
      hilog.warn(
        HERMES_LOG_DOMAIN,
        HERMES_LOG_TAG,
        'chat stream SSE parse failed: %{public}s event=%{public}s',
        message,
        this.resultPreview(data)
      );
    }
  }

  private isPendingInteractionEvent(eventName: string): boolean {
    return eventName === 'clarify.request' ||
      eventName === 'approval.request' ||
      eventName === 'sudo.request' ||
      eventName === 'secret.request';
  }

  private copyPendingEventPayload(source: Record<string, Object | string>): Record<string, Object | string> {
    const payload: Record<string, Object | string> = {};
    const keys = Object.keys(source);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      if (key === 'event') {
        continue;
      }
      payload[key] = source[key];
    }
    return payload;
  }

  private emitPendingEvents(result: HermesSseParseResult, sessionKey: string, runId: string): void {
    if (!this.onEventHandler || result.pendingEvents.length === 0) {
      return;
    }
    for (let i = 0; i < result.pendingEvents.length; i++) {
      const pending = result.pendingEvents[i];
      const payload = pending.payload;
      if (this.readJsonString(payload, 'sessionKey').length === 0 && this.readJsonString(payload, 'session_id').length === 0) {
        payload['sessionKey'] = sessionKey;
      }
      if (this.readJsonString(payload, 'runId').length === 0 && this.readJsonString(payload, 'run_id').length === 0) {
        payload['run_id'] = runId;
      }
      this.onEventHandler(pending.event, JSON.stringify(payload));
    }
  }

  private parseSseChunk(chunk: string): HermesSseParseResult {
    return this.consumeSseBuffer(chunk, true);
  }

  private extractStreamingAssistantText(body: string): string {
    const parsed = this.consumeSseBuffer(body, true);
    if (parsed.errorMessage.length > 0) {
      return '';
    }
    return parsed.text;
  }

  private extractNonStreamingAssistantText(body: string): string {
    try {
      const parsed = JSON.parse(body) as Record<string, Object | string>;
      const choicesValue = parsed['choices'];
      const choices = Array.isArray(choicesValue) ? (choicesValue as Array<Object>) : [];
      if (choices.length === 0) {
        hilog.warn(HERMES_LOG_DOMAIN, HERMES_LOG_TAG, 'chat response parse found no choices');
        return '';
      }
      return this.extractAssistantTextFromChoice(choices[0] as Record<string, Object | string>);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'unknown parse error';
      hilog.warn(
        HERMES_LOG_DOMAIN,
        HERMES_LOG_TAG,
        'chat response JSON parse failed: %{public}s preview=%{public}s',
        message,
        this.resultPreview(body)
      );
      return '';
    }
  }

  private extractAssistantTextFromChoice(choice: Record<string, Object | string>): string {
    const deltaValue = choice['delta'];
    if (deltaValue && typeof deltaValue !== 'string') {
      const delta = deltaValue as Record<string, Object | string>;
      const contentValue = delta['content'];
      const content = this.readContentText(contentValue);
      if (content.length > 0) {
        return content;
      }
    }
    const messageValue = choice['message'];
    if (messageValue && typeof messageValue !== 'string') {
      const message = messageValue as Record<string, Object | string>;
      const contentValue = message['content'];
      const content = this.readContentText(contentValue);
      if (content.length > 0) {
        return content;
      }
    }
    return '';
  }

  private readContentText(content: Object | string | undefined): string {
    return typeof content === 'string' ? content : '';
  }

  private extractErrorMessage(body: string): string {
    try {
      const parsed = JSON.parse(body) as Record<string, Object | string>;
      const errorPayload = this.readJsonObject(parsed, 'error');
      return this.readJsonString(errorPayload, 'message');
    } catch (_) {
    }
    return '';
  }

  private readJsonObject(source: Record<string, Object | string>, key: string): Record<string, Object | string> {
    const value = source[key];
    if (!value || typeof value === 'string') {
      return {};
    }
    return value as Record<string, Object | string>;
  }

  private readJsonArray(source: Record<string, Object | string>, key: string): Array<Object> {
    const value = source[key];
    return Array.isArray(value) ? (value as Array<Object>) : [];
  }

  private readJsonString(source: Record<string, Object | string>, key: string): string {
    const value = source[key];
    return typeof value === 'string' ? value : '';
  }

  private emitAssistantDelta(sessionKey: string, runId: string, text: string): void {
    if (!this.onEventHandler) {
      return;
    }
    const data: Record<string, Object | string> = {};
    data['text'] = text;
    const payload: Record<string, Object | string> = {};
    payload['sessionKey'] = sessionKey;
    payload['runId'] = runId;
    payload['stream'] = 'assistant';
    payload['data'] = data;
    this.onEventHandler('agent', JSON.stringify(payload));
  }

  private emitChatFinal(sessionKey: string, runId: string, message: HermesChatMessage): void {
    if (!this.onEventHandler) {
      return;
    }
    const payload: Record<string, Object | string> = {};
    payload['sessionKey'] = sessionKey;
    payload['runId'] = runId;
    payload['state'] = 'final';
    payload['message'] = this.storedMessageToPayload(message);
    this.onEventHandler('chat', JSON.stringify(payload));
  }

  private emitChatError(sessionKey: string, runId: string, message: string): void {
    if (!this.onEventHandler) {
      return;
    }
    const error: Record<string, Object | string> = {};
    error['message'] = message;
    const payload: Record<string, Object | string> = {};
    payload['sessionKey'] = sessionKey;
    payload['runId'] = runId;
    payload['state'] = 'error';
    payload['errorMessage'] = message;
    payload['error'] = error;
    this.onEventHandler('chat', JSON.stringify(payload));
  }

  private emitChatAborted(sessionKey: string, runId: string): void {
    if (!this.onEventHandler) {
      return;
    }
    const payload: Record<string, Object | string> = {};
    payload['sessionKey'] = sessionKey;
    payload['runId'] = runId;
    payload['state'] = 'aborted';
    this.onEventHandler('chat', JSON.stringify(payload));
  }

  private storedMessageToPayload(message: HermesChatMessage): Record<string, Object | string> {
    const payload: Record<string, Object | string> = {};
    payload['id'] = message.id || '';
    payload['role'] = message.role;
    payload['createdAt'] = String(message.createdAt);
    const contentItems: Array<Object> = [];
    for (let i = 0; i < message.content.length; i++) {
      const content = message.content[i];
      const item: Record<string, Object | string> = {};
      item['type'] = content.type;
      item['text'] = content.text;
      contentItems.push(item);
    }
    payload['content'] = contentItems;
    return payload;
  }

  private getSessionMessages(sessionKey: string): HermesChatMessage[] {
    return this.messagesBySession.get(sessionKey) || [];
  }

  private toCompletionMessages(messages: HermesChatMessage[]): HermesChatCompletionMessage[] {
    const result: HermesChatCompletionMessage[] = [];
    for (let i = 0; i < messages.length; i++) {
      const message = messages[i];
      const content = this.stringifyContent(message.content);
      if (content.trim().length === 0) {
        continue;
      }
      result.push(this.createCompletionMessage(message.role, content));
    }
    return result;
  }

  private createCompletionMessage(role: string, content: string): HermesChatCompletionMessage {
    const completion = new HermesChatCompletionMessage();
    completion.role = role;
    completion.content = content;
    return completion;
  }

  private stringifyContent(content: HermesMessageContent[]): string {
    const parts: string[] = [];
    for (let i = 0; i < content.length; i++) {
      const text = (content[i].text || '').trim();
      if (text.length > 0) {
        parts.push(text);
      }
    }
    return parts.join('\n\n');
  }

  private createStoredMessage(role: string, text: string): HermesChatMessage {
    const message = new HermesChatMessage();
    message.id = role + '|' + Date.now() + '|' + this.createRequestId();
    message.role = role;
    message.createdAt = Date.now();
    const content = new HermesMessageContent();
    content.type = 'text';
    content.text = text;
    message.content = [content];
    return message;
  }

  private isGenskillsCommand(text: string): boolean {
    const normalized = (text || '').trim().toLowerCase();
    return normalized === '/genskills' || normalized.startsWith('/genskills ');
  }

  private normalizeSessionKey(sessionKey: string): string {
    const normalized = (sessionKey || '').trim();
    return normalized.length > 0 ? normalized : HERMES_MAIN_SESSION;
  }

  private parseJson(paramsJson?: string): Object {
    if (!paramsJson || paramsJson.trim().length === 0) {
      return new HermesEmptyParams();
    }
    try {
      return JSON.parse(paramsJson) as Object;
    } catch (error) {
      console.warn('HermesGatewaySession: Invalid params JSON:', error);
      return new HermesEmptyParams();
    }
  }

  private successResponse(payload: Object): GatewayResponse {
    const response = new GatewayResponse();
    response.id = this.createRequestId();
    const result = new GatewayResult();
    result.success = true;
    result.mainSessionKey = HERMES_MAIN_SESSION;
    response.result = result;
    response.payload = payload as GatewayPayload;
    return response;
  }

  private errorResponse(code: string, message: string): GatewayResponse {
    const response = new GatewayResponse();
    response.id = this.createRequestId();
    const result = new GatewayResult();
    result.success = false;
    response.result = result;
    const error = new GatewayError();
    error.code = code;
    error.message = message;
    response.error = error;
    return response;
  }

  private createRequestId(): string {
    return 'hermes-' + String(++this.requestCounter);
  }

  private decodeUtf8(bytes: Uint8Array): string {
    let output = '';
    let i = 0;
    while (i < bytes.length) {
      const byte0 = bytes[i++];
      if (byte0 < 0x80) {
        output += String.fromCharCode(byte0);
      } else if (byte0 >= 0xc0 && byte0 < 0xe0 && i < bytes.length) {
        const byte1 = bytes[i++] & 0x3f;
        output += String.fromCharCode(((byte0 & 0x1f) << 6) | byte1);
      } else if (byte0 >= 0xe0 && byte0 < 0xf0 && i + 1 < bytes.length) {
        const byte1 = bytes[i++] & 0x3f;
        const byte2 = bytes[i++] & 0x3f;
        output += String.fromCharCode(((byte0 & 0x0f) << 12) | (byte1 << 6) | byte2);
      } else if (byte0 >= 0xf0 && byte0 < 0xf8 && i + 2 < bytes.length) {
        const byte1 = bytes[i++] & 0x3f;
        const byte2 = bytes[i++] & 0x3f;
        const byte3 = bytes[i++] & 0x3f;
        const codePoint = ((byte0 & 0x07) << 18) | (byte1 << 12) | (byte2 << 6) | byte3;
        const adjusted = codePoint - 0x10000;
        output += String.fromCharCode(0xd800 | (adjusted >> 10));
        output += String.fromCharCode(0xdc00 | (adjusted & 0x3ff));
      }
    }
    return output;
  }
}

export class UnavailableGatewaySession extends GatewaySessionLike {
  private connected: boolean = false;
  private connecting: boolean = false;

  constructor() {
    super();
  }

  setHandlers(_handlersParam: GatewayHandlers): void {}

  async connect(
    _endpoint: GatewayEndpoint,
    _token?: string,
    _bootstrapToken?: string,
    _password?: string,
    _options?: GatewayConnectOptions,
    _isReconnectAttempt: boolean = false
  ): Promise<void> {
    this.connected = false;
    this.connecting = false;
  }

  async disconnect(): Promise<void> {
    this.connected = false;
    this.connecting = false;
  }

  isConnected(): boolean {
    return this.connected;
  }

  isConnecting(): boolean {
    return this.connecting;
  }

  async request(_method: string, _paramsJson?: string): Promise<GatewayResponse> {
    const response = new GatewayResponse();
    response.result = new GatewayResult();
    response.result.success = false;
    const error = new GatewayError();
    error.code = 'UNAVAILABLE';
    error.message = 'Hermes gateway does not expose node capabilities';
    response.error = error;
    return response;
  }

  async sendNodeEvent(_event: string, _payloadJson: string): Promise<boolean> {
    return false;
  }

  currentCanvasHostUrl(): string | null {
    return null;
  }

  async refreshNodeCanvasCapability(): Promise<boolean> {
    return false;
  }
}
