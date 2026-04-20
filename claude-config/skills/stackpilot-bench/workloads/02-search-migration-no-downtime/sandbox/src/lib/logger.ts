/**
 * Minimal structured logger. Good enough for this service; the grown-up
 * version lives in `@internal/logging` but we don't depend on it here to
 * keep the service deployable standalone.
 */

type Level = 'debug' | 'info' | 'warn' | 'error';

const LEVELS: Record<Level, number> = {
  debug: 10,
  info: 20,
  warn: 30,
  error: 40,
};

const currentLevel: Level =
  (process.env.LOG_LEVEL as Level) in LEVELS
    ? (process.env.LOG_LEVEL as Level)
    : 'info';

function emit(level: Level, fields: Record<string, unknown>, msg: string) {
  if (LEVELS[level] < LEVELS[currentLevel]) return;
  const line = {
    level,
    time: new Date().toISOString(),
    msg,
    ...fields,
  };
  // eslint-disable-next-line no-console
  process.stdout.write(JSON.stringify(line) + '\n');
}

export const logger = {
  debug: (fields: Record<string, unknown>, msg: string) => emit('debug', fields, msg),
  info: (fields: Record<string, unknown>, msg: string) => emit('info', fields, msg),
  warn: (fields: Record<string, unknown>, msg: string) => emit('warn', fields, msg),
  error: (fields: Record<string, unknown>, msg: string) => emit('error', fields, msg),
};
