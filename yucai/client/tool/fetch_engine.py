#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""F66 引擎边车 —— llama-server.exe 获取脚本(T4;ADR-6/ADR-9)。

从 llama.cpp 官方 GitHub release 下载 **Windows Vulkan x64** 构建并解压到
`tool/engines/`(git 忽略 —— 真 exe 不入 git,测试资产只有 test/fixtures/
下的 tiny gguf)。集成为真件冒烟(test/assistant/integration/
engine_smoke_test.dart)与本机调试共用。

【版本钉死】(design.md Open Question 回填项;升级=改这两常量+重算 sha256):
  - release tag: b11669(= stable 标签 v0.7.0 的 nightly-tag.txt 所指构建,
    版本串 0.7.0-dev build 11669 commit 620d2225c,2026-10-23 选定)
  - zip sha256: 2c07574e7bde71321cb785282b20cc821e951132149eeceeea32ddebdbf0598e

【为何整 zip 解压而非单文件】该构建是"薄 exe + impl/后端 DLL"布局:
llama-server.exe 仅 9KB,真身在 llama-server-impl.dll,且运行时按 CPU 动态
挑选 ggml-cpu-<arch>.dll + ggml-vulkan.dll —— 单拷 exe 起不来,整包解压
(~91MB 本地缓存)是官方发布口径的唯一稳妥形态。exe 落位
`tool/engines/llama-server.exe`,与 EngineManagerImpl.exePath 缝约定一致。

flag 校准(b11669 --help 实测,2026-10-23):ADR-6 清单
`--host/--port/-m/-c/-ngl/--jinja/--no-webui` 全部在位零偏差;唯一备注:
`--no-webui` 已是 `--no-ui` 的弃用别名(仍有效,启动日志提示),暂不改
生产参数面 —— 换大版本时以 --help 复核。

用法(仓库根或 yucai/client 下均可):
  python tool/fetch_engine.py           # 幂等:已在位且版本匹配则跳过
  python tool/fetch_engine.py --force   # 强制重新下载解压

依赖:python3 标准库(urllib/zipfile/hashlib),零 pip 包。
"""
from __future__ import annotations

import argparse
import hashlib
import shutil
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

# -- 钉死常量(升级点) ---------------------------------------------------------

RELEASE_TAG = "b11669"
ZIP_NAME = f"llama-{RELEASE_TAG}-bin-win-vulkan-x64.zip"
ZIP_URL = (
    "https://github.com/ggml-org/llama.cpp/releases/download"
    f"/{RELEASE_TAG}/{ZIP_NAME}"
)
ZIP_SHA256 = "2c07574e7bde71321cb785282b20cc821e951132149eeceeea32ddebdbf0598e"

# -- 落位 ---------------------------------------------------------------------

# 本文件 = <client>/tool/fetch_engine.py -> 引擎目录 = 同级 engines/
ENGINES_DIR = Path(__file__).resolve().parent / "engines"
EXE_PATH = ENGINES_DIR / "llama-server.exe"

# 版本指纹(已有 exe 与钉死版本不符时视为陈旧,--force 之外的自动重下判据)
VERSION_STAMP = ENGINES_DIR / ".engine-version"


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _already_fetched() -> bool:
    return EXE_PATH.is_file() and VERSION_STAMP.read_text(encoding="ascii").strip() == RELEASE_TAG


def _download_to(url: str, dest: Path) -> None:
    print(f"downloading {url}")
    with urllib.request.urlopen(url, timeout=120) as resp, open(dest, "wb") as out:
        shutil.copyfileobj(resp, out, 1 << 20)
    print(f"OK downloaded {dest} ({dest.stat().st_size} bytes)")


def fetch(force: bool) -> int:
    if not force and _already_fetched():
        print(f"OK {EXE_PATH} already at pinned build {RELEASE_TAG}, nothing to do")
        return 0

    ENGINES_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="fetch-engine-") as tmp:
        zip_path = Path(tmp) / ZIP_NAME
        _download_to(ZIP_URL, zip_path)

        digest = _sha256_file(zip_path)
        print(f"sha256 {digest}")
        if digest != ZIP_SHA256:
            print(
                f"FATAL sha256 mismatch: want {ZIP_SHA256}, got {digest} "
                "(上游 release 资产被重推?改脚本常量前先人工核验)"
            )
            return 1

        with zipfile.ZipFile(zip_path) as zf:
            zf.extractall(ENGINES_DIR)
        print(f"OK extracted {len(zipfile.ZipFile(zip_path).namelist())} entries -> {ENGINES_DIR}")

    if not EXE_PATH.is_file():
        print(f"FATAL {EXE_PATH} missing after extract (上游布局变更?)")
        return 1
    VERSION_STAMP.write_text(f"{RELEASE_TAG}\n", encoding="ascii")
    print(f"OK {EXE_PATH} ready (build {RELEASE_TAG})")
    return 0


def main() -> None:
    parser = argparse.ArgumentParser(description="fetch pinned llama-server.exe (F66 engine sidecar)")
    parser.add_argument("--force", action="store_true", help="re-download even if already present")
    sys.exit(fetch(parser.parse_args().force))


if __name__ == "__main__":
    main()
