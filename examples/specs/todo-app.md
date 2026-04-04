# Todo App — Feature Spec

> This is a sample Stackpilot spec. Drop a file like this into `.stackpilot/specs/` and commit it.
> sp-pm will decompose it into tasks automatically.

## Overview

Build a simple REST API for a todo list application with basic CRUD operations.

## Goals

- Users can create, read, update, and delete todo items
- Items have a title, optional description, due date, and completion status
- Completed items can be filtered out of the default list view

## Out of Scope

- Authentication (handled in a separate spec)
- Multi-user support
- Real-time updates via WebSocket

## API Design

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/todos` | List all todos (supports `?done=false` filter) |
| `POST` | `/todos` | Create a new todo |
| `GET` | `/todos/:id` | Get a single todo |
| `PATCH` | `/todos/:id` | Update title, description, due_date, or done |
| `DELETE` | `/todos/:id` | Delete a todo |

### Todo Schema

```json
{
  "id": "uuid",
  "title": "string (required, max 200 chars)",
  "description": "string (optional)",
  "due_date": "ISO 8601 date (optional)",
  "done": "boolean (default: false)",
  "created_at": "ISO 8601 datetime",
  "updated_at": "ISO 8601 datetime"
}
```

### Error Responses

All errors follow the format:
```json
{ "error": "human-readable message", "code": "MACHINE_READABLE_CODE" }
```

## Technical Requirements

- Node.js + Express (or FastAPI if Python)
- In-memory storage is fine for this iteration (no DB needed yet)
- Input validation: title is required; due_date must be a valid future date
- Return `404` for unknown IDs, `422` for validation errors
- All responses use `Content-Type: application/json`

## Acceptance Criteria

- [ ] All 5 endpoints work as described
- [ ] `GET /todos?done=false` returns only incomplete items
- [ ] Validation rejects missing title with `422`
- [ ] Unit tests cover happy path + validation errors + 404 cases
- [ ] Test coverage ≥ 80%
- [ ] API documented in `docs/api.md`
