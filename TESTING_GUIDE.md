# Finance App - 运行和测试指南

## 🚀 快速开始

### 1. 安装依赖

```bash
# 安装前端依赖
pnpm install
```

### 2. 启动开发服务器

```bash
# 启动Tauri开发环境（包含前端和后端）
pnpm tauri dev
```

**首次启动**：
- 编译时间：约2-3分钟（Rust首次编译较慢）
- 应用窗口会自动打开
- 数据库会自动初始化（SQLite）

---

## 🧪 运行测试

### 后端测试（Rust）

```bash
# 进入后端目录
cd src-tauri

# 运行所有测试
cargo test

# 运行特定模块测试
cargo test account          # 账户相关测试
cargo test transaction      # 交易相关测试
cargo test debt            # 债务相关测试
cargo test currency        # 货币相关测试

# 显示测试输出
cargo test -- --nocapture

# 返回项目根目录
cd ..
```

**预期结果**：116个测试通过 ✅

### 前端测试（TypeScript）

```bash
# 运行所有前端测试
pnpm vitest run

# 运行特定测试文件
pnpm vitest run src/__tests__/currency.test.ts
pnpm vitest run src/__tests__/error-handling.test.tsx

# 监听模式（自动重新运行）
pnpm vitest

# 查看测试覆盖率
pnpm vitest run --coverage
```

**预期结果**：36个测试通过 ✅

### 类型检查

```bash
# TypeScript类型检查
pnpm type-check
```

### 代码质量检查

```bash
# Rust代码检查
cd src-tauri
cargo clippy

# 自动修复部分问题
cargo clippy --fix
```

---

## 📱 功能测试指南

### 测试场景1：账户管理

1. **启动应用**：`pnpm tauri dev`

2. **首次启动**：
   - 应该看到欢迎/注册页面
   - 点击"Get Started"获取账户ID
   - **重要**：保存显示的账户ID（用于多设备同步）

3. **创建账户**：
   - 导航到"Accounts"页面
   - 点击"Create Account"按钮
   - 填写表单：
     - Name: "我的银行账户"
     - Type: Asset
     - Chart of Account: 1002-银行存款
     - Currency: CNY
     - Initial Balance: 10000
   - 点击"Save"
   - ✅ 验证：账户出现在列表中

4. **删除账户**：
   - 点击账户的删除按钮
   - ✅ 验证：出现确认对话框
   - 点击"Cancel"
   - ✅ 验证：账户仍然存在
   - 再次点击删除，点击"Confirm"
   - ✅ 验证：账户被删除，显示成功Toast

### 测试场景2：交易记录

1. **前提**：至少创建2个账户（例如：银行账户和现金账户）

2. **记录交易**：
   - 导航到"Transactions"页面
   - 点击"Record Transaction"
   - 填写表单：
     - Date: 今天日期
     - Description: "取现"
     - Entry 1:
       - Account: 现金
       - Debit: 1000
     - Entry 2:
       - Account: 银行账户
       - Credit: 1000
   - ✅ 验证：余额指示器显示"Balanced ✓"
   - 点击"Save"
   - ✅ 验证：交易出现在列表中

3. **测试不平衡交易**：
   - 创建新交易
   - Entry 1: Debit 1000
   - Entry 2: Credit 500
   - ✅ 验证：余额指示器显示"Unbalanced: -500 CNY"
   - 点击"Save"
   - ✅ 验证：显示错误提示，交易未创建

4. **验证账户余额**：
   - 返回"Accounts"页面
   - ✅ 验证：银行账户余额 = 10000 - 1000 = 9000
   - ✅ 验证：现金账户余额 = 0 + 1000 = 1000

### 测试场景3：债务管理

1. **创建贷款**：
   - 导航到"Debts"页面
   - 点击"Create Debt"
   - 填写表单：
     - Type: Loan
     - Counterparty: "银行贷款"
     - Principal: 100000 CNY
     - Interest Rate: 5% (年利率)
     - Start Date: 今天
     - Due Date: 1年后
     - Payment Method: 等额本息
     - Remind Days Before: 3
   - ✅ 验证：显示还款计划预览（12期）
   - ✅ 验证：每期还款约8,560.75 CNY
   - 点击"Save"

2. **查看还款计划**：
   - 点击刚创建的债务
   - ✅ 验证：显示完整的12期还款计划
   - ✅ 验证：每期包含本金、利息、总额

3. **记录还款**：
   - 点击第一期的"Record Payment"按钮
   - 确认还款
   - ✅ 验证：该期标记为"已支付"
   - ✅ 验证：剩余余额减少

### 测试场景4：财务报表

1. **资产负债表**：
   - 导航到"Reports"页面
   - 选择"Balance Sheet"标签
   - ✅ 验证：显示所有资产账户
   - ✅ 验证：显示所有负债账户
   - ✅ 验证：总资产 - 总负债 = 权益

2. **收支表**：
   - 选择"Income Statement"标签
   - 选择日期范围："This Month"
   - ✅ 验证：显示本月收入和支出
   - ✅ 验证：净收入 = 收入 - 支出
   - ✅ 验证：图表正确显示收支对比

3. **导出CSV**：
   - 点击"Export CSV"按钮
   - ✅ 验证：下载CSV文件
   - 打开文件验证数据正确

### 测试场景5：货币管理

1. **添加货币**：
   - 导航到"Settings"页面
   - 在Currency Settings部分点击"Add Currency"
   - 填写：
     - Code: USD
     - Symbol: $
     - Exchange Rate: 7.25 (1 USD = 7.25 CNY)
   - 点击"Save"
   - ✅ 验证：USD出现在货币列表

2. **更新汇率**：
   - 点击USD的编辑按钮
   - 修改汇率为7.30
   - 保存
   - ✅ 验证：汇率更新成功

3. **创建外币账户**：
   - 返回Accounts页面
   - 创建新账户，Currency选择USD
   - ✅ 验证：账户创建成功，显示USD符号

### 测试场景6：同步功能

1. **查看同步状态**：
   - 查看Header右上角的同步状态
   - ✅ 验证：显示"Last synced: X minutes ago"

2. **手动同步**：
   - 点击"Sync Now"按钮
   - ✅ 验证：显示同步进度
   - ✅ 验证：同步完成后显示成功提示

3. **测试离线模式**：
   - 断开网络连接
   - ✅ 验证：Header显示离线指示器（橙色徽章）
   - 尝试同步
   - ✅ 验证：显示网络错误提示
   - 重新连接网络
   - ✅ 验证：离线指示器消失

4. **配置同步设置**：
   - 进入Settings页面
   - 在Sync Settings部分：
     - 切换"Enable automatic sync"
     - 修改同步间隔（5/15/30/60分钟）
   - ✅ 验证：设置保存成功

### 测试场景7：错误处理

1. **表单验证**：
   - 尝试创建空名称的账户
   - ✅ 验证：显示验证错误
   - ✅ 验证：表单不提交

2. **网络错误**：
   - 断开网络
   - 尝试同步
   - ✅ 验证：显示友好的错误消息（不是技术错误）

3. **确认对话框**：
   - 尝试删除有交易的账户
   - ✅ 验证：显示错误提示"Cannot delete account with transactions"

---

## 🔍 调试技巧

### 查看日志

**前端日志**：
- 打开浏览器开发者工具：F12
- 查看Console标签

**后端日志**：
- 在终端查看Rust输出
- 使用 `RUST_LOG=debug pnpm tauri dev` 启用详细日志

### 数据库检查

**SQLite数据库位置**：
- Windows: `%APPDATA%\com.finance.app\`
- macOS: `~/Library/Application Support/com.finance.app/`
- Linux: `~/.local/share/com.finance.app/`

**查看数据库**：
```bash
# 使用sqlite3命令行工具
sqlite3 path/to/database.db

# 查看所有表
.tables

# 查看账户
SELECT * FROM accounts;

# 查看交易
SELECT * FROM transactions;
```

### 重置数据库

如果需要从头开始：
```bash
# 删除数据库文件
# Windows
Remove-Item "$env:APPDATA\com.finance.app\*.db"

# 重新启动应用
pnpm tauri dev
```

---

## 🏗️ 生产构建

### 构建应用

```bash
# 构建生产版本
pnpm tauri build
```

**构建时间**：首次约10-15分钟

**输出位置**：
- **可执行文件**: `src-tauri/target/release/finance-app.exe`
- **安装包**: `src-tauri/target/release/bundle/msi/Finance App_0.1.0_x64_en-US.msi`

### 测试生产构建

```bash
# 直接运行可执行文件
.\src-tauri\target\release\finance-app.exe

# 或安装MSI包后测试
```

---

## ⚠️ 常见问题

### 问题1：编译错误

**症状**：`cargo build` 失败

**解决**：
```bash
# 清理并重新构建
cd src-tauri
cargo clean
cargo build
```

### 问题2：前端构建失败

**症状**：`pnpm build` 失败

**解决**：
```bash
# 删除node_modules重新安装
Remove-Item -Recurse -Force node_modules
pnpm install
```

### 问题3：端口被占用

**症状**：`Port 5173 is already in use`

**解决**：
```bash
# 查找并关闭占用端口的进程
Get-Process -Id (Get-NetTCPConnection -LocalPort 5173).OwningProcess | Stop-Process
```

### 问题4：数据库迁移失败

**症状**：应用启动时数据库错误

**解决**：
```bash
# 手动运行迁移
cd src-tauri
sqlx migrate run --database-url sqlite:test.db
```

---

## 📊 性能基准

**启动时间**：
- 首次启动：~3秒（包含数据库初始化）
- 后续启动：~1秒

**内存占用**：
- 空闲：~150MB
- 活跃使用：~200MB

**数据库性能**：
- 创建账户：<10ms
- 记录交易：<20ms
- 生成报表：<100ms（1000笔交易）

---

## ✅ 验收清单

测试完成后，确认以下功能：

- [ ] 应用成功启动
- [ ] 账户创建、编辑、删除
- [ ] 交易记录（复式记账验证）
- [ ] 债务创建和还款计划
- [ ] 财务报表生成
- [ ] 货币管理
- [ ] 同步功能（手动和自动）
- [ ] 错误处理和用户反馈
- [ ] 确认对话框
- [ ] 离线指示器
- [ ] 数据持久化（重启后数据仍在）

---

## 🎯 下一步

测试完成后：

1. **反馈问题**：记录发现的任何bug或改进建议
2. **性能测试**：创建大量数据测试性能
3. **多设备测试**：测试同步功能
4. **生产部署**：构建并部署到生产环境

---

**需要帮助？** 查看 `PROJECT_SUMMARY.md` 了解更多信息。
