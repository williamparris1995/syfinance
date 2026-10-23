#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""F66  —— llama-server.exe (T4;ADR-6/ADR-9)

 llama.cpp  GitHub release  **Windows Vulkan x64** 
`tool/engines/`(git  ——  exe  git, test/fixtures/
 tiny gguf)(test/assistant/integration/
engine_smoke_test.dart)

【】(design.md Open Question ;=+ sha256):
  - release tag: b11669(= stable  v0.7.0  nightly-tag.txt ,
     0.7.0-dev build 11669 commit 620d2225c,2026-10-23 )
  - zip sha256: 2c07574e7bde71321cb785282b20cc821e951132149eeceeea32ddebdbf0598e

【 zip 】" exe + impl/ DLL":
llama-server.exe  9KB, llama-server-impl.dll, CPU 
 ggml-cpu-<arch>.dll + ggml-vulkan.dll ——  exe ,
(~91MB )exe 
`tool/engines/llama-server.exe`, EngineManagerImpl.exePath 

flag (b11669 --help ,2026-10-23):ADR-6 
`--host/--port/-m/-c/-ngl/--jinja/--no-webui` ;:
`--no-webui`  `--no-ui` (,),
 ——  --help 

( yucai/client ):
  python tool/fetch_engine.py           # :
  python tool/fetch_engine.py --force   # 

:python3 (urllib/zipfile/hashlib), pip 
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

# -- () ---------------------------------------------------------

RELEASE_TAG = "b11669"
ZIP_NAME = f"llama-{RELEASE_TAG}-bin-win-vulkan-x64.zip"
ZIP_URL = (
    "https://github.com/ggml-org/llama.cpp/releases/download"
    f"/{RELEASE_TAG}/{ZIP_NAME}"
)
ZIP_SHA256 = "2c07574e7bde71321cb785282b20cc821e951132149eeceeea32ddebdbf0598e"

# --  ---------------------------------------------------------------------

#  = <client>/tool/fetch_engine.py ->  =  engines/
ENGINES_DIR = Path(__file__).resolve().parent / "engines"
EXE_PATH = ENGINES_DIR / "llama-server.exe"

# ( exe ,--force )
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
                "( release ?)"
            )
            return 1

        with zipfile.ZipFile(zip_path) as zf:
            zf.extractall(ENGINES_DIR)
        print(f"OK extracted {len(zipfile.ZipFile(zip_path).namelist())} entries -> {ENGINES_DIR}")

    if not EXE_PATH.is_file():
        print(f"FATAL {EXE_PATH} missing after extract (?)")
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
