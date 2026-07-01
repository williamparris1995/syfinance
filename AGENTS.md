# AGENTS.md

御财(YuCai)个人理财 — Go 后端(DDD + gRPC + ent)+ Flutter 客户端(flutter_bloc)。代码在 `yucai/server/` + `yucai/client/`。

**完整项目指南见 [CLAUDE.md](CLAUDE.md)**(架构 / 命令 / 约束 / 工作流)。

## 快速命令
- server:`cd yucai/server && go test ./... && go build ./...`
- client:`cd yucai/client && flutter test && flutter analyze`
- proto regen:`cd yucai && make gen-dart`(protoc_plugin 25.0.0)

## 关键约束(详 CLAUDE.md)
- English 结构化日志(无 CJK 在 log 串)
- `wire_gen.go` 手改(工具链坏,不跑 wire CLI)
- 跨模块 port 模式(消费方不 import 生产方)
- DDD 四层边界 + 复用第一(照 holding/debt 范式)
