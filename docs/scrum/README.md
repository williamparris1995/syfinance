# Scrum 管理指南

**项目**: 财务管理系统 - 生产就绪改进  
**最后更新**: 2026-05-15

---

## 目录

1. [Scrum 概述](#scrum-概述)
2. [角色和职责](#角色和职责)
3. [Scrum 仪式](#scrum-仪式)
4. [工件管理](#工件管理)
5. [工具和模板](#工具和模板)
6. [最佳实践](#最佳实践)

---

## Scrum 概述

### 什么是 Scrum？

Scrum 是一个敏捷开发框架，通过迭代和增量的方式交付产品。本项目采用 Scrum 管理两个 Sprint 的开发工作。

### 为什么使用 Scrum？

- **透明性**: 所有工作可见，进度清晰
- **检查**: 定期检查进度和质量
- **适应**: 快速响应变化和问题
- **时间盒**: 固定时间周期，避免无限延期

---

## 角色和职责

### Product Owner
**职责**:
- 维护 Product Backlog
- 定义验收标准
- 优先级排序
- 参与 Sprint Review

**本项目**: [待指定]

### Scrum Master
**职责**:
- 促进 Scrum 仪式
- 移除阻碍
- 保护团队不受干扰
- 推动持续改进

**本项目**: [待指定]

### Development Team
**职责**:
- 估算任务
- 完成 Sprint Backlog
- 每日同步进度
- 自组织工作

**本项目**: [团队成员列表]

---

## Scrum 仪式

### 1. Sprint Planning（Sprint 计划会）

**时间**: Sprint 开始时  
**时长**: 2-4小时  
**参与者**: 全体团队

**议程**:
1. 回顾 Sprint 目标
2. 从 Product Backlog 选择 User Stories
3. 分解任务到 Sprint Backlog
4. 估算工作量
5. 确认团队承诺

**输出**: Sprint Backlog

**文档**: `docs/scrum/sprint-N-backlog.md`

---

### 2. Daily Scrum（每日站会）

**时间**: 每天固定时间  
**时长**: 15分钟  
**参与者**: Development Team

**三个问题**:
1. 昨天完成了什么？
2. 今天计划做什么？
3. 有什么阻碍？

**规则**:
- 准时开始，准时结束
- 站着开会（保持简短）
- 只同步状态，不讨论细节
- 详细讨论会后进行

**文档**: `docs/scrum/daily-standup-YYYY-MM-DD.md`

---

### 3. Sprint Review（Sprint 评审会）

**时间**: Sprint 结束时  
**时长**: 1-2小时  
**参与者**: 全体团队 + 利益相关者

**议程**:
1. 演示完成的功能
2. 回顾 Sprint 目标达成情况
3. 收集反馈
4. 讨论 Product Backlog 调整

**输出**: 
- 演示记录
- 反馈列表
- Product Backlog 更新

**文档**: `docs/scrum/sprint-N-review.md`

---

### 4. Sprint Retrospective（Sprint 回顾会）

**时间**: Sprint Review 之后  
**时长**: 1小时  
**参与者**: Development Team + Scrum Master

**议程**:
1. 什么做得好？（Keep）
2. 什么需要改进？（Stop）
3. 我们可以尝试什么？（Start）
4. 制定行动项

**输出**: 行动项列表

**文档**: `docs/scrum/retrospective-sprint-N.md`

---

## 工件管理

### Product Backlog

**位置**: `docs/scrum/product-backlog.md`

**内容**:
- User Stories
- 验收标准
- Story Points
- 优先级

**维护**:
- Product Owner 负责
- 每个 Sprint 后更新
- 持续优先级排序

---

### Sprint Backlog

**位置**: `docs/scrum/sprint-N-backlog.md`

**内容**:
- Sprint 目标
- 选入的 User Stories
- 任务分解
- 任务状态

**维护**:
- Development Team 负责
- 每日更新状态
- Sprint 结束后归档

---

### Increment（增量）

**定义**: 每个 Sprint 结束时可交付的产品增量

**本项目**:
- Sprint 1: 安全的本地版本
- Sprint 2: 完整的生产版本

**验证**: Definition of Done

---

## 工具和模板

### 文档模板

| 模板 | 位置 | 用途 |
|------|------|------|
| Product Backlog | `docs/scrum/product-backlog.md` | 管理所有需求 |
| Sprint Backlog | `docs/scrum/sprint-N-backlog.md` | 管理 Sprint 任务 |
| Daily Standup | `docs/scrum/daily-standup-template.md` | 记录每日站会 |
| Retrospective | `docs/scrum/retrospective-template.md` | 记录回顾会 |

### 任务板（Scrum Board）

**状态列**:
- Todo: 待开始
- In Progress: 进行中
- Done: 已完成

**更新频率**: 每日

**工具**: 
- 物理白板（推荐）
- 或使用 Markdown 文件

---

## 最佳实践

### 1. 估算技巧

**Story Points 参考**:
- 1 SP = 1-2小时（简单任务）
- 3 SP = 半天（中等任务）
- 5 SP = 1天（复杂任务）
- 8 SP = 2天（很复杂）
- 13 SP = 3-5天（需要拆分）

**估算方法**: Planning Poker

---

### 2. 任务分解

**原则**:
- 每个任务 < 8小时
- 任务可独立完成
- 任务有明确的完成标准

**示例**:
```
❌ 坏: "实现同步功能"（太大）
✅ 好: "实现 JWT 服务"（具体、可测量）
```

---

### 3. Definition of Done

**层级**:
1. **任务级**: 代码完成、测试通过
2. **Story 级**: 验收标准满足、文档更新
3. **Sprint 级**: 所有 Story 完成、可演示

**检查清单**: 见各 Sprint Backlog

---

### 4. 处理阻碍

**流程**:
1. 在 Daily Scrum 中提出
2. Scrum Master 记录
3. 会后立即处理
4. 下次站会更新状态

**升级机制**:
- 24小时内无法解决 → 升级到 Product Owner
- 影响 Sprint 目标 → 立即升级

---

### 5. 速度跟踪

**Velocity（速度）**: 每个 Sprint 完成的 Story Points

**计算**:
```
Velocity = 完成的 Story Points / Sprint 数量
```

**用途**:
- 预测未来 Sprint 容量
- 评估团队效率
- 调整计划

**本项目目标**:
- Sprint 1: 16 SP
- Sprint 2: 21 SP

---

## 常见问题

### Q: Sprint 中可以添加新任务吗？
A: 可以，但需要：
- 不影响 Sprint 目标
- 团队有剩余容量
- Product Owner 同意

### Q: 如果 Sprint 目标无法完成怎么办？
A: 
1. 在 Daily Scrum 中尽早识别
2. 与 Product Owner 讨论优先级
3. 必要时调整范围（移除低优先级任务）
4. 在 Retrospective 中分析原因

### Q: 如何处理紧急 Bug？
A: 
- P0 Bug: 立即处理，可能影响 Sprint
- P1 Bug: 加入当前 Sprint
- P2 Bug: 加入 Product Backlog

---

## 参考资源

- [Scrum Guide](https://scrumguides.org/)
- [Agile Manifesto](https://agilemanifesto.org/)
- 项目设计文档: `docs/superpowers/specs/2026-05-15-production-readiness-design.md`

---

## 变更日志

- 2026-05-15: 初始版本创建
