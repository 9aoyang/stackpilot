-- 001_create_documents.sql
--
-- Creates the documents table and the composite GIN index we currently
-- use for ILIKE search. Applied in prod on 2025-08-12.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS documents (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title       TEXT NOT NULL,
    body        TEXT NOT NULL DEFAULT '',
    tags        TEXT[] NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS documents_title_trgm
    ON documents USING gin (title gin_trgm_ops);

CREATE INDEX IF NOT EXISTS documents_body_trgm
    ON documents USING gin (body gin_trgm_ops);

CREATE INDEX IF NOT EXISTS documents_created_at_idx
    ON documents (created_at DESC);
