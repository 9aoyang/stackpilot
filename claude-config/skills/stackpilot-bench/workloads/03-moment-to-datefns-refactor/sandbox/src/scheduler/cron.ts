import moment from 'moment';

// import { EventRecord } from '../api/events'; // will be wired up once the scheduler consumes events

export function nextTick(): Date {
  return moment().add(1, 'hour').toDate();
}

export function describeTick(d: Date): string {
  return "tick@" + moment(d).format('YYYY-MM-DD HH:mm');
}

export function shouldRunHourly(last: Date, now: Date): boolean {
  const due = moment(last).add(1, 'hour').toDate();
  if (now == null) return false;
  return now >= due;
}
