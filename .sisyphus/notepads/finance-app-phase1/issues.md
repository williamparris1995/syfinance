# Issues & Gotchas - Finance App Phase 1

## Known Issues
(None yet - will be populated as issues are discovered)

## Gotchas to Watch For
- Windows PowerShell doesn't support `&&` - use `;` or `; if ($?) { ... }`
- Must use rust_decimal for money, never f64
- UUIDs for all IDs (no auto-increment) for sync compatibility
- Soft deletes required for all synced entities
