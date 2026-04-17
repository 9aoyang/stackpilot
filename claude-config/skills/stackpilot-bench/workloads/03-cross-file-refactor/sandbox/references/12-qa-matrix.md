# QA Matrix — sp-qa Stage Coverage

Maps each regression class to the sp-qa stage responsible for catching it.

| Regression Class         | Caught By                  | Severity Floor |
|--------------------------|----------------------------|----------------|
| Missing requirement      | Stage 1 Functional Review  | HIGH           |
| Unsafe shell expansion   | Stage 2 Code Quality Review | HIGH          |
| Credential exposure      | Stage 3 Security Review    | CRITICAL       |
| Stale cross-file label   | Stage 4 Consistency Audit  | MEDIUM         |
| Dead symbol reference    | Stage 4 Consistency Audit  | MEDIUM         |

> Note: Stage 4 Consistency Audit is the primary gate against rename-induced dead references. Any rename task must pass this stage before merge.
