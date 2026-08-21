# Code Plan — feature A drift 本地库落地

> 消费 spec.md(confirmed)+ design.md(confirmed)。inline 模式(新子系统自包含,唯一外部接线一处 DI 注册)。执行器:主 session(worktree cwd)。

## Tasks

- [x] **T1 表定义 + 库骨架**:10 个 tables 文件(契约表列=design LLD 清单,自有表=server 语义)+ `app_database.dart`(migration 骨架 v1)+ build.yaml 加 `store_date_time_values_as_text: true` + pubspec 补 `path_provider`(文件库路径,drift lazyDatabase 惰性解析)。验证:build_runner 生成成功 + analyze 干净。
- [x] **T2 DAO**:8 模块 DAO + ReferenceDao + DerivedDao(签名=design DAO 契约:insert/getById/watchAll/update/deleteById + 模块关系查询)。验证:重新生成 + analyze。
- [x] **T3 DI**:injection.dart 手动 `registerLazySingleton<AppDatabase>`(对齐 core infra 惯例,ADR-5)。
- [x] **T4 内存库单测**:test/core/localdb/ 三件——契约模块 CRUD / 级联删除(transaction→entries、debt→schedule、budget→items、goal→links、tag 联结)/ 引用+派生冒烟。RED→GREEN 逐步跑。
- [x] **T5 收口**:flutter test 全套(基线 ≤3 fail/2 文件)+ flutter analyze 不新增 + go build 不涉(server 零改动自证)→ commit。

## 约定声明

- 契约表不加列默认值(契约保真,design ADR-3);测试 helper 显式给值。
- 注释英文(仓库惯例),仅记约束性信息。
- 生成物 *.g.dart 入库(drift 标准流程,R3)。
