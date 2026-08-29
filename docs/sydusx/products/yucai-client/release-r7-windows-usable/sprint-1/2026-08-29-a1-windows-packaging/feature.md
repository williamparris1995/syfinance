# Feature — A1 Windows 打包/安装通路(R7 sprint-1 feature A)

> ticket 11(deployment-pathway)的 client 面;R7 首个 feature。发布形态(安装器选型)analysis/design grill 定。

## Description

从源码到可安装 Windows 产物的一条命令通路:`flutter build windows` 产物整理 + 安装器(候选:MSIX / Inno Setup / 纯 zip 便携版,grill 定)+ 版本戳(pubspec 版本进产物)+ 全新安装后本地模式三判据复验(断网启动→记账可用;不绑定→永远本地)。产物可分发(非开发机可装)。

## Stories

1. 打包脚本/Makefile 目标:release 产物一键生成(含依赖清理)
2. 安装器选型与制作(grill:MSIX vs Inno vs zip)
3. 版本戳:pubspec → 产物(关于页/文件属性可见)
4. 全新安装验收:三判据清单在打包版执行并记录

## title

A1 Windows 打包/安装通路(分发基础)

## keywords

windows, packaging, installer, msix, inno, distribution, release, 11, A1
