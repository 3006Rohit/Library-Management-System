module.exports = {
  open: jest.fn(() => Promise.resolve()),
  close: jest.fn(() => Promise.resolve()),
  execute: jest.fn(() => Promise.resolve()),
  reset: jest.fn(() => Promise.resolve())
};
