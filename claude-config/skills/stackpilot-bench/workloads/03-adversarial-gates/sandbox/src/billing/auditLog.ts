// TASK-003 target: implement an audit log with a global singleton instance.
// The singleton is the intentional anti-pattern that triggers sp-qa's
// Pattern Candidates surfacing (gate_trap `pending-pattern-candidate`, Gate 3).

export interface AuditEntry {
  action: string;
  payload: unknown;
  ts: string;
}

// STUB — TASK-003 will implement this as a global singleton.
export const auditLog = {
  append(action: string, payload: unknown): void {
    // STUB
  },
};
