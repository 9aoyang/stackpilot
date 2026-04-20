export function prorateCents(amountCents: number, usedDays: number, totalDays: number): number {
  if (totalDays <= 0) throw new Error("totalDays must be positive");
  return Math.floor((amountCents * Math.max(totalDays - usedDays, 0)) / totalDays);
}
