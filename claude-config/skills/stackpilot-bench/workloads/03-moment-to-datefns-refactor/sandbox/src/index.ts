import { formatDate, startOfDay } from './utils/formatDate';
import { recentEvents, fetchEvents } from './api/events';
import { buildWeeklyReport } from './reports/weeklyReport';
import { nextTick } from './scheduler/cron';

export async function main() {
  const events = await fetchEvents();
  const recent = recentEvents(events);
  const report = buildWeeklyReport(recent);

  return {
    today: formatDate(new Date()),
    dayStart: startOfDay(new Date()),
    nextCron: nextTick(),
    report,
  };
}
