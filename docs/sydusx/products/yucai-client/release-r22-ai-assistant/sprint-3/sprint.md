# Sprint 3 — P3 语音(语音管线+对话体验)

> /sydusx-portfolio 2026-10-24 立项(sprint-1 收官后;原「sprint-2 收官后立项」触发词随 sprint-2 撤销订正)。调研依据=项目记忆 ondevice-llm-voice-research(sherpa-onnx 中文栈/push-to-talk/延迟预算)。

## Sprint Goal

说→答端到端语音对话:push-to-talk 输入→流式 ASR→agent loop→按句流式 TTS 播报+打断;体感流畅(本地栈大头=LLM 首 token,已由 sprint-1 引擎就位)。

## Features

- [ ] **F68 语音管线** — sherpa_onnx 依赖接入+DLL/体积 spike 收口;流式 ASR(Paraformer zh-en)+Silero VAD+Kokoro v1.1-zh TTS+语音模型管理(首跑下载 ~550-600MB 三件套,照 F67 范式)+mic 采集包选型落地。 claimed: session_aeae29d380294919dea3162276116bd7 2026-10-24
- [ ] **F69 对话体验** — push-to-talk 交互+实时字幕(partial)+按句流式 TTS 播报队列+barge-in 打断(清队列+取消 LLM);语音 UX 原型 OD 对比页+用户确认门(照 F65 先例)。(依赖 F68 管线)

## status: pending
