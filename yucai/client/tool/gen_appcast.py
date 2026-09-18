#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""御财 Sparkle/WinSparkle appcast 生成器(F24 FR-1/FR-2;ADR-2)。

作用:输入本次发布信息(tag/说明/安装包 URL + 本地安装包文件)+ 经典 DSA 私钥,
生成符合 Sparkle appcast 规范(RSS 2.0 + sparkle 命名空间)的 appcast.xml:
  - <item> 携带版本(<sparkle:version>/<sparkle:shortVersionString>,取 tag 去掉
    前缀 v,即 pubspec 的 X.Y.Z —— 版本单源,NFR-2;+N 构建号不进版本串,
    与 yucai/Makefile windows-installer 的 AppVersion 口径一致)
  - <enclosure url=...> 指向本 Release 的安装包资产 URL
  - sparkle:dsaSignature = WinSparkle 0.8.1 口径的经典 DSA 签名 —— 签名对象是
    【SHA1(SHA1(安装包))】双哈希摘要,不是文件单哈希!(engine
    signatureverifier.cpp VerifyDSASHA1Signature 的现实,等价
    `openssl dgst -sha1 -binary < f | openssl dgst -sha1 -sign key`;单哈希
    签名恒验不过 → v1.0.2–v1.0.5 全部「更新未正确签名」的根因,2026-09-16 修)
  - length = 安装包字节数(WinSparkle 下载完整性校验)

签名档位 = 经典 DSA 的现实依据(集成验证结论,用户裁决修订):auto_updater 1.0.0
捆绑的 WinSparkle 0.8.1 只支持经典 DSA 验签 —— exe 公钥资源(DSAPub/DSAPEM,
源 yucai/client/windows/runner/dsa_pub.pem)+ appcast sparkle:dsaSignature;
EdDSA(sparkle:edSignature)需 WinSparkle 0.9+,当前引擎不可用。

【升级引擎后切回 EdDSA 两行清单】(auto_updater 升至捆绑 WinSparkle ≥0.9 时):
  1. gen_appcast.py:sparkle:dsaSignature 改回 edSignature,签名实现由
     DSA-SHA1/PEM 改回 Ed25519/base64(密钥工具恢复 EdDSA 语义并同步更名);
  2. release.yml 与 RELEASE.md:APPCAST_DSA_PRIVATE_KEY 改回
     APPCAST_EDDSA_PRIVATE_KEY,客户端公钥改回 EdDSA 常量接入。

属性位置按 WinSparkle 解析器(src/appcast.cpp)事实:
  - sparkle:dsaSignature 只认 enclosure 属性;
  - sparkle:version / shortVersionString 同时认 item 子元素(现行语法)与
    enclosure 属性(legacy 语法)—— 两种都写,最大化兼容。

密钥格式(Sparkle 经典 DSA,与官方 generate_keys/sign_update 生态互通):
  - 私钥:PEM(TraditionalOpenSSL DSA;PKCS#8 封装亦可加载)
    → GitHub Secrets APPCAST_DSA_PRIVATE_KEY
  - 公钥:PEM(SubjectPublicKeyInfo)→ yucai/client/windows/runner/dsa_pub.pem
  密钥对用 tool/gen_appcast_dsa_key.py 一次性生成(见 RELEASE.md)。

依赖:python3 + cryptography(`pip install cryptography`;GitHub Actions
windows-latest 上由 .github/workflows/release.yml 显式安装)。

用法(CI 内见 release.yml「Generate signed appcast.xml」步骤;本地 dry-run 同参):
  python tool/gen_appcast.py \
    --tag v1.0.1 \
    --notes-file notes.txt \
    --asset-url https://github.com/OWNER/REPO/releases/download/v1.0.1/yucai-setup-1.0.1.exe \
    --asset-file dist/yucai-setup-1.0.1.exe \
    --output appcast.xml
  私钥来源(二选一,显式参数优先;绝不建议命令行直传私钥,防进 shell 历史):
    --private-key-file <path>   或   环境变量 APPCAST_DSA_PRIVATE_KEY

本地自测(完成门:生成→公钥验签往返 + XML 结构断言;全程临时目录,不落持久文件,
密钥对临时生成,测完即弃):
  python tool/gen_appcast.py --self-test
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import os
import sys
import tempfile
from email.utils import formatdate, parsedate_to_datetime
from xml.etree import ElementTree as ET
from xml.sax.saxutils import escape as _xml_escape

# ---- 常量(改动只动这里) ----
# FR-2 稳定订阅地址:latest 恒指向最新 Release,URL 不变(作为 channel <link>)。
DEFAULT_FEED_URL = "https://github.com/williamparris1995/syfinance/releases/latest/download/appcast.xml"
CHANNEL_TITLE = "御财"
CHANNEL_DESCRIPTION = "御财(个人理财)Windows 更新源"
CHANNEL_LANGUAGE = "zh-cn"
SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
DC_NS = "http://purl.org/dc/elements/1.1/"
DSA_KEY_SIZE = 1024   # Sparkle 经典 DSA 档位(WinSparkle 0.8.1 验签口径)
DSA_DER_TAG = 0x30    # DER SEQUENCE 首字节(OpenSSL DSA 签名形态自检用)


def _die(msg: str) -> "None":
    """统一致命错误出口(中文提示,带退出码 1)。"""
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
        from cryptography.hazmat.primitives.serialization import load_pem_private_key
    except ImportError:  # pragma: no cover - 环境缺依赖分支
        _die("缺少依赖 cryptography,请先:pip install cryptography(见 tool/RELEASE.md)")
    return dsa, hashes, DSAPrivateKey, load_pem_private_key


def _esc(text: str) -> str:
    """XML 文本节点转义。"""
    return _xml_escape(text)


def _esc_attr(text: str) -> str:
    """XML 属性值转义(额外处理引号)。"""
    return _xml_escape(text, {'"': "&quot;"})


def _cdata(text: str) -> str:
    """包 CDATA;拆分字面量 "]]>" 防提前闭合(拆分后相邻 CDATA 段在 XML
    语义上无缝拼接,解析侧取回原文)。"""
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def strip_tag_prefix(tag: str) -> str:
    """'v1.2.3' -> '1.2.3'(无 v 前缀则原样);并校验纯点分数字形态。"""
    version = tag[1:] if tag.startswith("v") else tag
    parts = version.split(".")
    if not version or not all(p.isdigit() for p in parts):
        _die(f"tag '{tag}' 派生的版本号 '{version}' 不符 X.Y.Z 点分数字形态")
    return version


def load_private_key(material: str):
    """从 PEM 材料构造经典 DSA 私钥(Sparkle/WinSparkle 0.8.1 口径)。

    接受 TraditionalOpenSSL DSA("-----BEGIN DSA PRIVATE KEY-----",密钥工具
    gen_appcast_dsa_key.py 的输出形态)与 PKCS#8("-----BEGIN PRIVATE KEY-----")
    两种 PEM 封装(cryptography 均可加载);容忍首尾空白(Secrets/文件粘贴
    常见)。非 DSA 私钥直接拒绝(防拿错钥档位)。
    """
    _, _, DSAPrivateKey, load_pem_private_key = _load_dsa()
    try:
        key = load_pem_private_key(material.strip().encode("utf-8"), password=None)
    except Exception:
        _die("私钥不是合法 PEM(检查是否整段复制、含 BEGIN/END 行;生成:tool/gen_appcast_dsa_key.py)")
    if not isinstance(key, DSAPrivateKey):
        _die(f"私钥类型是 {type(key).__name__},应为经典 DSA 私钥(WinSparkle 0.8.1 档位)")
    return key


def sign_file(key, path: str) -> tuple[str, int]:
    """读安装包字节 → WinSparkle 0.8.1 口径 DSA 签名;返回 (base64(DER 签名), 文件字节数)。

    引擎口径(signatureverifier.cpp VerifyDSASHA1Signature):对
    SHA1(SHA1(file)) 双哈希摘要做 DSA-SHA1 签名 —— 与
    `openssl dgst -sha1 -binary < f | openssl dgst -sha1 -sign key` 等价;
    签名体为 OpenSSL DER(r‖s 序列),base64 后写入 sparkle:dsaSignature。
    【勿改回单哈希 key.sign(data, SHA1):引擎恒验不过,更新死拒】
    DSA 无流式接口,整体载入内存(CI 安装包约百 MB 级,可接受);
    返回的 length 仍为文件【精确字节】(WinSparkle 下载完整性校验)。
    """
    from cryptography.hazmat.primitives.asymmetric.utils import Prehashed

    _, hashes, _, _ = _load_dsa()
    with open(path, "rb") as f:
        data = f.read()
    inner = hashlib.sha1(data).digest()
    outer = hashlib.sha1(inner).digest()
    signature = base64.b64encode(key.sign(outer, Prehashed(hashes.SHA1()))).decode("ascii")
    return signature, len(data)


def build_appcast(
    *,
    version: str,
    notes: str,
    asset_url: str,
    signature_b64: str,
    asset_length: int,
    pub_date_rfc2822: str,
    feed_url: str = DEFAULT_FEED_URL,
    channel_title: str = CHANNEL_TITLE,
    channel_description: str = CHANNEL_DESCRIPTION,
    language: str = CHANNEL_LANGUAGE,
) -> str:
    """拼装 appcast.xml 文本(纯字符串模板 + 显式转义,输出确定性、可 diff)。"""
    item_title = f"{channel_title} {version}"
    v = _esc(version)
    return f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="{SPARKLE_NS}" xmlns:dc="{DC_NS}">
  <channel>
    <title>{_esc(channel_title)}</title>
    <link>{_esc(feed_url)}</link>
    <description>{_esc(channel_description)}</description>
    <language>{_esc(language)}</language>
    <item>
      <title>{_esc(item_title)}</title>
      <description>{_cdata(notes)}</description>
      <pubDate>{_esc(pub_date_rfc2822)}</pubDate>
      <sparkle:version>{v}</sparkle:version>
      <sparkle:shortVersionString>{v}</sparkle:shortVersionString>
      <enclosure url="{_esc_attr(asset_url)}" sparkle:version="{v}" sparkle:shortVersionString="{v}" sparkle:dsaSignature="{_esc_attr(signature_b64)}" length="{asset_length}" type="application/octet-stream"/>
    </item>
  </channel>
</rss>
"""


# ---------------------------------------------------------------------------
# 自测模式(完成门):临时密钥 → 生成 → XML 结构断言 → 公钥验签往返。
# 不依赖任何仓库内既有密钥;全部产物落在系统临时目录,退出即清理。
# ---------------------------------------------------------------------------
def _run_self_test() -> None:
    dsa, hashes, DSAPrivateKey, _ = _load_dsa()
    from cryptography.hazmat.primitives.serialization import (
        Encoding,
        NoEncryption,
        PrivateFormat,
        PublicFormat,
        load_pem_public_key,
    )

    # 1) 临时密钥对(PEM 形态,与真实路径同口径):私钥走 load_private_key,
    #    公钥 PEM 重载模拟 WinSparkle 只持公钥侧验签的现实。
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
    loaded = load_private_key(priv_pem)
    assert isinstance(loaded, DSAPrivateKey) and loaded.key_size == DSA_KEY_SIZE, \
        "PEM 私钥重载后应为 1024-bit 经典 DSA"

    # 2) 临时假安装包 + 带 CDATA 陷阱/引号/中文的 notes(测转义路径)。
    payload = os.urandom(65536) + "御财假安装包]]>尾巴".encode("utf-8")
    version = "1.2.3"
    tag = f"v{version}"
    notes = "修复:\n- 支出列表 <排序> & 筛选\n- 含 \"引号\" 与 ]]> 陷阱\n中文换行均应保留"
    asset_url = "https://example.com/yancai/dist/yucai-setup-1.2.3.exe?a=1&b=2"
    pub_date = formatdate(usegmt=True)  # RFC 2822(UTC)

    with tempfile.TemporaryDirectory(prefix="yucai-appcast-selftest-") as tmp:
        asset = os.path.join(tmp, "yucai-setup-1.2.3.exe")
        with open(asset, "wb") as f:
            f.write(payload)
        sig_b64, length = sign_file(loaded, asset)
        assert length == len(payload), "length 应等于文件字节数"
        sig_der = base64.b64decode(sig_b64, validate=True)
        assert sig_der[0] == DSA_DER_TAG, "签名应为 DER SEQUENCE(OpenSSL DSA 形态)"

        xml_text = build_appcast(
            version=version, notes=notes, asset_url=asset_url,
            signature_b64=sig_b64, asset_length=length, pub_date_rfc2822=pub_date)

        out = os.path.join(tmp, "appcast.xml")
        with open(out, "w", encoding="utf-8", newline="\n") as f:
            f.write(xml_text)
        # 回读按 utf-8 无损(编码声明 ↔ 实际编码一致)。
        with open(out, "r", encoding="utf-8") as f:
            xml_text = f.read()

    # 3) XML 结构断言(解析器视角,而非字符串匹配)。
    assert xml_text.startswith('<?xml version="1.0" encoding="utf-8"?>'), "缺 utf-8 XML 声明"
    root = ET.fromstring(xml_text)
    assert root.tag == "rss" and root.get("version") == "2.0", "根节点应为 rss 2.0"
    # ET 不把 xmlns:* 当属性暴露,命名空间声明在原文层面断言。
    assert f'xmlns:sparkle="{SPARKLE_NS}"' in xml_text, "缺 sparkle 命名空间声明"
    assert f'xmlns:dc="{DC_NS}"' in xml_text, "缺 dc 命名空间声明"
    ns = {"sparkle": SPARKLE_NS}
    channel = root.find("channel")
    assert channel.findtext("title") == CHANNEL_TITLE
    assert channel.findtext("link") == DEFAULT_FEED_URL, "channel link 应为 FR-2 稳定订阅地址"
    items = channel.findall("item")
    assert len(items) == 1, "单条目(latest Release 各自带独立 appcast,FR-2)"
    item = items[0]
    assert item.findtext("title") == f"御财 {version}"
    # item 子元素(现行语法)+ enclosure 属性(legacy 语法)双份版本断言。
    assert item.findtext("sparkle:version", namespaces=ns) == version
    assert item.findtext("sparkle:shortVersionString", namespaces=ns) == version
    enc = item.find("enclosure")
    assert enc is not None, "缺 enclosure"
    assert enc.get("url") == asset_url
    assert enc.get(f"{{{SPARKLE_NS}}}version") == version
    assert enc.get(f"{{{SPARKLE_NS}}}shortVersionString") == version
    assert enc.get("length") == str(len(payload))
    assert enc.get("type") == "application/octet-stream"
    # tag → 版本派生。
    assert strip_tag_prefix(tag) == version
    # notes 原文取回(含换行/引号/中文/CDATA 陷阱字符)。
    assert item.findtext("description") == notes, "description 应无损保留 notes 原文"
    # pubDate 可被 RFC 2822 解析。
    parsedate_to_datetime(item.findtext("pubDate"))

    # 4) 公钥验签往返 —— 按【引擎口径】(双哈希,模拟 WinSparkle 侧校验):
    #    签名须过 SHA1(SHA1(payload)),且必须不过单哈希 SHA1(payload)
    #    (单哈希口径回归门:v1.0.2–1.0.5「更新未正确签名」的根因,勿退回)。
    from cryptography.hazmat.primitives.asymmetric.utils import Prehashed

    pub = load_pem_public_key(pub_pem.encode("ascii"))
    sig = base64.b64decode(enc.get(f"{{{SPARKLE_NS}}}dsaSignature"))
    inner = hashlib.sha1(payload).digest()
    outer = hashlib.sha1(inner).digest()
    pub.verify(sig, outer, Prehashed(hashes.SHA1()))  # 失败即抛异常
    try:
        pub.verify(sig, inner, Prehashed(hashes.SHA1()))
    except Exception:
        pass
    else:
        raise AssertionError("单哈希口径竟验签通过,签名实现退回错误口径")
    # 篡改一个字节必须验签失败(防「恒真」假阳性)。
    tampered = bytearray(payload)
    tampered[0] ^= 0xFF
    t_outer = hashlib.sha1(hashlib.sha1(bytes(tampered)).digest()).digest()
    try:
        pub.verify(sig, t_outer, Prehashed(hashes.SHA1()))
    except Exception:
        pass
    else:
        raise AssertionError("篡改后仍验签通过,签名实现有误")

    print("SELF-TEST PASSED: gen_appcast.py(密钥 PEM 加载 / XML 结构 / DSA 签名往返 / 篡改拒绝)")
    print(f"  version={version} length={len(payload)} signature={sig_b64[:20]}...")


def main(argv: list[str] | None = None) -> None:
    _force_utf8_stdio()
    p = argparse.ArgumentParser(
        description="生成 Sparkle/WinSparkle 规范的签名 appcast.xml(详见文件头注)")
    p.add_argument("--self-test", action="store_true",
                   help="本地自测:临时密钥生成→XML 断言→公钥验签往返(不触真实密钥)")
    p.add_argument("--tag", help="发布 tag,如 v1.0.1(版本取去 v 部分)")
    p.add_argument("--notes", help="发布说明(内联;与 --notes-file 二选一)")
    p.add_argument("--notes-file", help="发布说明文件(CI 用 tag 注释导出文件)")
    p.add_argument("--asset-url", help="安装包在 GitHub Release 的资产 URL")
    p.add_argument("--asset-file", help="安装包本地路径(读取字节算签名与长度)")
    p.add_argument("--private-key-file",
                   help="DSA 私钥 PEM 文件;缺省读环境变量 APPCAST_DSA_PRIVATE_KEY")
    p.add_argument("--pub-date", help="pubDate(RFC 2822);缺省取当前 UTC 时间")
    p.add_argument("--output", default="appcast.xml", help="输出文件(可重跑覆盖)")
    args = p.parse_args(argv)

    if args.self_test:
        _run_self_test()
        return

    missing = [k for k, v in {
        "--tag": args.tag, "--asset-url": args.asset_url,
        "--asset-file": args.asset_file}.items() if not v]
    if missing:
        _die(f"缺少必填参数: {', '.join(missing)}(或用 --self-test 跑自测)")
    if bool(args.notes) == bool(args.notes_file):
        _die("--notes 与 --notes-file 必须二选一")

    version = strip_tag_prefix(args.tag)
    notes = args.notes if args.notes is not None else _read_notes(args.notes_file)

    # 私钥:显式文件 > 环境变量(Actions Secrets 走 env)。
    if args.private_key_file:
        with open(args.private_key_file, "r", encoding="utf-8") as f:
            material = f.read()
    elif os.environ.get("APPCAST_DSA_PRIVATE_KEY"):
        material = os.environ["APPCAST_DSA_PRIVATE_KEY"]
    else:
        _die("未提供私钥:--private-key-file 或环境变量 APPCAST_DSA_PRIVATE_KEY(见 tool/RELEASE.md)")
    key = load_private_key(material)

    signature_b64, length = sign_file(key, args.asset_file)
    pub_date = args.pub_date or formatdate(usegmt=True)
    xml_text = build_appcast(
        version=version, notes=notes, asset_url=args.asset_url,
        signature_b64=signature_b64, asset_length=length, pub_date_rfc2822=pub_date)

    with open(args.output, "w", encoding="utf-8", newline="\n") as f:
        f.write(xml_text)
    print(f"OK {args.output}: version={version} length={length} signature={signature_b64[:20]}...")
    print(f"   订阅地址(FR-2): {DEFAULT_FEED_URL}")


def _read_notes(path: str) -> str:
    """读说明文件(容忍 UTF-8 BOM,tag 注释导出常见)。"""
    if not os.path.isfile(path):
        _die(f"说明文件不存在: {path}")
    with open(path, "r", encoding="utf-8-sig") as f:
        return f.read()


if __name__ == "__main__":
    main()
