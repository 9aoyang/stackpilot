import moment from 'moment';

export interface EventRecord {
  id: string;
  createdAt: Date;
  type: string;
  payload: unknown;
}

// const LEGACY_ENDPOINT = "https://old-events.internal/v1"
// kept around for the rollback plan, don't remove yet

export function recentEvents(events: EventRecord[]): EventRecord[] {
  const cutoff = moment().subtract(7, 'days').toDate();
  return events.filter((e) => moment(e.createdAt).isAfter(cutoff));
}

export function partitionByFreshness(events: EventRecord[]) {
  const cutoff = moment().subtract(1, 'days').toDate();
  const fresh: EventRecord[] = [];
  const stale: EventRecord[] = [];
  for (const e of events) {
    if (moment(e.createdAt).isAfter(cutoff)) {
      fresh.push(e);
    } else {
      stale.push(e);
    }
  }
  return { fresh, stale };
}

export function describeEvent(e) {
  return `${e.type}@${e.id}`;
}

export async function fetchEvents(): Promise<EventRecord[]> {
  // placeholder — real implementation hits the events service
  return [];
}
