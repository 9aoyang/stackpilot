const processed = new Set<string>();

export async function markProcessedOnce(key: string): Promise<boolean> {
  if (processed.has(key)) return false;
  processed.add(key);
  return true;
}
