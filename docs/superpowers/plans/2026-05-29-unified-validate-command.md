# 统一验证命令实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 package.json 中添加 `pnpm validate` 脚本，串联 5 个代码质量检查步骤

**Architecture:** 单行 npm script，用 `&&` 串联 5 个已有检查命令，快速失败模式

**Tech Stack:** pnpm, TypeScript, Rust (cargo fmt/clippy), Python3

---

### Task 1: 添加 validate 脚本到 package.json

**Files:**
- Modify: `package.json`

- [ ] **Step 1: 在 scripts 中添加 validate 命令**

在 `package.json` 的 `scripts` 对象中，在 `"tauri"` 行之前添加：

```json
"validate": "pnpm type-check && pnpm lint && cd src-tauri && cargo fmt -- --check && cargo clippy --all-targets --all-features -- -D warnings && cd .. && python3 scripts/validate_code_quality.py",
```

修改后的 scripts 完整内容：

```json
"scripts": {
  "dev": "vite",
  "build": "vite build",
  "type-check": "tsc --noEmit",
  "lint": "eslint src --ext .ts,.tsx",
  "lint:fix": "eslint src --ext .ts,.tsx --fix",
  "validate": "pnpm type-check && pnpm lint && cd src-tauri && cargo fmt -- --check && cargo clippy --all-targets --all-features -- -D warnings && cd .. && python3 scripts/validate_code_quality.py",
  "tauri": "tauri"
},
```

- [ ] **Step 2: 验证命令可执行**

Run: `pnpm validate`
Expected: 5 个检查步骤依次执行。由于预存的 clippy 警告（`-D warnings` 视为错误），命令会在步骤 4 失败。这是预期行为——验证了串联逻辑正确。

- [ ] **Step 3: 提交**

```bash
git add package.json
git commit -m "feat: add pnpm validate script for unified code quality checks"
```
