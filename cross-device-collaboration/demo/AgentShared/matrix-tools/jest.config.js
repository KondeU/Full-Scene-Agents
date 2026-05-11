module.exports = {
  rootDir: __dirname,
  testEnvironment: 'node',
  setupFilesAfterEnv: ['./jest.setup.js'],
  testMatch: ['<rootDir>/*.test.js'],
  moduleNameMapper: {
    '^matrix-js-sdk$': '<rootDir>/__mocks__/matrix-js-sdk.js'
  },
  collectCoverage: true,
  collectCoverageFrom: [
    '_common.js',
    'upload_file.js',
    'get_chat_history.js',
    'obtain_access_token.js',
    'get_member_presence.js',
    'install_matrix-js-sdk.js'
  ],
  coverageDirectory: './coverage',
  coverageReporters: ['text', 'lcov', 'html'],
  verbose: true,
  testTimeout: 10000
};