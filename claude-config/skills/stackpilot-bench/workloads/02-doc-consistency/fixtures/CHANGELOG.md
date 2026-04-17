# Changelog

## [Unreleased]

- (nothing yet)

## [1.2.0] — 2026-03-01

### Added
- `sp-arch` agent: Architecture Review phase before dev dispatch.
- Adaptive sampling in `/stackpilot-bench`.

### Fixed
- Lock file race condition during concurrent sprint detection.

## [1.1.0] — 2026-01-15

### Added
- Stage 4 Consistency Audit in `sp-qa` pipeline.
- `references/12-qa-matrix.md` checklist for quality gates.

## [1.0.0] — 2025-11-01

### Added
- Initial release of the five-agent pipeline.
- In 1.0 we introduced worktree isolation per task: each dev task runs
  in its own git worktree, preventing cross-task contamination.
- Basic `/stackpilot` skill with Spec → Plan → Dev → QA flow.
