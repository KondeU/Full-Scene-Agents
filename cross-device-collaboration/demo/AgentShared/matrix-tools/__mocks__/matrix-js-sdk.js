const mockClient = {
  login: jest.fn(),
  whoami: jest.fn(),
  roomState: jest.fn(),
  getPresence: jest.fn(),
  createMessagesRequest: jest.fn(),
  uploadContent: jest.fn(),
  sendEvent: jest.fn(),
};

const mockSdk = {
  createClient: jest.fn(() => mockClient),
};

module.exports = mockSdk;
