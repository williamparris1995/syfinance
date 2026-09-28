# Code Plan — F46 LLM 分析师

> execute 2026-09-28。依据 spec(FR-1..5/NFR-1..3)+design(ADR-1..6)+prototype v9。零新依赖;零 proto/server。

## 任务分解

- [x] **T1 纯核+接线底座**:`lib/core/llm/llm_settings.dart`(ThemeSettings 家法,keys llm.*,bootstrap load)+`lib/report/data/llm/`(llm_payload 纯函数[负面清单断言]/llm_prompt[系统提示逐字]/llm_mda_narrator[implements MdaNarrator,HttpFn 缝,二态降级:未 ready→'',失败→NarrationFailure])+llm_http(生产 dart:io,唯平台文件,30s 超时)+DI regen(MdaNarrator 主绑定替换,F44 narrator 测试同步);单测全缝化。
- [x] **T2 UI 接线**(prototype v9):设置页「AI 分析师」卡(六行+未启用禁用态)+首启用免责对话框(取消回弹,ack 持久化);报告页「AI 解读」按钮(ready 才可见)+`AnalystNote` 旁挂小节(三态+重新解读+期变更清空);widget 测试(两页+对话框回弹+旁挂清空)。
- [x] **T3 门与收尾**:e2e 设置卡可达断言;全门五项证据(全量/analyze stash 对比/e2e/proto 零 diff/build_runner 幂等)。

## 依赖

T1→T2→T3 串行;每 task 两轴评审+修复回路。

## 验收映射

FR-1→T2;FR-2/FR-3→T1;FR-4→T2;FR-5→T1(错误消息面)+T2;NFR-1→T1;NFR-2→T2;NFR-3→T3。
