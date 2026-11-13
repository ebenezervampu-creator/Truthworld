/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['<rootDir>/tests/**/*.test.ts'],
  setupFiles: ['dotenv/config'],
  setupFilesAfterEnv: ['<rootDir>/tests/setup.ts'],
  transform: {
    '^.+\\.tsx?$': [
      'ts-jest',
      {
        tsconfig: {
          target: 'es2020',
          module: 'commonjs',
          moduleResolution: 'node',
          esModuleInterop: true,
          skipLibCheck: true,
          resolveJsonModule: true,
          noUnusedLocals: false,
        },
      },
    ],
  },
  moduleFileExtensions: ['ts', 'js', 'json', 'node'],
  moduleNameMapper: {
    '^(\\.{1,2}/.*)\\.js$': '$1',
  },
  coverageDirectory: '<rootDir>/coverage',
  collectCoverageFrom: [
    'src/utils/**/*.ts',
    'src/services/**/*.ts',
    'src/shared/**/*.ts',
    'src/community/**/*.ts',
    'src/economy/**/*.ts',
    'src/feed/**/*.ts',
    'src/admin/**/*.ts',
    'src/watchtime/**/*.ts',
    'src/search/**/*.ts',
    'src/channels/**/*.ts',
    'src/pipeline/**/*.ts',
    '!src/**/*.d.ts',
    '!src/**/__tests__/**',
    '!src/benchmark/**',
    '!src/pipeline/benchmarks/**',
    '!src/seo/**',
    '!src/resolution/**'
  ],
  coverageReporters: ['text', 'lcov', 'json-summary'],
  testTimeout: 15000,
  verbose: true,
};
