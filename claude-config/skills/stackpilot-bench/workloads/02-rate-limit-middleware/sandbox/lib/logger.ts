type Fields = Record<string, unknown>;

function emit(level: 'info' | 'warn' | 'error', msg: string, fields?: Fields): void {
  const payload = { level, msg, ...(fields ?? {}) };
  // Minimal sink — real project pipes to pino / datadog. Kept quiet in tests.
  if (process.env.LOG_SILENT === '1') return;
  // eslint-disable-next-line no-console
  (level === 'error' ? console.error : level === 'warn' ? console.warn : console.info)(
    JSON.stringify(payload),
  );
}

export const logger = {
  info(msg: string, fields?: Fields): void {
    emit('info', msg, fields);
  },
  warn(msg: string, fields?: Fields): void {
    emit('warn', msg, fields);
  },
  error(msg: string, fields?: Fields): void {
    emit('error', msg, fields);
  },
};
