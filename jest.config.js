const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  moduleNameMapper: {
    ...(jestConfig.moduleNameMapper || {}),
    "^lightning/accApi$":
      "<rootDir>/force-app/test/jest-mocks/lightning/accApi.js"
  },
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"]
};
