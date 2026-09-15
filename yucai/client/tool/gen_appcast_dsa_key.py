#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""御财 appcast 经典 DSA 密钥对一次性生成器(F24 FR-3;ADR-3,签名档位 DSA)。

作用:生成 Sparkle/WinSparkle【经典 DSA】(1024-bit DSA + SHA-1)签名密钥对,
编码与 Sparkle 官方 generate_keys 工具生态互通:
  - 公钥:PEM(SubjectPublicKeyInfo)→ 原样粘贴为
    yucai/client/windows/runner/dsa_pub.pem(auto_updater 构建时烤入 exe 的
    WinSparkle 公钥资源 DSAPub/DSAPEM,更新验签用)
  - 私钥:PEM(TraditionalOpenSSL DSA)→ 仅入 GitHub Actions Secrets
    (APPCAST_DSA_PRIVATE_KEY),配 tool/gen_appcast.py 对安装包签名

为何 DSA 而非 EdDSA:设计原裁 EdDSA(ed25519,更现代);集成验证发现
auto_updater 1.0.0 捆绑的 WinSparkle 0.8.1 只支持经典 DSA 验签,EdDSA 需
0.9+。签名档位降 DSA 匹配引擎(用户裁决;依据与升级路径详见 gen_appcast.py
头注、RELEASE.md「为何 DSA 而非 EdDSA」)。

安全纪律(红线,详见 tool/RELEASE.md):
  - 本脚本【只打印到 stdout,绝不写任何文件】—— 私钥不落盘、不入库;
  - 私钥不得提交仓库 / 贴聊天窗口 / 进日志 / 截图;
  - 一次性:重跑 = 生成全新配对(勿覆盖在用配对,否则旧签名链断裂);
  - 泄漏或丢失时的轮换流程见 RELEASE.md「密钥轮换」。

依赖:python3 + cryptography(`pip install cryptography`;密钥生成只在本机
跑一次,CI 内 release.yml 只装依赖跑 gen_appcast.py,不跑本脚本)。

用法:
  python tool/gen_appcast_dsa_key.py

本地自测(完成门:生成→PEM 重载→DSA-SHA1 签名→公钥验签往返 + 篡改/错钥必拒;
密钥临时,不打印不落盘):
  python tool/gen_appcast_dsa_key.py --self-test
"""
from __future__ import annotations

import argparse
import sys

SECRET_NAME = "APPCAST_DSA_PRIVATE_KEY"  # 与 release.yml / RELEASE.md 三方一致
PUB_PEM_PATH = "yucai/client/windows/runner/dsa_pub.pem"  # 公钥唯一落点
DSA_KEY_SIZE = 1024      # Sparkle 经典 DSA 档位(官方 generate_keys 同规格)
PRIV_PEM_HEADER = "-----BEGIN DSA PRIVATE KEY-----"  # TraditionalOpenSSL DSA 封装
PUB_PEM_HEADER = "-----BEGIN PUBLIC KEY-----"        # SubjectPublicKeyInfo 封装


def _die(msg: str) -> None:
    """统一致命错误出口。"""
    print(f"FATAL: {msg}", file=sys.stderr)
    sys.exit(1)


def _force_utf8_stdio() -> None:
    """Windows 下管道/控制台默认非 UTF-8 代码页,中文输出会 UnicodeEncodeError;
    统一重配 stdio 为 UTF-8(errors=replace,极端环境也不崩)。"""
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:  # pragma: no cover - 极端平台无 reconfigure
            pass


def _load_dsa():
    """惰性导入 cryptography 的经典 DSA 原语(缺依赖时给出可操作提示)。"""
    try:
        from cryptography.hazmat.primitives import hashes
        from cryptography.hazmat.primitives.asymmetric import dsa
        from cryptography.hazmat.primitives.asymmetric.dsa import DSAPrivateKey
        from cryptography.hazmat.primitives.serialization import (
            Encoding,
            NoEncryption,
            PrivateFormat,
            PublicFormat,
            load_pem_private_key,
            load_pem_public_key,
        )
    except ImportError:  # pragma: no cover - 环境缺依赖分支
        _die("缺少依赖 cryptography,请先:pip install cryptography(见 tool/RELEASE.md)")
    return (dsa, hashes, DSAPrivateKey, load_pem_private_key, load_pem_public_key,
            Encoding, PrivateFormat, PublicFormat, NoEncryption)


def generate_keypair_pem() -> tuple[str, str]:
    """生成 1024-bit DSA 密钥对并编码为 Sparkle 生态惯例的 PEM。

    返回 (private_key_pem, public_key_pem):
      - private_key_pem:TraditionalOpenSSL DSA 私钥 PEM("DSA PRIVATE KEY"
        头,与 Sparkle 官方 generate_keys 产物同格式;cryptography/OpenSSL
        均可直接加载)→ 存 GitHub Secrets APPCAST_DSA_PRIVATE_KEY
      - public_key_pem:SubjectPublicKeyInfo 公钥 PEM("PUBLIC KEY" 头,
        PEM_read_bio_DSA_PUBKEY 可读)→ 存 PUB_PEM_PATH(dsa_pub.pem)
    """
    dsa, _, _, _, _, Encoding, PrivateFormat, PublicFormat, NoEncryption = \
        _load_dsa()
    key = dsa.generate_private_key(key_size=DSA_KEY_SIZE)
    priv_pem = key.private_bytes(
        encoding=Encoding.PEM,
        format=PrivateFormat.TraditionalOpenSSL,
        encryption_algorithm=NoEncryption(),
    ).decode("ascii")
    pub_pem = key.public_key().public_bytes(
        encoding=Encoding.PEM,
        format=PublicFormat.SubjectPublicKeyInfo,
    ).decode("ascii")
    return priv_pem, pub_pem


def _run_self_test() -> None:
    """往返自测:生成→PEM 格式/重载断言→DSA-SHA1 签名→公钥验签(篡改/错钥必拒)。

    自测密钥用后即弃,不打印,不落盘。
    """
    (dsa, hashes, DSAPrivateKey, load_pem_private_key, load_pem_public_key,
     _, _, _, _) = _load_dsa()

    priv_pem, pub_pem = generate_keypair_pem()

    # 1) PEM 格式断言(头尾行 = 期望的封装格式)。
    assert priv_pem.startswith(PRIV_PEM_HEADER + "\n"), "私钥 PEM 头不符"
    assert priv_pem.rstrip("\n").endswith("-----END DSA PRIVATE KEY-----"), \
        "私钥 PEM 尾不符"
    assert pub_pem.startswith(PUB_PEM_HEADER + "\n"), "公钥 PEM 头不符"
    assert pub_pem.rstrip("\n").endswith("-----END PUBLIC KEY-----"), "公钥 PEM 尾不符"

    # 2) PEM 重载往返(私钥与 gen_appcast.load_private_key 同口径;公钥侧模拟
    #    WinSparkle 只持公钥验签的现实)。
    key = load_pem_private_key(priv_pem.encode("ascii"), password=None)
    pub = load_pem_public_key(pub_pem.encode("ascii"))
    assert isinstance(key, DSAPrivateKey), "重载后应为 DSA 私钥"
    assert key.key_size == DSA_KEY_SIZE, f"密钥长度 {key.key_size} != {DSA_KEY_SIZE}"

    # 3) 签名→公钥验签往返(Sparkle 经典口径:DSA + SHA-1,DER 签名体)。
    message = "御财 appcast dsa self-test 往返校验".encode("utf-8") + bytes(range(256))
    sig = key.sign(message, hashes.SHA1())
    assert sig[0] == 0x30, "签名应为 DER SEQUENCE(OpenSSL DSA 签名形态)"
    pub.verify(sig, message, hashes.SHA1())  # 失败即抛异常
    # 篡改必拒(防「恒真」假阳性)。
    tampered = bytearray(message)
    tampered[0] ^= 0x01
    try:
        pub.verify(sig, bytes(tampered), hashes.SHA1())
    except Exception:
        pass
    else:
        raise AssertionError("篡改后仍验签通过,签名实现有误")
    # 用错公钥(另生成一对)验签必拒。
    other_pub = load_pem_public_key(generate_keypair_pem()[1].encode("ascii"))
    try:
        other_pub.verify(sig, message, hashes.SHA1())
    except Exception:
        pass
    else:
        raise AssertionError("错配公钥仍验签通过")

    print("SELF-TEST PASSED: gen_appcast_dsa_key.py(PEM 格式 / 重载往返 / "
          "DSA-SHA1 签名验签 / 篡改拒绝 / 错钥拒绝)")


def _print_keypair(priv_pem: str, pub_pem: str) -> None:
    """人类可读输出:公钥 dsa_pub.pem 指引 + 私钥 Secrets 指引(只打 stdout,不写文件)。

    PEM 顶格打印(无缩进),保证复制粘贴后即为合法 PEM。
    """
    bar = "=" * 74
    print(bar)
    print("御财 appcast 经典 DSA 密钥对(一次性生成 —— 立即按下方指引安置,勿存他处)")
    print(bar)
    print()
    print(f"[1/3] 公钥(PEM)—— 原样粘贴为 {PUB_PEM_PATH}:")
    print()
    print(pub_pem.rstrip("\n"))
    print()
    print("  整段(含 BEGIN/END 行与全部换行)保存为上述文件;格式 =")
    print("  SubjectPublicKeyInfo(BEGIN PUBLIC KEY),即 Sparkle 官方 dsa_pub.pem")
    print("  同款,auto_updater 构建时烤入 exe 的 WinSparkle 公钥资源。")
    print()
    print("[2/3] 私钥(PEM)—— 仅入 GitHub Actions Secrets,绝不入库:")
    print()
    print(priv_pem.rstrip("\n"))
    print()
    print("  仓库 → Settings → Secrets and variables → Actions → New repository secret:")
    print(f"    Name : {SECRET_NAME}")
    print("    Value: <上面整段私钥 PEM,含 BEGIN/END 行与全部换行>")
    print()
    print("[3/3] 自检:python yucai/client/tool/gen_appcast.py --self-test")
    print()
    print("红线:私钥不写文件、不提交、不进日志/截图;重跑本脚本 = 全新配对,")
    print("      勿覆盖在用配对(轮换流程见 tool/RELEASE.md)。")
    print(bar)


def main(argv: list[str] | None = None) -> None:
    _force_utf8_stdio()
    p = argparse.ArgumentParser(
        description="一次性生成 appcast 经典 DSA 签名密钥对(详见文件头注)")
    p.add_argument("--self-test", action="store_true",
                   help="自测:生成→签名→验签往返(不打印任何密钥材料)")
    args = p.parse_args(argv)

    if args.self_test:
        _run_self_test()
        return

    priv_pem, pub_pem = generate_keypair_pem()
    _print_keypair(priv_pem, pub_pem)


if __name__ == "__main__":
    main()
