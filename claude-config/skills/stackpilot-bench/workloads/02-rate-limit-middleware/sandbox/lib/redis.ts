// Stubbed redis client. Real project swaps this for ioredis.
// The interface mirrors ioredis so the real client drops in later.

const store = new Map<string, { value: number; expiresAt: number | null }>();

export const redis = {
  async get(key: string): Promise<string | null> {
    const entry = store.get(key);
    if (!entry) return null;
    if (entry.expiresAt !== null && entry.expiresAt < Date.now()) {
      store.delete(key);
      return null;
    }
    return String(entry.value);
  },

  async incr(key: string): Promise<number> {
    const entry = store.get(key);
    if (!entry || (entry.expiresAt !== null && entry.expiresAt < Date.now())) {
      store.set(key, { value: 1, expiresAt: null });
      return 1;
    }
    entry.value += 1;
    return entry.value;
  },

  async expire(key: string, seconds: number): Promise<number> {
    const entry = store.get(key);
    if (!entry) return 0;
    entry.expiresAt = Date.now() + seconds * 1000;
    return 1;
  },

  async pttl(key: string): Promise<number> {
    const entry = store.get(key);
    if (!entry || entry.expiresAt === null) return -1;
    return Math.max(0, entry.expiresAt - Date.now());
  },

  async __reset(): Promise<void> {
    store.clear();
  },
};
