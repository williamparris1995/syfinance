# Feature — 存档导出/导入(加密存档文件,多设备迁移/云盘备份)

> R6 sprint-3 feature J(依赖 G 的 drift→backup 导出器;2026-08-22 立项,源:用户决策——离线为主,存档文件自由流转)。
> 形态采用手动 file picker 而非绑定云盘文件夹(YAGNI):用户自行决定存档存哪(U 盘/云盘同步文件夹/任意位置),覆盖「多设备导入」与「云盘备份」两场景,零云盘 API 集成。

## Description

本地库全量导出为**用户密码加密**的存档文件(backup 格式,复用 G 导出器 + 服务端 D13 同族 KDF/scrypt 加密语义——云盘/传输通道不可信);任意设备上经 file picker 选择存档 → 解密 → **全量替换**导入本地库(restore 语义,同服务端 purge+import,不做合并——多设备合并归 ticket 16)。设置页入口:导出存档 / 导入存档。

## Stories

1. 导出:drift 全量 → backup 格式 → 用户密码加密 → file picker 保存
2. 导入:file picker 选择 → 密码解密校验(checksum/KDF 版本) → 全量替换本地库(事务)
3. 错误路径:密码错/文件损坏/版本不识别 → 明确报错,本地库不动
4. 设置页两入口(Guest/绑定态均可用——绑定态导入需警示将覆盖本地镜像)
5. 测试:导出→导入回环一致;错误路径;加密格式版本化

## title

存档导出/导入:加密 backup 文件 file picker 手动流转(多设备迁移/云盘备份)

## keywords

archive, export, import, encrypted backup, file picker, migration, cloud drive, R6
