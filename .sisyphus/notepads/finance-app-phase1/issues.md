# Issues & Gotchas - Finance App Phase 1

## Known Issues
(None yet - will be populated as issues are discovered)

## Gotchas to Watch For
- Windows PowerShell doesn't support `&&` - use `;` or `; if ($?) { ... }`
- Must use rust_decimal for money, never f64
- UUIDs for all IDs (no auto-increment) for sync compatibility
- Soft deletes required for all synced entities
## [2026-04-07] Task 4: Diagnostics Tool Limitation
- `cargo test` and `pnpm vitest run` both passed, but the LSP diagnostics tool still reported `rust-analyzer` as unavailable even after `rust-analyzer.exe` was confirmed present and up to date via `rustup`.
- TypeScript diagnostics succeeded (`No diagnostics found`) for the frontend test/config files.
