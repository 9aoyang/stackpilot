---
name: update-gstack
description: Update the gstack skills repo and verify all required skills are present. Rolls back automatically if verification fails.
---

Run the gstack auto-updater script to pull the latest gstack skills.

Steps:
1. Find the stackpilot repo (check common locations: ~/Documents/github/stackpilot, ~/stackpilot, or ask user)
2. Run: `bash scripts/update-gstack.sh`
3. Report the result: success (silent), or the rollback reason if it failed
