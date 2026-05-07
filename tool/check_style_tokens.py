#!/usr/bin/env python3
"""
检查 lib/ 目录中是否有新的硬编码样式值。
在 CI 或本地提交前运行，防止技术债务回流。

用法:
    python tool/check_style_tokens.py
    python tool/check_style_tokens.py --generate-baseline

退出码:
    0 - 无新增债务（或 baseline 生成成功）
    1 - 发现新增债务
"""

import os
import re
import sys

# 文件/目录排除列表
EXCLUDE_DIRS = {"theme", "widgets"}  # 底层组件允许硬编码（Token 定义处）
EXCLUDE_FILES = {"app_design_tokens.dart"}

# 检测模式
PATTERNS = [
    (
        r"BorderRadius\.circular\(\s*(?!AppRadii)[0-9]",
        "Hardcoded BorderRadius.circular(…)",
    ),
    (
        r"\.withAlpha\(\s*(?!AppAlphas)[0-9]",
        "Hardcoded .withAlpha(…)",
    ),
    (
        r"AppBreakpoints\.isDesktop",
        "Legacy AppBreakpoints.isDesktop (use AppLayout)",
    ),
]

BASELINE_PATH = os.path.join(os.path.dirname(__file__), "check_style_tokens_baseline.txt")


def _load_baseline() -> set[str]:
    """加载 baseline 文件，返回 (rel_path:text) 键集合。"""
    if not os.path.exists(BASELINE_PATH):
        return set()
    keys = set()
    with open(BASELINE_PATH, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line:
                keys.add(line)
    return keys


def scan() -> list[tuple[str, int, str, str]]:
    """扫描 lib/ 目录，返回 (文件路径, 行号, 匹配文本, 问题描述) 列表。"""
    violations = []
    base = os.path.join(os.path.dirname(__file__), "..", "lib")

    for root, dirs, files in os.walk(base):
        # 排除底层目录
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]

        for fname in files:
            if not fname.endswith(".dart"):
                continue
            if fname in EXCLUDE_FILES:
                continue

            fpath = os.path.join(root, fname)
            rel = os.path.relpath(fpath, os.path.dirname(__file__) + "/..").replace("\\", "/")

            with open(fpath, "r", encoding="utf-8") as fh:
                for lineno, line in enumerate(fh, start=1):
                    for pattern, desc in PATTERNS:
                        if re.search(pattern, line):
                            text = line.strip()
                            violations.append((rel, lineno, text, desc))

    return violations


def generate_baseline(violations: list[tuple[str, int, str, str]]) -> None:
    """将当前所有违规写入 baseline 文件。"""
    keys = sorted({f"{rel}:{text}" for rel, _lineno, text, _desc in violations})
    with open(BASELINE_PATH, "w", encoding="utf-8") as fh:
        for key in keys:
            fh.write(key + "\n")
    print(f"[BASELINE] Wrote {len(keys)} entries to {BASELINE_PATH}")


def main() -> int:
    violations = scan()

    if not violations:
        print("[PASS] No new style debt found.")
        return 0

    if len(sys.argv) > 1 and sys.argv[1] == "--generate-baseline":
        generate_baseline(violations)
        return 0

    baseline = _load_baseline()
    new_violations = []
    for rel, lineno, text, desc in violations:
        key = f"{rel}:{text}"
        if key not in baseline:
            new_violations.append((rel, lineno, text, desc))

    if not new_violations:
        total = len(violations)
        print(f"[PASS] No new style debt found ({total} legacy issues frozen in baseline).")
        return 0

    print(f"[FAIL] Found {len(new_violations)} new style debt issue(s):\n")
    for rel, lineno, text, desc in new_violations:
        print(f"  {rel}:{lineno}")
        print(f"    {desc}")
        print(f"    → {text}\n")

    print(
        "Hint: Use AppRadii / AppAlphas / AppLayout instead of hardcoded values.\n"
        "If these are intentional, run: python tool/check_style_tokens.py --generate-baseline\n"
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
