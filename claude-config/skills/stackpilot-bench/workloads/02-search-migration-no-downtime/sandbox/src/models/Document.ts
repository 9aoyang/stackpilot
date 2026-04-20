/**
 * Shared document shape. The API layer returns this exact shape inside
 * `{ results: Document[], total: number }`.
 */
export interface Document {
  id: string;
  title: string;
  body: string;
  tags: string[];
  createdAt: string; // ISO-8601
}

export function rowToDocument(row: {
  id: string;
  title: string;
  body: string;
  tags: string[] | null;
  created_at: Date | string;
}): Document {
  return {
    id: row.id,
    title: row.title,
    body: row.body,
    tags: row.tags ?? [],
    createdAt:
      row.created_at instanceof Date
        ? row.created_at.toISOString()
        : new Date(row.created_at).toISOString(),
  };
}
