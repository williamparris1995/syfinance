## Coding Standards

**CRITICAL**: All generated Rust code MUST follow `docs/CODING_STANDARDS.md`

### Mandatory Rules (Will Fail CI)

1. **Use ORM (SeaORM)** - NO hardcoded SQL field names
   ```rust
   ❌ sqlx::query!("SELECT id, title FROM reminders")
   ✅ Reminders::find().all(&db).await?
   ```

2. **Use tracing, NOT println!**
   ```rust
   ❌ println!("Error: {}", e);
   ✅ error!(error = %e, "Failed to process");
   ```

3. **Use serde for enums, NO hardcoded strings**
   ```rust
   ❌ match s { "LOW" => Ok(Self::Low), ... }
   ✅ #[derive(Serialize, Deserialize)]
      #[serde(rename_all = "SCREAMING_SNAKE_CASE")]
      pub enum Priority { Low, Normal, High, Urgent }
   ```

4. **All errors must be logged with context**
   ```rust
   ❌ Err(e) => return Err(MyError::Failed)
   ✅ Err(e) => {
          error!(operation = "do_something", error = %e, "Failed");
          return Err(MyError::Failed);
      }
   ```

### Validation

Before committing, run:
```bash
make check  # Runs format, clippy, and custom quality checks
```

Or manually:
```bash
cd src-tauri
cargo fmt -- --check
cargo clippy -- -D warnings
python3 ../scripts/validate_code_quality.py
```

### Reference

Full standards: `docs/CODING_STANDARDS.md`

---

## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- After modifying code files in this session, run `python3 -c "from graphify.watch import _rebuild_code; from pathlib import Path; _rebuild_code(Path('.'))"` to keep the graph current
