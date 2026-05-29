# 统一验证命令设计

**日期：** 2026-05-29
**状态：** 已批准

## 目标

将分散在 `pnpm`、`make`、`npx` 的 5 个代码质量检查工具封装为单一 `pnpm validate` 命令，用于 `executing-plans` 完成后的自动验证。

## 命令

```
pnpm validate
```

## 执行步骤

快速失败模式：任何步骤失败立即停止，返回非零退出码。

| # | 命令 | 检查内容 |
|---|------|----------|
| 1 | `pnpm type-check` | TypeScript 类型检查（`tsc --noEmit`） |
| 2 | `pnpm lint` | ESLint + `i18next/no-literal-string`（禁止 JSX 裸字符串） |
| 3 | `cd src-tauri && cargo fmt -- --check` | Rust 代码格式检查 |
| 4 | `cd src-tauri && cargo clippy --all-targets --all-features -- -D warnings` | Rust lint（含 clippy.toml 自定义规则） |
| 5 | `cd .. && python3 scripts/validate_code_quality.py` | Python 质量检查（3 个验证器） |

### 步骤 5 子检查明细

| 验证器 | 检查项 |
|--------|--------|
| RustValidator | 禁止硬编码 SQL（强制 ORM）、禁止 match 硬编码字符串（强制 serde）、禁止 println!（强制 tracing）、禁止 `log::` 宏 |
| LogValidator | 禁止 Rust tracing 日志中的中文、禁止 TS `console.*` 中的中文 |
| ConstValidator | 禁止 TSX JSX 中的裸字符串字面量（强制 i18n `t()` 包裹） |

## 改动

仅修改 `package.json`，在 `scripts` 中添加一行：

```json
"validate": "pnpm type-check && pnpm lint && cd src-tauri && cargo fmt -- --check && cargo clippy --all-targets --all-features -- -D warnings && cd .. && python3 scripts/validate_code_quality.py"
```

## 不改动

- Makefile 保持不变（`make check` 仍只跑 Rust 侧）
- 不添加新文件或新依赖
