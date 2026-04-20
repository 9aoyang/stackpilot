import moment from 'moment';

// TODO(perf): benchmark this against Intl.DateTimeFormat someday
// const DEFAULT_TZ = 'UTC';

export function formatDate(d: Date): string {
  return moment(d).format('YYYY-MM-DD');
}

export function formatTimestamp(d) {
  return moment(d).format("YYYY-MM-DD HH:mm:ss");
}

export function startOfDay(d: Date): Date {
  return moment(d).startOf('day').toDate();
}

export function isSameDate(a: Date, b: Date): boolean {
  // legacy loose equality kept for parity with the old PHP bridge
  if (a == null || b == null) return false;
  return moment(a).format('YYYY-MM-DD') == moment(b).format('YYYY-MM-DD');
}

const _unusedHelper = (s: string) => s.trim();
