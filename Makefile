# Makefile for code quality checks
# 用于验证代码是否符合CODING_STANDARDS.md规范

.PHONY: help check check-format check-clippy check-quality check-all test build clean

# 默认目标
help:
	@echo "代码质量检查工具"
	@echo ""
	@echo "可用命令:"
	@echo "  make check         - 运行所有检查（推荐）"
	@echo "  make check-format  - 检查代码格式"
	@echo "  make check-clippy  - 运行Clippy检查"
	@echo "  make check-quality - 运行自定义质量检查"
	@echo "  make test          - 运行测试"
	@echo "  make build         - 构建项目"
	@echo "  make fix           - 自动修复可修复的问题"
	@echo ""

# 运行所有检查
check: check-format check-clippy check-quality
	@echo ""
	@echo "✅ 所有检查完成！"

# 检查代码格式
check-format:
	@echo "🔍 检查代码格式..."
	@cd src-tauri && cargo fmt -- --check
	@echo "✅ 格式检查通过"

# 运行Clippy检查
check-clippy:
	@echo "🔍 运行Clippy检查..."
	@cd src-tauri && cargo clippy --all-targets --all-features -- -D warnings
	@echo "✅ Clippy检查通过"

# 运行自定义质量检查
check-quality:
	@echo "🔍 运行自定义代码质量检查..."
	@python3 scripts/validate_code_quality.py
	@echo "✅ 质量检查通过"

# 运行测试
test:
	@echo "🧪 运行测试..."
	@cd src-tauri && cargo test
	@echo "✅ 测试通过"

# 构建项目
build:
	@echo "🔨 构建项目..."
	@cd src-tauri && cargo build
	@echo "✅ 构建成功"

# 自动修复可修复的问题
fix:
	@echo "🔧 自动修复代码..."
	@cd src-tauri && cargo fmt
	@cd src-tauri && cargo clippy --fix --allow-dirty --allow-staged
	@echo "✅ 自动修复完成"

# 清理构建产物
clean:
	@echo "🧹 清理构建产物..."
	@cd src-tauri && cargo clean
	@echo "✅ 清理完成"

# CI/CD使用的完整检查
ci: check test build
	@echo ""
	@echo "✅ CI检查全部通过！"
