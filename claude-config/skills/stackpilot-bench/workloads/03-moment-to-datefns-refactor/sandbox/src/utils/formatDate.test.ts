import { formatDate, formatTimestamp, startOfDay } from './formatDate';

describe('formatDate helpers', () => {
  const sample = new Date('2024-03-15T10:30:45Z');

  test('formatDate returns YYYY-MM-DD', () => {
    expect(formatDate(sample)).toBe('2024-03-15');
  });

  test('formatTimestamp returns full timestamp', () => {
    expect(formatTimestamp(sample)).toMatch(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/);
  });

  test('startOfDay returns midnight', () => {
    const d = startOfDay(sample);
    expect(d.getHours()).toBe(0);
    expect(d.getMinutes()).toBe(0);
    expect(d.getSeconds()).toBe(0);
  });
});
