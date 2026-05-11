/**
 * jest.setup.js
 * Jest test setup file - mocks and global configurations
 */

jest.setTimeout(30000);

const mockExit = jest.spyOn(process, 'exit').mockImplementation((code) => {
  throw new Error(`Process exit with code ${code}`);
});

beforeEach(() => {
  mockExit.mockClear();
  jest.clearAllMocks();
});

afterAll(() => {
  mockExit.mockRestore();
});

global.mockConsole = () => {
  const originalLog = console.log;
  const originalError = console.error;
  const originalWarn = console.warn;
  
  const logs = [];
  const errors = [];
  const warns = [];
  
  console.log = (...args) => logs.push(args);
  console.error = (...args) => errors.push(args);
  console.warn = (...args) => warns.push(args);
  
  return {
    logs,
    errors,
    warns,
    restore: () => {
      console.log = originalLog;
      console.error = originalError;
      console.warn = originalWarn;
    }
  };
};

