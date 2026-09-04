# Feature — F10 离线写语义与缓冲(R9 sprint-1)

> 2026-09-03 用户拍板"只做离线续写"起步;R9 立项分解确认。

## Description

查实绑定态(bound mode)写路径现状(R6 M2:本地 drift 镜像写穿透——断网时写的实际行为要代码级查证),落地:绑定态断网时记账继续走 R6 真实本地 DS 管道(guest 同管道),未同步写集合可跟踪(哪些本地写尚未上行),回网时触发补同步(补同步 RPC 形态留给 F11,本 feature 定义触发与数据准备)。约束:离线写零功能降级(与 guest 模式同能力);回归门不回归。

## Stories

- [ ] S1: 绑定态写路径与断网行为查证(design 阶段代码级事实,写路径图)
- [ ] S2: 离线续写落地(断网时写走本地管道,零降级)
- [ ] S3: 未同步写集合跟踪(待上行写的标识/游标)
- [ ] S4: 回网触发与数据准备(连接恢复→准备待同步批次→交 F11 通路)

## title

F10 离线写语义与缓冲(绑定态断网续写)

## keywords

offline-write, bound-mode, write-buffer, pending-sync, reconnect-trigger, F10
