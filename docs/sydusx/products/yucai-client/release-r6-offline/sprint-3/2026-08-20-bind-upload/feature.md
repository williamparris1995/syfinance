# Feature — 绑定上传(空账号 guard + RestoreBackup 单向上传 + 回切在线)

> R6 sprint-3 feature G(依赖 sprint-2 全模块本地数据)。
> 复用 R5 刚加固的 restore 路径:D5 快照一致 + D6 purge+import 原子(server 侧已完成,本 feature **零 server 改动**)。

## Description

游客绑定账号的完整链路:①OIDC 登录(现有流程);②**空账号预检 guard(M3,必做)**——登录后先拉取账号数据摘要,非空 → 阻止上传并提示(该账号已有数据,合并流程 defer;用户可选换账号或放弃绑定);③空账号 → 本地 drift 全量导出为 backup 格式(G1 契约)→ 经现有 `RestoreBackup` RPC 单向上传;④上传成功 → 回切 server 权威在线模式(现有架构不变),本地库转镜像角色(写穿透在 feature H)。

防 clobber 是安全底线:guard 失效路径(如预检后账号被并发写入)在 design 阶段评估——单用户产品风险低,record 为 accepted risk 或加二次确认。

## Stories

1. 空账号预检 guard:登录后拉账号摘要,非空阻止上传(M3)+ 用户提示与选项
2. 本地 drift → backup 格式导出(按 G1 契约映射表,含全部业务实体)
3. 经 RestoreBackup 上传 + 服务端数据验证(拉回比对条目数/关键字段)
4. 绑定状态机:guest → binding(进度/失败可重试)→ bound(回切在线模式)
5. 上传失败恢复:可重试/可放弃,本地数据不受影响(单向性保证)
6. 测试:空账号上传成功 / 非空账号被 guard 阻止 / 上传中断重试

## title

绑定上传:空账号 guard + drift→backup 导出 + RestoreBackup 单向上传 + 回切在线

## keywords

bind, upload, restore backup, empty account guard, clobber, one-way, R6, M3

