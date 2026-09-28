---
title: F46 llm-analyst
keywords: [LLM, AI 分析师, BYOK, 脱敏, 叙述, 解读, 智谱, OpenAI 兼容, llm-analyst]
---

# Feature — F46 LLM 分析师(R16 sprint-2)

> 2026-09-28 立项。方案承接 F44 立项时用户构想评估决议(BYOK/脱敏/免责/城市档位,F44 spec Scope boundary 存档);消费 F44 narrative port。

## Description

现状:报告诊断全为本地规则(F44),narrative port 仅 Noop。目标:BYOK LLM 分析师——①设置页「AI 分析师」配置卡(OpenAI 兼容端点[智谱/OpenAI/DeepSeek/自定义]/API Key[flutter_secure_storage]/模型名/城市规模档位/订阅名明文开关);②报告页「AI 解读」入口(已配置才可见)→ 数据外发确认(脱敏包预览+免责声明)→ 调用 → 「分析师解读」旁挂呈现(**不入 ReportDocument 快照**,保 FR-2 三态一致);③脱敏聚合包(科目类别+金额区间级,无账户名/交易备注/身份;订阅名随开关);④数字全部来自本地快照+规则结论,LLM 仅叙述;⑤HTTP 走 dart:io HttpClient 零新依赖,注入缝可测;⑥失败降级(未配置引导/网络失败重试/超时)。

## Stories(粗,analysis 细化)

- [x] S1: 设置卡+配置存取(Key 走 secure storage)
- [x] S2: 脱敏包构造+prompt 管线
- [x] S3: LLM client(注入缝)+响应解析
- [x] S4: 报告页入口+确认流+解读章节呈现
- [x] S5: 测试与门

## Keywords

`LLM` `AI 分析师` `BYOK` `脱敏` `叙述` `解读` `智谱` `OpenAI 兼容` `llm-analyst`
