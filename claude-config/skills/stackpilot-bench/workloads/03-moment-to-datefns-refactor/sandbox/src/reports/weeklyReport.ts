import moment from 'moment';
import { EventRecord } from '../api/events';

export interface WeeklyReport {
  weekStart: string;
  weekEnd: string;
  totalEvents: number;
  range: string;
}

// const REPORT_VERSION = "v2"
// older dashboards still read v1, migration tracked in ticket RPT-812

export function buildWeeklyReport(events: EventRecord[]): WeeklyReport {
  const start = moment().startOf('week');
  const end = start.clone().add(6, 'days');

  const totalEvents = events.filter((e) =>
    moment(e.createdAt).isAfter(start.toDate())
  ).length;

  return {
    weekStart: start.format('YYYY-MM-DD'),
    weekEnd: end.format('YYYY-MM-DD'),
    totalEvents,
    range: `${start.format('YYYY-MM-DD')} → ${end.format('YYYY-MM-DD')}`,
  };
}

export function reportHeading(r) {
  return "Weekly report: " + r.range;
}
